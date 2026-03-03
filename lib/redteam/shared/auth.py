#!/usr/bin/env python3
"""Pluggable authentication for red team engagements.

Supports multiple auth modes configured in target.yaml:
  - bearer_cognito  username/password exchange for JWT
  - api_key         static key in a header
  - basic           HTTP Basic auth
  - none            no authentication

Usage:
    from shared.auth import get_auth_headers, get_token
    headers = get_auth_headers()        # ready-to-use headers dict
    token   = get_token()               # raw bearer token string

Can also be run directly to verify credentials:
    python shared/auth.py
"""

import os
import sys

import requests

from shared.config import load_target_config, get_api_url


# ── Public API ───────────────────────────────────────────────────────

def get_auth_headers(config=None):
    """Return a headers dict with Content-Type, auth, and any extras."""
    if config is None:
        config = load_target_config()

    mode = config["auth"]["mode"]
    headers = {
        "Content-Type": config["request"].get("content_type", "application/json"),
    }

    # Extra headers from target.yaml
    for k, v in config.get("headers", {}).items():
        headers[k] = v

    if mode == "bearer_cognito":
        token_data = _cognito_login(config)
        field = config["auth"]["cognito"]["token_response_field"]
        headers["Authorization"] = f"Bearer {token_data[field]}"

    elif mode == "api_key":
        ak = config["auth"]["api_key"]
        key = os.environ.get(ak["env_var"], "")
        if not key:
            sys.exit(f"Error: {ak['env_var']} not set in .env")
        prefix = ak.get("prefix", "Bearer ")
        headers[ak.get("header", "Authorization")] = f"{prefix}{key}"

    elif mode == "basic":
        pass  # handled via requests auth= parameter

    elif mode == "none":
        pass

    else:
        sys.exit(f"Error: unknown auth mode '{mode}' in target.yaml")

    return headers


def get_basic_auth(config=None):
    """Return ``(user, password)`` for HTTP Basic auth, or ``None``."""
    if config is None:
        config = load_target_config()
    if config["auth"]["mode"] != "basic":
        return None
    basic = config["auth"]["basic"]
    return (
        os.environ.get(basic["env_user"], ""),
        os.environ.get(basic["env_pass"], ""),
    )


def get_token(config=None):
    """Return the raw bearer token string (for modes that produce one)."""
    if config is None:
        config = load_target_config()
    mode = config["auth"]["mode"]

    if mode == "bearer_cognito":
        data = _cognito_login(config)
        return data[config["auth"]["cognito"]["token_response_field"]]

    if mode == "api_key":
        ak = config["auth"]["api_key"]
        return os.environ.get(ak["env_var"], "")

    return ""


def get_token_data(config=None):
    """Return the full token response dict (cognito mode only)."""
    if config is None:
        config = load_target_config()
    if config["auth"]["mode"] == "bearer_cognito":
        return _cognito_login(config)
    return {}


# ── Internal ─────────────────────────────────────────────────────────

def _cognito_login(config):
    """Exchange username/password for a token response dict."""
    cognito = config["auth"]["cognito"]
    base_url = config["api"]["url"].rstrip("/")
    endpoint = f"{base_url}{cognito['token_endpoint']}"

    username = os.environ.get("TARGET_USERNAME", "")
    password = os.environ.get("TARGET_PASSWORD", "")
    if not username or not password:
        sys.exit(
            "Error: TARGET_USERNAME and TARGET_PASSWORD must be set in .env"
        )

    body = {}
    for k, v in cognito["token_request_body"].items():
        if isinstance(v, str):
            body[k] = (
                v.replace("{{USERNAME}}", username)
                .replace("{{PASSWORD}}", password)
            )
        else:
            body[k] = v

    print(f"Authenticating as {username}...", file=sys.stderr)
    resp = requests.post(endpoint, json=body, timeout=10)
    resp.raise_for_status()
    data = resp.json()
    token_field = cognito["token_response_field"]
    print(f"Token acquired (expires in {data.get('expires_in', '?')}s)", file=sys.stderr)
    return data


# ── CLI entry point ──────────────────────────────────────────────────

if __name__ == "__main__":
    config = load_target_config()
    print(f"Target:    {config['target']['name']}")
    print(f"API:       {get_api_url(config)}")
    print(f"Auth mode: {config['auth']['mode']}")
    print()

    headers = get_auth_headers(config)
    print("Auth OK")
    auth_val = headers.get("Authorization", "")
    if auth_val:
        print(f"  Token: {auth_val[:50]}...")
