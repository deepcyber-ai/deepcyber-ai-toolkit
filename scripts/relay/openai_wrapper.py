#!/usr/bin/env python3
"""
DeepCyber OpenAI-Compatible Wrapper
====================================
Runs on the tester's laptop. Presents a standard OpenAI /v1/chat/completions
API that cloud tools (HumanBound, Promptfoo, etc.) can talk to natively.

Translates between OpenAI format and the target's internal API format
(e.g. Vertex AI reasoningEngines:streamQuery with nested double-encoded JSON).

Features:
  - Standard OpenAI /v1/chat/completions endpoint
  - HumanBound-compatible /threads (thread_init) and /chat (chat_completion)
  - /v1/sessions/init and /v1/sessions/terminate for direct session management
  - /v1/models endpoint for model discovery
  - Automatic request body translation (no double-encoding for callers)
  - JWT injection for internal API auth
  - Tamper-evident audit logging
  - Rate limiting

Usage:
    export TARGET_API="https://internal-api.client.com/v1/reasoningEngines/:streamQuery"
    export JWT_TOKEN="your-gcp-token"
    python openai_wrapper.py

Then point any OpenAI-compatible tool at:
    OPENAI_API_BASE=http://localhost:8090/v1
    OPENAI_API_KEY=<your-relay-secret>

HumanBound config (-e flag):
    {
      "streaming": false,
      "thread_init": {
        "endpoint": "http://localhost:8090/threads",
        "headers": {"Authorization": "Bearer <relay-secret>"},
        "payload": {}
      },
      "chat_completion": {
        "endpoint": "http://localhost:8090/chat",
        "headers": {"Authorization": "Bearer <relay-secret>"},
        "payload": {"content": "$PROMPT"}
      }
    }
"""

import copy
import hashlib
import json
import logging
import os
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import yaml

try:
    from fastapi import FastAPI, Header, HTTPException, Request
    from fastapi.responses import JSONResponse
    import httpx
    import uvicorn
except ImportError:
    print("Missing dependencies. Install with:")
    print("  pip install fastapi uvicorn httpx pyyaml")
    sys.exit(1)


# ── Configuration ──────────────────────────────────────────────────────────

TARGET_API       = os.getenv("TARGET_API", "http://localhost:8089/v1/reasoningEngines/:streamQuery")
LISTEN_PORT      = int(os.getenv("WRAPPER_PORT", "8090"))
RELAY_SECRET     = os.getenv("RELAY_SECRET", "CHANGE_ME_TO_RANDOM_SECRET")
JWT_TOKEN        = os.getenv("JWT_TOKEN", "")
LOG_DIR          = Path(os.getenv("LOG_DIR", "./audit_logs"))
RATE_LIMIT_RPS   = int(os.getenv("RATE_LIMIT", "10"))
MODEL_NAME       = os.getenv("MODEL_NAME", "target")
TARGET_YAML      = os.getenv("TARGET_YAML", "")

# ── Load target.yaml if available ──────────────────────────────────────────

_target_config = None

def load_target_yaml():
    global _target_config
    if _target_config is not None:
        return _target_config

    search_paths = []
    if TARGET_YAML:
        search_paths.append(TARGET_YAML)
    search_paths += [
        os.path.join(os.getcwd(), "target.yaml"),
        os.path.join(os.path.dirname(__file__), "target.yaml"),
    ]

    for path in search_paths:
        if os.path.isfile(path):
            with open(path) as f:
                _target_config = yaml.safe_load(f)
                log.info(f"Loaded target config from {path}")
                return _target_config

    return None


# ── App Setup ──────────────────────────────────────────────────────────────

app = FastAPI(title="DeepCyber OpenAI Wrapper", version="1.0")
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("wrapper")

# Audit log
audit_log_path = LOG_DIR / f"wrapper_audit_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jsonl"
seq_counter = 0
prev_hash = "GENESIS"

# Rate limiter
request_times = []

# Session state
_sessions = {}  # session_id -> {user_id, created_at, ...}
_active_session: Optional[str] = None

