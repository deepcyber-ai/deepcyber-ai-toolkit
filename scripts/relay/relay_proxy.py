#!/usr/bin/env python3
"""
DeepCyber Relay Proxy
=====================
Runs on the tester's laptop inside the client network.
Receives requests from any cloud-based tool (HumanBound, Promptfoo, etc.)
via tunnel (Cloudflare/ngrok/SSH), forwards them to the internal API,
returns responses.

All requests/responses are logged with tamper-evident chained SHA-256 hashes
for regulatory audit compliance.

Usage:
    export TARGET_API="https://internal-api.client.com/v1"
    export RELAY_SECRET="$(openssl rand -hex 32)"
    export JWT_TOKEN="your-jwt-token"
    python relay_proxy.py

Then in another terminal:
    cloudflared tunnel --url http://localhost:8443
"""

import json
import time
import uuid
import hashlib
import logging
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    from flask import Flask, request, Response
    import requests as http_client
except ImportError:
    print("Missing dependencies. Install with:")
    print("  pip install flask requests")
    sys.exit(1)


# ── Configuration ──────────────────────────────────────────────────────────

TARGET_API_BASE = os.getenv("TARGET_API", "http://localhost:8080")
LISTEN_PORT     = int(os.getenv("RELAY_PORT", "8443"))
SHARED_SECRET   = os.getenv("RELAY_SECRET", "CHANGE_ME_TO_RANDOM_SECRET")
JWT_TOKEN       = os.getenv("JWT_TOKEN", "")
LOG_DIR         = Path(os.getenv("LOG_DIR", "./audit_logs"))
RATE_LIMIT_RPS  = int(os.getenv("RATE_LIMIT", "10"))

# Optional: comma-separated list of allowed path prefixes
# If empty, all paths are allowed
ALLOWED_PATHS = (
    os.getenv("ALLOWED_PATHS", "").split(",")
    if os.getenv("ALLOWED_PATHS")
    else []
)

# Optional: comma-separated list of blocked path prefixes (e.g. admin endpoints)
BLOCKED_PATHS = (
    os.getenv("BLOCKED_PATHS", "").split(",")
    if os.getenv("BLOCKED_PATHS")
    else []
)


# ── Setup ──────────────────────────────────────────────────────────────────

app = Flask(__name__)
LOG_DIR.mkdir(parents=True, exist_ok=True)

# Audit log file — one per session
audit_log_path = LOG_DIR / f"relay_audit_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jsonl"
seq_counter = 0
prev_hash = "GENESIS"

# Console logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
log = logging.getLogger("relay")

# Rate limiter state
request_times = []


# ── Audit Logging (tamper-evident) ─────────────────────────────────────────

def audit_log(entry: dict):
    """
    Append a tamper-evident log entry.
    Each entry contains:
    - Sequential counter
    - UTC timestamp
    - Hash of previous entry (chain)
    - SHA-256 hash of (prev_hash + current entry JSON)
    
    If any entry is modified, inserted, or deleted, the chain breaks
    and can be detected by the verification script.
    """
    global seq_counter, prev_hash
    seq_counter += 1
    entry["seq"] = seq_counter
    entry["timestamp"] = datetime.now(timezone.utc).isoformat()
    entry["prev_hash"] = prev_hash

    # Compute chain hash
    raw = json.dumps(entry, sort_keys=True)
    entry["hash"] = hashlib.sha256(f"{prev_hash}:{raw}".encode()).hexdigest()
    prev_hash = entry["hash"]

    with open(audit_log_path, "a") as f:
        f.write(json.dumps(entry) + "\n")


# ── Rate Limiting ──────────────────────────────────────────────────────────

def check_rate_limit() -> bool:
    """Simple sliding-window rate limiter."""
    now = time.time()
    request_times[:] = [t for t in request_times if now - t < 1.0]
    if len(request_times) >= RATE_LIMIT_RPS:
        return False
    request_times.append(now)
    return True


# ── Authentication ─────────────────────────────────────────────────────────

