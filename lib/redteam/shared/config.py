#!/usr/bin/env python3
"""Shared configuration loader for red team projects.

Reads target.yaml from the project root and provides a structured config
object that all tool integrations use.

Usage:
    from shared.config import load_target_config, get_api_url
    config = load_target_config()
    print(config["target"]["name"])
"""

import copy
import json
import os
import sys

import yaml

_CONFIG_CACHE = None


def load_target_config():
    """Load and return the target configuration from target.yaml.

    Searches for target.yaml in (first match wins):
      1. PROJECT_DIR env var (set by dcr CLI)
      2. REPO_ROOT env var (legacy)
      3. Parent of this file (legacy: code alongside config)
      4. Current working directory
      5. Parent of current working directory

    Also loads .env from the same directory as target.yaml.
    """
    global _CONFIG_CACHE
    if _CONFIG_CACHE is not None:
        return _CONFIG_CACHE

    search_dirs = []
    if os.environ.get("PROJECT_DIR"):
        search_dirs.append(os.environ["PROJECT_DIR"])
    if os.environ.get("REPO_ROOT"):
        search_dirs.append(os.environ["REPO_ROOT"])
    search_dirs.append(os.path.join(os.path.dirname(__file__), ".."))
    search_dirs.append(os.getcwd())
    search_dirs.append(os.path.join(os.getcwd(), ".."))

    config_path = None
    for d in search_dirs:
        candidate = os.path.join(os.path.abspath(d), "target.yaml")
        if os.path.isfile(candidate):
            config_path = candidate
            break

    if config_path is None:
        sys.exit(
            "Error: target.yaml not found.\n"
            "Set PROJECT_DIR or run from the project directory."
        )

    # Load .env from same directory
    from dotenv import load_dotenv

    env_path = os.path.join(os.path.dirname(config_path), ".env")
    load_dotenv(env_path)

    with open(config_path) as f:
        config = yaml.safe_load(f)

    config["_project_dir"] = os.path.dirname(config_path)
    _CONFIG_CACHE = config
    return config


def get_project_dir(config=None):
    """Return the absolute path to the project directory."""
    if config is None:
        config = load_target_config()
    return config.get("_project_dir", os.getcwd())


def get_api_url(config=None):
    """Return the full API URL (base + path)."""
    if config is None:
        config = load_target_config()
    base = config["api"]["url"].rstrip("/")
    path = config["api"].get("path", "/")
    if path and path != "/":
        return f"{base}{path}"
    return base


def get_request_body(prompt, config=None):
    """Build the request body dict with the given prompt substituted in.

    Walks the body template from target.yaml and replaces any string
    containing ``{{PROMPT}}`` with the actual prompt text.
    """
    if config is None:
        config = load_target_config()
    template = config["request"]["body"]
    return _substitute(template, "{{PROMPT}}", prompt)


def get_response_field(config=None):
    """Return the dot-notation path to the response text field."""
    if config is None:
        config = load_target_config()
    return config["response"]["field"]


def extract_response(json_data, config=None):
    """Extract the AI's text reply from a JSON response using dot-notation.

    Supports paths like ``response``, ``data.text``, or
    ``choices.0.message.content``.
    """
    field = get_response_field(config)
    obj = json_data
    for part in field.split("."):
        if isinstance(obj, list) or part.isdigit():
            obj = obj[int(part)]
        else:
            obj = obj[part]
    return obj


def load_policy(config=None):
    """Load the policy section from target.yaml, including external documents.

    Returns a dict with keys: allowed_topics, forbidden_topics, must_refuse,
    expected_boundaries, documents (list of {label, content} dicts).
    Returns None if no policy section exists.
    """
    if config is None:
        config = load_target_config()

    policy = config.get("policy")
    if not policy:
        return None

    eng_dir = get_project_dir(config)
    docs = []
    for doc in policy.get("documents", []):
        doc_path = os.path.join(eng_dir, doc["path"])
        if os.path.isfile(doc_path):
            with open(doc_path) as f:
                docs.append({"label": doc.get("label", doc["path"]), "content": f.read()})
        else:
            print(f"Warning: policy document not found: {doc_path}", file=sys.stderr)

    return {
        "allowed_topics": policy.get("allowed_topics", []),
        "forbidden_topics": policy.get("forbidden_topics", []),
        "must_refuse": policy.get("must_refuse", []),
        "expected_boundaries": policy.get("expected_boundaries", []),
        "documents": docs,
    }