# HTTP client — create fresh per-request to avoid stale connections
HTTP_TIMEOUT = 60.0


# ── Audit Logging ──────────────────────────────────────────────────────────

def audit_log(entry: dict):
    global seq_counter, prev_hash
    seq_counter += 1
    entry["seq"] = seq_counter
    entry["timestamp"] = datetime.now(timezone.utc).isoformat()
    entry["prev_hash"] = prev_hash
    raw = json.dumps(entry, sort_keys=True)
    entry["hash"] = hashlib.sha256(f"{prev_hash}:{raw}".encode()).hexdigest()
    prev_hash = entry["hash"]
    with open(audit_log_path, "a") as f:
        f.write(json.dumps(entry) + "\n")


# ── Rate Limiting ──────────────────────────────────────────────────────────

def check_rate_limit() -> bool:
    now = time.time()
    request_times[:] = [t for t in request_times if now - t < 1.0]
    if len(request_times) >= RATE_LIMIT_RPS:
        return False
    request_times.append(now)
    return True


# ── Auth ───────────────────────────────────────────────────────────────────

def verify_auth(authorization: str = Header(default="")):
    """Verify Bearer token matches RELAY_SECRET."""
    if RELAY_SECRET == "CHANGE_ME_TO_RANDOM_SECRET":
        return  # No auth configured
    token = authorization.replace("Bearer ", "").strip()
    if token != RELAY_SECRET:
        raise HTTPException(status_code=401, detail="Unauthorized")


# ── Target API Translation ─────────────────────────────────────────────────

def build_target_body(message: str, session_id: Optional[str] = None) -> dict:
    """Translate a plain text message into the target's internal format.

    The caller sends a simple OpenAI message. This function builds the
    nested, double-encoded body that the internal API expects.
    """
    config = load_target_yaml()

    if config and "request" in config:
        body = copy.deepcopy(config["request"]["body"])
        # Set session_id if available
        if session_id:
            try:
                body["input"]["session_id"] = session_id
            except (KeyError, TypeError):
                pass
        # Build the inner JSON and substitute
        inner = json.dumps({"execution_purpose": "chat", "message": message})
        body = _substitute(body, "{{PROMPT}}", message)
        # Handle the double-encoding: if text field contains a JSON template
        try:
            text_val = body["input"]["message"]["parts"][0]["text"]
            if "execution_purpose" in text_val:
                # Already has the template, good
                pass
            else:
                body["input"]["message"]["parts"][0]["text"] = inner
        except (KeyError, IndexError, TypeError):
            pass
        return body

    # Fallback: generic Vertex AI format
    return {
        "classMethod": "async_stream_query",
        "input": {
            "user_id": "dcr-redteam",
            "session_id": session_id or "dcr-session-001",
            "message": {
                "role": "user",
                "parts": [
                    {"text": json.dumps({"execution_purpose": "chat", "message": message})}
                ]
            }
        }
    }


def build_init_body(name: str = "Test User", age: int = 35,
                    duid: str = "dcr-redteam", cct: str = "dcr-test-token") -> dict:
    """Build an initialize_session request body."""
    config = load_target_yaml()

    init_payload = {"execution_purpose": "initialize_session",
                    "name": name, "age": age, "duid": duid, "cct": cct}

    if config and "request" in config:
        body = copy.deepcopy(config["request"]["body"])
        try:
            body["input"]["message"]["parts"][0]["text"] = json.dumps(init_payload)
            body["input"].pop("session_id", None)
        except (KeyError, IndexError, TypeError):
            pass
        return body

    return {
        "classMethod": "async_stream_query",
        "input": {
            "user_id": "dcr-redteam",
            "message": {
                "role": "user",
                "parts": [{"text": json.dumps(init_payload)}]
            }
        }
    }