def verify_caller() -> bool:
    """Verify request carries the correct shared secret."""
    token = request.headers.get("X-Relay-Secret", "")
    return token == SHARED_SECRET


# ── Path Filtering ─────────────────────────────────────────────────────────

def is_path_allowed(path: str) -> bool:
    """
    Check if the requested path is permitted.
    - If BLOCKED_PATHS is set, deny any matching prefix
    - If ALLOWED_PATHS is set, only permit matching prefixes
    - If neither is set, allow everything
    """
    # Check blocklist first
    if BLOCKED_PATHS and BLOCKED_PATHS != [""]:
        if any(path.startswith(p.strip()) for p in BLOCKED_PATHS if p.strip()):
            return False

    # Check allowlist
    if ALLOWED_PATHS and ALLOWED_PATHS != [""]:
        return any(path.startswith(p.strip()) for p in ALLOWED_PATHS if p.strip())

    return True


# ── Core Relay Handler ─────────────────────────────────────────────────────

@app.route("/", defaults={"path": ""}, methods=[
    "GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"
])
@app.route("/<path:path>", methods=[
    "GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"
])
def relay(path):
    request_id = str(uuid.uuid4())[:8]

    # ── Gate: Authentication ──
    if not verify_caller():
        audit_log({
            "event": "AUTH_REJECTED",
            "id": request_id,
            "src": request.remote_addr
        })
        log.warning(f"[{request_id}] AUTH REJECTED from {request.remote_addr}")
        return Response("Unauthorized", status=401)

    # ── Gate: Rate limiting ──
    if not check_rate_limit():
        audit_log({"event": "RATE_LIMITED", "id": request_id})
        log.warning(f"[{request_id}] RATE LIMITED")
        return Response("Rate limited", status=429)

    # ── Gate: Path filtering ──
    if not is_path_allowed(f"/{path}"):
        audit_log({
            "event": "PATH_BLOCKED",
            "id": request_id,
            "path": f"/{path}"
        })
        log.warning(f"[{request_id}] PATH BLOCKED: /{path}")
        return Response("Path not allowed", status=403)

    # ── Build target request ──
    target_url = f"{TARGET_API_BASE.rstrip('/')}/{path}"
    if request.query_string:
        target_url += f"?{request.query_string.decode()}"

    # Forward headers, strip relay-specific and hop-by-hop headers
    skip_headers = {
        "host", "x-relay-secret", "transfer-encoding",
        "connection", "keep-alive", "proxy-authenticate",
        "proxy-authorization", "te", "trailers", "upgrade"
    }
    headers = {
        k: v for k, v in request.headers
        if k.lower() not in skip_headers
    }

    # Inject JWT if configured
    if JWT_TOKEN:
        headers["Authorization"] = f"Bearer {JWT_TOKEN}"

    body = request.get_data()

    # ── Log request ──
    audit_log({
        "event": "REQUEST",
        "id": request_id,
        "method": request.method,
        "target": target_url,
        "headers": {k: v for k, v in headers.items()
                    if k.lower() != "authorization"},  # Don't log JWT
        "body_size": len(body),
        "body_preview": body[:1000].decode("utf-8", errors="replace")
    })

    log.info(f"[{request_id}] {request.method} /{path} → {target_url}")

    # ── Forward to internal API ──
    try:
        resp = http_client.request(
            method=request.method,
            url=target_url,
            headers=headers,
            data=body,
            timeout=30,
            verify=True,        # Verify TLS — set False if internal CA issues
            allow_redirects=False
        )
    except http_client.exceptions.ConnectionError as e:
        audit_log({
            "event": "TARGET_UNREACHABLE",
            "id": request_id,
            "error": str(e)
        })
        log.error(f"[{request_id}] TARGET UNREACHABLE: {e}")
        return Response(
            json.dumps({"error": "relay_target_unreachable", "detail": str(e)}),
            status=502,
            content_type="application/json"
        )
    except http_client.exceptions.Timeout:
        audit_log({
            "event": "TARGET_TIMEOUT",
            "id": request_id
        })
        log.error(f"[{request_id}] TARGET TIMEOUT (30s)")
        return Response(
            json.dumps({"error": "relay_target_timeout"}),
            status=504,
            content_type="application/json"
        )
    except Exception as e:
        audit_log({
            "event": "TARGET_ERROR",
            "id": request_id,
            "error": str(e)
        })
        log.error(f"[{request_id}] TARGET ERROR: {e}")
        return Response(
            json.dumps({"error": "relay_error", "detail": str(e)}),
            status=502,
            content_type="application/json"
        )

    # ── Log response ──
    audit_log({
        "event": "RESPONSE",
        "id": request_id,
        "status": resp.status_code,
        "body_size": len(resp.content),
        "body_preview": resp.content[:1000].decode("utf-8", errors="replace")
    })

    log.info(f"[{request_id}] ← {resp.status_code} ({len(resp.content)} bytes)")

    # ── Return to HumanBound ──
    excluded = {
        "transfer-encoding", "content-encoding",
        "content-length", "connection"
    }
    response_headers = {
        k: v for k, v in resp.headers.items()
        if k.lower() not in excluded
    }

    return Response(
        resp.content,
        status=resp.status_code,
        headers=response_headers
    )


