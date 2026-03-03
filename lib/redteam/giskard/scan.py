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

import pandas as pd
import requests

from shared.config import (
    load_target_config,
    get_api_url,
    get_request_body,
    get_engagement_dir,
    extract_response,
)
from shared.auth import get_auth_headers

import giskard


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
                outputs.append(extract_response(resp.json(), config))
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
    default_output = os.path.join(get_engagement_dir(), "giskard_report.html")
    parser.add_argument(
        "--output",
        default=default_output,
        help=f"Output HTML report path (default: {default_output})",
    )
    args = parser.parse_args()

    # Load config
    config = load_target_config()
    target_name = config["target"]["name"]
    description = config["target"].get("description", "")
    api_url = get_api_url(config)

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