def extract_response_text(data: dict) -> str:
    """Extract the AI's text reply from the target's response format."""
    config = load_target_yaml()
    field_path = "content.parts.0.text"
    if config and "response" in config:
        field_path = config["response"].get("field", field_path)

    obj = data
    for part in field_path.split("."):
        if isinstance(obj, list) or part.isdigit():
            obj = obj[int(part)]
        else:
            obj = obj[part]

    # The inner text may itself be JSON
    if isinstance(obj, str):
        try:
            inner = json.loads(obj)
            if isinstance(inner, dict) and "message" in inner:
                return inner["message"]
        except (json.JSONDecodeError, KeyError):
            pass
    return str(obj)


async def send_to_target(body: dict) -> dict:
    """Send a request to the internal API and return parsed response."""
    headers = {"Content-Type": "application/json"}
    if JWT_TOKEN:
        headers["Authorization"] = f"Bearer {JWT_TOKEN}"

    async with httpx.AsyncClient(timeout=HTTP_TIMEOUT) as client:
        resp = await client.post(TARGET_API, json=body, headers=headers)

    content_type = resp.headers.get("content-type", "")

    # Handle SSE responses
    if "text/event-stream" in content_type:
        last_data = None
        for line in resp.text.strip().split("\n"):
            if line.startswith("data: "):
                last_data = json.loads(line[6:])
        if last_data:
            return last_data
        raise ValueError("No data in SSE response")

    return resp.json()


def _substitute(obj, placeholder, value):
    if isinstance(obj, str):
        return obj.replace(placeholder, value)
    if isinstance(obj, dict):
        return {k: _substitute(v, placeholder, value) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_substitute(item, placeholder, value) for item in obj]
    return obj


# ── OpenAI-Compatible Endpoints ────────────────────────────────────────────

@app.get("/v1/models")
async def list_models(authorization: str = Header(default="")):
    verify_auth(authorization)
    return {
        "object": "list",
        "data": [
            {
                "id": MODEL_NAME,
                "object": "model",
                "owned_by": "internal",
            }
        ]
    }


@app.post("/v1/chat/completions")
async def chat_completions(request: Request, authorization: str = Header(default="")):
    verify_auth(authorization)
    request_id = str(uuid.uuid4())[:8]

    if not check_rate_limit():
        raise HTTPException(status_code=429, detail="Rate limited")

    body = await request.json()
    messages = body.get("messages", [])
    if not messages:
        raise HTTPException(status_code=400, detail="No messages provided")

    # Extract the last user message
    user_message = ""
    for msg in reversed(messages):
        if msg.get("role") == "user":
            user_message = msg["content"]
            break

    if not user_message:
        raise HTTPException(status_code=400, detail="No user message found")

    audit_log({
        "event": "REQUEST",
        "id": request_id,
        "message": user_message[:500],
        "session_id": _active_session,
    })

    log.info(f"[{request_id}] chat/completions: {user_message[:80]}...")

    try:
        target_body = build_target_body(user_message, session_id=_active_session)
        response_data = await send_to_target(target_body)
        reply = extract_response_text(response_data)
    except Exception as e:
        audit_log({"event": "TARGET_ERROR", "id": request_id, "error": str(e)})
        log.error(f"[{request_id}] Target error: {e}")
        raise HTTPException(status_code=502, detail=f"Target error: {e}")

    audit_log({
        "event": "RESPONSE",
        "id": request_id,
        "reply": reply[:500],
    })

    log.info(f"[{request_id}] ← {len(reply)} chars")

    # Return standard OpenAI format
    return {
        "id": f"chatcmpl-{request_id}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": MODEL_NAME,
        "choices": [
            {
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": reply,
                },
                "finish_reason": "stop",
            }
        ],
        "usage": {
            "prompt_tokens": len(user_message.split()),
            "completion_tokens": len(reply.split()),
            "total_tokens": len(user_message.split()) + len(reply.split()),
        }
    }


# ── Session Management ─────────────────────────────────────────────────────