# ── Health & Status Endpoints ──────────────────────────────────────────────

@app.route("/__relay/health")
def health():
    """Unauthenticated health check — tunnel liveness."""
    return {"status": "ok", "target": TARGET_API_BASE, "requests": seq_counter}


@app.route("/__relay/stats")
def stats():
    """Authenticated stats endpoint."""
    if not verify_caller():
        return Response("Unauthorized", status=401)
    return {
        "total_requests": seq_counter,
        "log_file": str(audit_log_path),
        "log_size_bytes": audit_log_path.stat().st_size if audit_log_path.exists() else 0,
        "target": TARGET_API_BASE,
        "rate_limit_rps": RATE_LIMIT_RPS,
        "path_allowlist": ALLOWED_PATHS or "ALL",
        "path_blocklist": BLOCKED_PATHS or "NONE",
    }


@app.route("/__relay/update-jwt", methods=["POST"])
def update_jwt():
    """Hot-swap JWT without restarting the relay."""
    global JWT_TOKEN
    if not verify_caller():
        return Response("Unauthorized", status=401)
    
    data = request.get_json(silent=True) or {}
    new_token = data.get("token", "")
    if not new_token:
        return Response("Missing 'token' in body", status=400)
    
    JWT_TOKEN = new_token
    audit_log({"event": "JWT_UPDATED", "token_prefix": new_token[:10] + "..."})
    log.info("JWT token updated via API")
    return {"status": "updated"}


# ── Entry Point ────────────────────────────────────────────────────────────

if __name__ == "__main__":
    banner = f"""
╔══════════════════════════════════════════════════╗
║  DeepCyber Relay Proxy v1.0                     ║
║                                                  ║
║  Target:  {TARGET_API_BASE:<38} ║
║  Port:    {LISTEN_PORT:<38} ║
║  Log:     {str(audit_log_path):<38} ║
║  Rate:    {RATE_LIMIT_RPS:<38} req/s ║
╚══════════════════════════════════════════════════╝
"""
    print(banner)

    if SHARED_SECRET == "CHANGE_ME_TO_RANDOM_SECRET":
        log.warning("⚠  USING DEFAULT SECRET — set RELAY_SECRET env var!")

    if not JWT_TOKEN:
        log.warning("⚠  No JWT_TOKEN set — requests will not have Authorization header")

    audit_log({
        "event": "RELAY_STARTED",
        "target": TARGET_API_BASE,
        "port": LISTEN_PORT,
        "path_allowlist": ALLOWED_PATHS or "ALL",
        "path_blocklist": BLOCKED_PATHS or "NONE"
    })

    # Listen on 0.0.0.0 inside the container so Docker port mapping works.
    # The Cloudflare Tunnel connects to the host-mapped port.
    app.run(
        host="0.0.0.0",
        port=LISTEN_PORT,
        debug=False,
        threaded=True           # Handle concurrent requests from HumanBound
    )
