#!/usr/bin/env python3
"""Giskard LLM security scan.

Wraps the target REST API as a Giskard model and runs the built-in
vulnerability detectors (prompt injection, information disclosure,
harmful content, stereotypes, hallucination, etc.).

Reads target API configuration from target.yaml.

Usage:
    python scan.py                    # run all detectors
    python scan.py --only prompt_injection information_disclosure
    python scan.py --output report.html
"""

import argparse
import os
import sys

# Save grader key before any imports (litellm's dotenv may overwrite env vars).
_grader_key = os.environ.get("GRADER_API_KEY")

import pandas as pd
import requests

from shared.config import (
    load_target_config,
    get_api_url,
    get_request_body,
    get_project_dir,
    extract_response,
    load_policy,
    build_policy_text,
    ensure_session,
)
from shared.auth import get_auth_headers

import giskard
from giskard.llm.client import set_default_client

# Configure Giskard's internal LLM for test generation and scoring.
# litellm auto-loads .env which sets OPENAI_BASE_URL to RunPod.
# We must create a client with explicit OpenAI settings to override.
_giskard_model = os.environ.get("GISKARD_MODEL", "gpt-4o-mini")
if _grader_key:
    from giskard.llm.client.litellm import LiteLLMClient as _LiteLLMClient
    _client = _LiteLLMClient(
        model=_giskard_model,
        completion_params={
            "api_key": _grader_key,
            "api_base": "https://api.openai.com/v1",
        },
    )
    set_default_client(_client)
else:
    from giskard.llm.client import set_llm_model
    set_llm_model(_giskard_model)


def make_predict_fn(config):
    """Return a prediction function that calls the target API."""
    api_url = get_api_url(config)
    headers = get_auth_headers(config)

    # Session header
    session_cfg = config.get("session", {})
    session_header = session_cfg.get("header", "")
    if session_header:
        headers[session_header] = "giskard-scan"

    def predict(df: pd.DataFrame) -> list[str]:
        import json as _json
        outputs = []
        for message in df["question"].values:
            try:
                body = get_request_body(str(message), config)
                resp = requests.post(
                    api_url,
                    json=body,
                    headers=headers,
                    timeout=30,
                )
                resp.raise_for_status()
                raw = extract_response(resp.json(), config)
                # Unwrap double-encoded JSON (e.g. InvestAI nested payload)
                if isinstance(raw, str) and raw.startswith("{"):
                    try:
                        inner = _json.loads(raw)
                        raw = inner.get("message") or inner.get("error", raw)
                    except _json.JSONDecodeError:
                        pass
                outputs.append(str(raw))
            except Exception as e:
                outputs.append(f"[Error: {e}]")
        return outputs

    return predict


def main():
    parser = argparse.ArgumentParser(description="Run Giskard LLM scan")
    parser.add_argument(
        "--only",
        nargs="+",
        help="Run only these detectors (e.g. prompt_injection information_disclosure)",
    )
    default_output = os.path.join(get_project_dir(), "giskard_report.html")
    parser.add_argument(
        "--output",
        default=default_output,
        help=f"Output HTML report path (default: {default_output})",
    )
    args = parser.parse_args()

    # Load config and ensure session
    config = load_target_config()
    ensure_session(config)
    target_name = config["target"]["name"]
    description = config["target"].get("description", "")
    api_url = get_api_url(config)

    # Enrich description with policy if available
    policy = load_policy(config)
    if policy:
        policy_text = build_policy_text(policy)
        base_desc = description.strip() if isinstance(description, str) else str(description).strip()
        description = f"{base_desc}\n\n{policy_text}" if base_desc else policy_text
        print("==> Policy loaded — enriching model description for detectors")

    print(f"==> Target: {target_name}")
    print(f"==> API:    {api_url}")
    print(f"==> Auth:   {config['auth']['mode']}")

    # Wrap the API as a Giskard model
    print("==> Creating Giskard model wrapper...")
    model = giskard.Model(
        model=make_predict_fn(config),
        model_type="text_generation",
        name=target_name,
        description=description.strip() if isinstance(description, str) else str(description).strip(),
        feature_names=["question"],
    )

    # Run the scan
    print("==> Running Giskard scan...")
    scan_kwargs = {}
    if args.only:
        scan_kwargs["only"] = args.only
        print(f"    Detectors: {', '.join(args.only)}")
    else:
        print("    Detectors: all")

    results = giskard.scan(model, **scan_kwargs)

    # Display summary
    print("\n==> Scan complete!")
    print(results)

    # Save HTML report
    results.to_html(args.output)
    print(f"\n==> Report saved to {args.output}")
    print(f"    Open it with: open {args.output}")


if __name__ == "__main__":
    main()