@app.post("/v1/sessions/init")
async def init_session(request: Request, authorization: str = Header(default="")):
    verify_auth(authorization)
    global _active_session

    body = await request.json() if await request.body() else {}
    name = body.get("name", "Test User")
    age = body.get("age", 35)
    duid = body.get("duid", "dcr-redteam")
    cct = body.get("cct", "dcr-test-token")

    log.info(f"Initializing session for {name} (age={age})")

    try:
        init_body = build_init_body(name=name, age=age, duid=duid, cct=cct)
        response_data = await send_to_target(init_body)
        inner_text = extract_response_text.__wrapped__(response_data) if hasattr(extract_response_text, '__wrapped__') else None

        # Parse the raw response to get session details
        config = load_target_yaml()
        field_path = "content.parts.0.text"
        if config and "response" in config:
            field_path = config["response"].get("field", field_path)

        obj = response_data
        for part in field_path.split("."):
            if isinstance(obj, list) or part.isdigit():
                obj = obj[int(part)]
            else:
                obj = obj[part]

        inner = json.loads(obj) if isinstance(obj, str) else obj

        if inner.get("status") == "success":
            session_id = inner.get("session_id")
            _active_session = session_id
            _sessions[session_id] = {
                "user_id": inner.get("user_id"),
                "name": name,
                "created_at": datetime.now(timezone.utc).isoformat(),
            }

            audit_log({
                "event": "SESSION_INIT",
                "session_id": session_id,
                "name": name,
            })

            return {
                "status": "success",
                "session_id": session_id,
                "user_id": inner.get("user_id"),
                "welcome_message": inner.get("welcome_message", ""),
            }
        else:
            errors = inner.get("error", [])
            raise HTTPException(status_code=400, detail={"status": "failed", "errors": errors})

    except HTTPException:
        raise
    except Exception as e:
        log.error(f"Session init error: {e}")
        raise HTTPException(status_code=502, detail=f"Session init error: {e}")


@app.post("/v1/sessions/terminate")
async def terminate_session(request: Request, authorization: str = Header(default="")):
    verify_auth(authorization)
    global _active_session

    body = await request.json() if await request.body() else {}
    session_id = body.get("session_id", _active_session)

    if session_id and session_id in _sessions:
        del _sessions[session_id]

    if _active_session == session_id:
        _active_session = None

    audit_log({
        "event": "SESSION_TERMINATE",
        "session_id": session_id,
    })

    log.info(f"Session terminated: {session_id}")

    return {"status": "terminated", "session_id": session_id}


@app.get("/v1/sessions")
async def list_sessions(authorization: str = Header(default="")):
    verify_auth(authorization)
    return {
        "active_session": _active_session,
        "sessions": _sessions,
    }


# ── HumanBound-Compatible Endpoints ───────────────────────────────────
# These match HumanBound CLI's thread_init and chat_completion endpoints.
# HumanBound calls POST /threads to create a thread, then POST /chat
# with {"content": "user message"} for each turn.

@app.post("/threads")
async def humanbound_thread_init(request: Request, authorization: str = Header(default="")):
    """HumanBound thread_init — creates a session and returns a thread ID."""
    verify_auth(authorization)
    global _active_session

    if not check_rate_limit():
        raise HTTPException(status_code=429, detail="Rate limited")

    body = await request.json() if await request.body() else {}
    name = body.get("name", "Test User")
    age = body.get("age", 35)
    duid = body.get("duid", "dcr-redteam")
    cct = body.get("cct", "dcr-test-token")

    request_id = str(uuid.uuid4())[:8]
    log.info(f"[{request_id}] HumanBound thread_init for {name}")

    try:
        init_body = build_init_body(name=name, age=age, duid=duid, cct=cct)
        response_data = await send_to_target(init_body)

        # Parse the target response to extract session ID
        config = load_target_yaml()
        field_path = "content.parts.0.text"
        if config and "response" in config:
            field_path = config["response"].get("field", field_path)

        obj = response_data
        for part in field_path.split("."):
            if isinstance(obj, list) or part.isdigit():
                obj = obj[int(part)]
            else:
                obj = obj[part]

        inner = json.loads(obj) if isinstance(obj, str) else obj

        if inner.get("status") == "success":
            session_id = inner.get("session_id")
            _active_session = session_id
            _sessions[session_id] = {
                "user_id": inner.get("user_id"),
                "name": name,
                "created_at": datetime.now(timezone.utc).isoformat(),
            }

            audit_log({
                "event": "THREAD_INIT",
                "id": request_id,
                "session_id": session_id,
            })

            # Return minimal JSON — HumanBound just needs a thread/session ID
            return {
                "id": session_id,
                "object": "thread",
                "created_at": int(time.time()),
                "metadata": {
                    "user_id": inner.get("user_id"),
                    "welcome_message": inner.get("welcome_message", ""),
                },
            }
        else:
            errors = inner.get("error", [])
            raise HTTPException(status_code=400, detail={"status": "failed", "errors": errors})

    except HTTPException:
        raise
    except Exception as e:
        log.error(f"[{request_id}] Thread init error: {e}")
        raise HTTPException(status_code=502, detail=f"Thread init error: {e}")