def build_policy_text(policy):
    """Convert a policy dict into a single text block for tool consumption.

    Tools that accept free-text policy descriptions (Promptfoo graderGuidance,
    Giskard model description, PyRIT scorer, Garak detector goal) use this.
    """
    if not policy:
        return ""

    sections = []
    for key, heading in [
        ("allowed_topics", "ALLOWED TOPICS"),
        ("forbidden_topics", "FORBIDDEN TOPICS"),
        ("must_refuse", "MUST REFUSE"),
        ("expected_boundaries", "EXPECTED BOUNDARIES"),
    ]:
        items = policy.get(key, [])
        if items:
            lines = "\n".join(f"- {item}" for item in items)
            sections.append(f"{heading}:\n{lines}")

    for doc in policy.get("documents", []):
        sections.append(f"--- {doc['label']} ---\n{doc['content']}")

    return "\n\n".join(sections)


_SESSION_ID = None


def build_init_request(config=None):
    """Build an initialize_session request body from target.yaml's init_payload.

    Returns the full request body dict, or None if no init_payload is configured.
    """
    if config is None:
        config = load_target_config()

    session_cfg = config.get("session", {})
    init_payload = session_cfg.get("init_payload")
    if not init_payload:
        return None

    body = copy.deepcopy(config["request"]["body"])

    # Replace the inner text with init_payload JSON
    try:
        body["input"]["message"]["parts"][0]["text"] = json.dumps(init_payload)
        # Remove session_id from init request (it comes back in the response)
        body["input"].pop("session_id", None)
    except (KeyError, IndexError, TypeError):
        # Non-nested format — substitute as prompt
        return _substitute(body, "{{PROMPT}}", json.dumps(init_payload))

    return body


def ensure_session(config=None):
    """Initialize a session with the target API and cache the session_id.

    Sends an initialize_session request using session.init_payload from
    target.yaml. Updates config["request"]["body"]["input"]["session_id"]
    in-place so all subsequent get_request_body() calls use the correct
    session_id.

    Returns the session_id, or None if no init_payload is configured.
    Subsequent calls return the cached session_id without re-initializing.
    """
    global _SESSION_ID
    if config is None:
        config = load_target_config()

    if _SESSION_ID is not None:
        try:
            config["request"]["body"]["input"]["session_id"] = _SESSION_ID
        except (KeyError, TypeError):
            pass
        return _SESSION_ID

    init_body = build_init_request(config)
    if init_body is None:
        return None

    import requests as _requests
    from shared.auth import get_auth_headers

    api_url = get_api_url(config)
    headers = get_auth_headers(config)
    headers["Content-Type"] = config["request"].get("content_type", "application/json")

    print(f"==> Initializing session at {api_url}...")

    try:
        resp = _requests.post(api_url, json=init_body, headers=headers, timeout=30)

        # Handle SSE response
        content_type = resp.headers.get("content-type", "")
        if "text/event-stream" in content_type:
            for line in resp.text.strip().split("\n"):
                if line.startswith("data: "):
                    data = json.loads(line[6:])
                    break
            else:
                data = resp.json()
        else:
            resp.raise_for_status()
            data = resp.json()

        # Parse the envelope
        inner_text = extract_response(data, config)
        inner = json.loads(inner_text) if isinstance(inner_text, str) else inner_text

        if inner.get("status") == "success":
            _SESSION_ID = inner.get("session_id")
            user_id = inner.get("user_id")
            welcome = inner.get("welcome_message", "")

            print(f"    Session ID: {_SESSION_ID}")
            if welcome:
                print(f"    Welcome: {welcome[:100]}")

            # Update config in-place for all subsequent calls
            try:
                config["request"]["body"]["input"]["session_id"] = _SESSION_ID
                if user_id:
                    config["request"]["body"]["input"]["user_id"] = user_id
            except (KeyError, TypeError):
                pass

            return _SESSION_ID
        else:
            errors = inner.get("error", [])
            msg = "; ".join(f"[{e.get('code')}] {e.get('message')}" for e in errors)
            print(f"    Session init failed: {msg}", file=sys.stderr)
            return None

    except Exception as e:
        print(f"    Session init error: {e}", file=sys.stderr)
        return None


def _substitute(obj, placeholder, value):
    """Recursively substitute *placeholder* with *value* in a nested structure."""
    if isinstance(obj, str):
        return obj.replace(placeholder, value)
    if isinstance(obj, dict):
        return {k: _substitute(v, placeholder, value) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_substitute(item, placeholder, value) for item in obj]
    return obj
