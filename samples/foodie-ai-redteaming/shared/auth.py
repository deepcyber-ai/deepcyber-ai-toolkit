#!/usr/bin/env python3
"""Shared authentication helper for the Foodie AI API.

Handles login and token refresh via the /auth/token and /auth/refresh
endpoints. Used by all red-teaming tool integrations in this repo.

Can also be run directly to verify credentials:
    python shared/auth.py
"""

import os
import sys

import requests
from dotenv import load_dotenv

# Load .env from the repo root (one level up from shared/)
_ENV_PATH = os.path.join(os.path.dirname(__file__), "..", ".env")
load_dotenv(_ENV_PATH)


def load_credentials():
    """Read API URL and credentials from environment variables."""
    api_url = os.environ.get("FOODIE_API_URL", "").rstrip("/")
    username = os.environ.get("FOODIE_USERNAME", "")
    password = os.environ.get("FOODIE_PASSWORD", "")

    if not api_url or not username or not password:
        sys.exit(
            "Error: FOODIE_API_URL, FOODIE_USERNAME, and FOODIE_PASSWORD must be set.\n"
            "Copy .env.example to .env and fill in your values."
        )
    return api_url, username, password


def get_token(api_url, username, password):
    """Exchange username/password for an ID token and refresh token.

    Returns:
        dict with keys: id_token, refresh_token, expires_in, token_type
    """
    resp = requests.post(
        f"{api_url}/auth/token",
        json={"username": username, "password": password},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()


def refresh_token(api_url, refresh_tok):
    """Exchange a refresh token for a new ID token.

    Returns:
        dict with keys: id_token, expires_in, token_type
    """
    resp = requests.post(
        f"{api_url}/auth/refresh",
        json={"refresh_token": refresh_tok},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()


if __name__ == "__main__":
    url, user, pwd = load_credentials()
    print(f"API:  {url}")
    print(f"User: {user}")
    print()

    auth = get_token(url, user, pwd)
    print(f"Login OK")
    print(f"  id_token:      {auth['id_token'][:40]}...")
    print(f"  refresh_token: {auth['refresh_token'][:40]}...")
    print(f"  expires_in:    {auth['expires_in']}s")

    new_auth = refresh_token(url, auth["refresh_token"])
    print(f"\nRefresh OK")
    print(f"  id_token:      {new_auth['id_token'][:40]}...")
    print(f"  expires_in:    {new_auth['expires_in']}s")