@app.post("/chat")
async def humanbound_chat(request: Request, authorization: str = Header(default="")):
    """HumanBound chat_completion — accepts {"content": "..."} and returns AI reply."""
    verify_auth(authorization)

    if not check_rate_limit():
        raise HTTPException(status_code=429, detail="Rate limited")

    body = await request.json()
    user_message = body.get("content", "")
    if not user_message:
        raise HTTPException(status_code=400, detail="Missing 'content' in body")

    request_id = str(uuid.uuid4())[:8]

    audit_log({
        "event": "REQUEST",
        "id": request_id,
        "endpoint": "/chat",
        "message": user_message[:500],
        "session_id": _active_session,
    })

    log.info(f"[{request_id}] /chat: {user_message[:80]}...")

    try:
        target_body = build_target_body(user_message, session_id=_active_session)
        response_data = await send_to_target(target_body)
        reply = extract_response_text(response_data)
    except Exception as e:
        audit_log({"event": "TARGET_ERROR", "id": request_id, "error": str(e)})
        log.error(f"[{request_id}] Target error: {e}")
        raise HTTPException(status_code=502, detail=f"Target error: {e}")

    audit_log({
        "event": "RESPONSE",
        "id": request_id,
        "endpoint": "/chat",
        "reply": reply[:500],
    })

    log.info(f"[{request_id}] ← {len(reply)} chars")

    # Return plain content — HumanBound expects the response body to be the reply
    return {
        "id": f"msg-{request_id}",
        "content": reply,
        "role": "assistant",
    }


# ── Health ─────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "target": TARGET_API,
        "active_session": _active_session,
        "requests": seq_counter,
    }


@app.post("/v1/update-jwt")
async def update_jwt(request: Request, authorization: str = Header(default="")):
    verify_auth(authorization)
    global JWT_TOKEN
    body = await request.json()
    new_token = body.get("token", "")
    if not new_token:
        raise HTTPException(status_code=400, detail="Missing 'token' in body")
    JWT_TOKEN = new_token
    audit_log({"event": "JWT_UPDATED", "token_prefix": new_token[:10] + "..."})
    log.info("JWT token updated")
    return {"status": "updated"}


# ── Entry Point ────────────────────────────────────────────────────────────

if __name__ == "__main__":
    banner = f"""
╔══════════════════════════════════════════════════════╗
║  DeepCyber OpenAI Wrapper v1.0                       ║
║                                                      ║
║  Target:   {TARGET_API:<42}║
║  Port:     {LISTEN_PORT:<42}║
║  Model:    {MODEL_NAME:<42}║
║  Log:      {str(audit_log_path):<42}║
╚══════════════════════════════════════════════════════╝
"""
    print(banner)

    if RELAY_SECRET == "CHANGE_ME_TO_RANDOM_SECRET":
        log.warning("USING DEFAULT SECRET — set RELAY_SECRET env var!")

    if not JWT_TOKEN:
        log.warning("No JWT_TOKEN set — requests will not have Authorization header")

    audit_log({
        "event": "WRAPPER_STARTED",
        "target": TARGET_API,
        "port": LISTEN_PORT,
        "model": MODEL_NAME,
    })

    uvicorn.run(app, host="0.0.0.0", port=LISTEN_PORT, log_level="info")
