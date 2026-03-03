#!/usr/bin/env python3
"""Red Teaming CLI (using HumanBound)

A command-line tool that generates the bot.json configuration from
target.yaml and drives the HumanBound CLI (`hb`) to run OWASP-aligned
adversarial tests against the target API.

Usage:
    python redteam.py setup          # Generate bot.json from target.yaml
    python redteam.py init           # Scan the bot and create a project
    python redteam.py test           # Run adversarial tests (default: owasp_multi_turn)
    python redteam.py test --single  # Run single-turn attacks
    python redteam.py test --adaptive # Run adaptive multi-turn attacks
    python redteam.py status         # Check experiment status
    python redteam.py logs           # View test findings
    python redteam.py logs --failed  # View only failed findings
    python redteam.py posture        # View security posture score
    python redteam.py guardrails     # Export guardrail rules
    python redteam.py full           # Run the full workflow end-to-end
"""

import argparse
import json
import os
import subprocess
import sys

from shared.config import load_target_config, get_api_url, get_request_body, get_project_dir, load_policy, build_policy_text
from shared.auth import get_auth_headers


# ── Helpers ──────────────────────────────────────────────────────────────

def _bot_config_path():
    """Return the path to bot.json inside the project directory."""
    path = os.path.join(get_project_dir(), "humanbound", "bot.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


# ── Constants ───────────────────────────────────────────────────────────

TEST_CATEGORIES = {
    "single": "humanbound/adversarial/owasp_single_turn",
    "multi": "humanbound/adversarial/owasp_multi_turn",
    "agentic": "humanbound/adversarial/owasp_agentic_multi_turn",
    "behavioral": "humanbound/behavioral/qa",
    "workflow": "humanbound/adversarial/owasp_workflow",
    "auditor": "humanbound/adversarial/logs_auditor",
}

TEST_LEVELS = ("unit", "system", "acceptance")


def run(cmd, check=True):
    """Run a shell command, streaming output to the terminal."""
    print(f"\n>>> {cmd}\n")
    result = subprocess.run(cmd, shell=True, check=False)
    if check and result.returncode != 0:
        print(f"\nCommand exited with code {result.returncode}")
        return False
    return True


def ensure_bot_json():
    """Make sure bot.json exists, generating it if needed."""
    if not os.path.exists(_bot_config_path()):
        print("bot.json not found — generating it now.\n")
        cmd_setup(None)


def ensure_logged_in():
    """Check HumanBound login status, prompt to log in if needed."""
    result = subprocess.run(
        "hb whoami",
        shell=True,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print("You are not logged in to HumanBound.")
        print("Opening browser for authentication...\n")
        run("hb login")


# ── Commands ────────────────────────────────────────────────────────────

def cmd_setup(_args):
    """Generate bot.json from target.yaml and current auth credentials."""
    config = load_target_config()
    headers = get_auth_headers(config)
    api_url = get_api_url(config)

    # Session header
    session_cfg = config.get("session", {})
    session_header = session_cfg.get("header", "")
    if session_header:
        headers[session_header] = "humanbound-run"

    # Build init payload (session reset command)
    init_command = session_cfg.get("init_command", "")
    init_payload = get_request_body(init_command, config) if init_command else {}

    # Build chat payload with $PROMPT placeholder (HumanBound replaces it)
    chat_payload = get_request_body("$PROMPT", config)

    bot_config = {
        "streaming": False,
        "thread_auth": {
            "endpoint": "",
            "headers": {},
            "payload": {},
        },
        "thread_init": {
            "endpoint": api_url,
            "headers": headers,
            "payload": init_payload,
        },
        "chat_completion": {
            "endpoint": api_url,
            "headers": headers,
            "payload": chat_payload,
        },
    }

    bot_path = _bot_config_path()
    with open(bot_path, "w") as f:
        json.dump(bot_config, f, indent=2)

    target_name = config["target"]["name"]
    auth_mode = config["auth"]["mode"]
    print(f"Generated {bot_path}")
    print(f"  Target:  {target_name}")
    print(f"  API URL: {api_url}")
    print(f"  Auth:    {auth_mode}")
    print(f"  Chat completion: uses $PROMPT placeholder for attack payloads")


def _write_policy_prompt(config):
    """Write policy text to a temp file for HumanBound --prompt flag.

    Returns the file path, or None if no policy is defined.
    """
    policy = load_policy(config)
    if not policy:
        return None
    policy_text = build_policy_text(policy)
    if not policy_text:
        return None
    prompt_path = os.path.join(get_project_dir(config), "humanbound", "policy_prompt.txt")
    os.makedirs(os.path.dirname(prompt_path), exist_ok=True)
    with open(prompt_path, "w") as f:
        f.write(policy_text)
    return prompt_path


def cmd_init(_args):
    """Scan the bot and create a HumanBound project."""
    ensure_logged_in()
    ensure_bot_json()
    config = load_target_config()
    name = config["target"]["name"]

    # Pass policy as scope prompt if available
    prompt_path = _write_policy_prompt(config)
    prompt_flag = f" --prompt {prompt_path}" if prompt_path else ""
    if prompt_path:
        print("==> Policy loaded — passing as scope prompt to HumanBound")

    run(f'hb init --name "{name}" --endpoint {_bot_config_path()}{prompt_flag} --yes')


def cmd_test(args):
    """Run adversarial tests against the API."""
    ensure_logged_in()
    ensure_bot_json()
    bot_path = _bot_config_path()

    # Determine test category
    if getattr(args, "single", False):
        category = TEST_CATEGORIES["single"]
    elif getattr(args, "agentic", False):
        category = TEST_CATEGORIES["agentic"]
    elif getattr(args, "behavioral", False):
        category = TEST_CATEGORIES["behavioral"]
    elif getattr(args, "workflow", False):
        category = TEST_CATEGORIES["workflow"]
    elif getattr(args, "auditor", False):
        category = TEST_CATEGORIES["auditor"]
    elif getattr(args, "adaptive", False):
        category = TEST_CATEGORIES["multi"]
    else:
        category = TEST_CATEGORIES["multi"]

    # Determine test level
    level = getattr(args, "level", "unit")
    if level not in TEST_LEVELS:
        sys.exit(f"Error: level must be one of {TEST_LEVELS}")

    # Build command
    cmd = (
        f"hb test"
        f" -e {bot_path}"
        f" -t {category}"
        f" -l {level}"
        f" --wait"
    )

    if getattr(args, "adaptive", False):
        cmd += " --adaptive"

    if getattr(args, "fail_on", None):
        cmd += f" --fail-on={args.fail_on}"

    run(cmd)


def cmd_status(args):
    """Check experiment status."""
    ensure_logged_in()
    cmd = "hb status"
    if getattr(args, "watch", False):
        cmd += " --watch"
    run(cmd)


def cmd_logs(args):
    """View test findings."""
    ensure_logged_in()
    cmd = "hb logs"
    if getattr(args, "failed", False):
        cmd += " --verdict fail"
    run(cmd)


def cmd_posture(_args):
    """View security posture score."""
    ensure_logged_in()
    run("hb posture")


def cmd_guardrails(args):
    """Export guardrail rules."""
    ensure_logged_in()
    vendor = getattr(args, "vendor", "humanbound")
    fmt = getattr(args, "format", "json")
    cmd = f"hb guardrails --vendor {vendor} --format {fmt}"
    if getattr(args, "output", None):
        cmd += f" -o {args.output}"
    run(cmd)


def cmd_full(_args):
    """Run the full red teaming workflow end-to-end."""
    config = load_target_config()
    target_name = config["target"]["name"]

    print("=" * 60)
    print(f"  {target_name} — Full Red Teaming Workflow")
    print("=" * 60)

    # Step 1: Setup
    print("\n--- Step 1/6: Generating bot.json ---")
    cmd_setup(None)

    # Step 2: Login check
    print("\n--- Step 2/6: Checking authentication ---")
    ensure_logged_in()

    # Step 3: Init project (with policy if available)
    bot_path = _bot_config_path()
    print("\n--- Step 3/6: Scanning bot and creating project ---")
    prompt_path = _write_policy_prompt(config)
    prompt_flag = f" --prompt {prompt_path}" if prompt_path else ""
    if prompt_path:
        print("    Policy loaded — passing as scope prompt")
    run(f'hb init --name "{target_name}" --endpoint {bot_path}{prompt_flag} --yes')

    # Step 4: Run single-turn attacks
    print("\n--- Step 4/6: Running single-turn OWASP attacks ---")
    run(
        f"hb test -e {bot_path}"
        f" -t {TEST_CATEGORIES['single']}"
        f" -l unit --wait",
        check=False,
    )

    # Step 5: Run multi-turn attacks
    print("\n--- Step 5/6: Running multi-turn OWASP attacks ---")
    run(
        f"hb test -e {bot_path}"
        f" -t {TEST_CATEGORIES['multi']}"
        f" -l unit --wait",
        check=False,
    )

    # Step 6: Results
    print("\n--- Step 6/6: Results ---")
    print("\n>> Security Posture:")
    run("hb posture", check=False)

    print("\n>> Failed Findings:")
    run("hb logs --verdict fail", check=False)

    print("\n" + "=" * 60)
    print("  Red teaming complete!")
    print("  Run 'python redteam.py guardrails' to export hardening rules.")
    print("=" * 60)


# ── CLI Parser ──────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Red Teaming CLI (powered by HumanBound)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  python redteam.py setup              Generate bot.json\n"
            "  python redteam.py init               Scan bot and create project\n"
            "  python redteam.py test               Run multi-turn OWASP attacks\n"
            "  python redteam.py test --single       Run single-turn attacks\n"
            "  python redteam.py test --adaptive     Run adaptive attacks\n"
            "  python redteam.py test --level system  Run deeper system-level tests\n"
            "  python redteam.py full                Run the complete workflow\n"
            "  python redteam.py posture             View security score\n"
            "  python redteam.py logs --failed       View failed findings only\n"
            "  python redteam.py guardrails          Export hardening rules\n"
        ),
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # setup
    subparsers.add_parser("setup", help="Generate bot.json from target.yaml")

    # init
    subparsers.add_parser("init", help="Scan bot and create a HumanBound project")

    # test
    test_parser = subparsers.add_parser("test", help="Run adversarial tests")
    test_type = test_parser.add_mutually_exclusive_group()
    test_type.add_argument("--single", action="store_true", help="Single-turn OWASP attacks")
    test_type.add_argument("--agentic", action="store_true", help="Agentic multi-turn attacks")
    test_type.add_argument("--behavioral", action="store_true", help="Behavioral QA tests")
    test_type.add_argument("--workflow", action="store_true", help="OWASP workflow attacks")
    test_type.add_argument("--auditor", action="store_true", help="Logs auditor analysis")
    test_type.add_argument("--adaptive", action="store_true", help="Adaptive multi-turn attacks")
    test_parser.add_argument(
        "--level", choices=TEST_LEVELS, default="unit",
        help="Testing depth: unit (~20min), system (~45min), acceptance (~90min)",
    )
    test_parser.add_argument(
        "--fail-on", choices=("critical", "high", "medium", "low", "any"),
        help="Exit with error if findings meet this severity threshold",
    )

    # status
    status_parser = subparsers.add_parser("status", help="Check experiment status")
    status_parser.add_argument("--watch", action="store_true", help="Poll until complete")

    # logs
    logs_parser = subparsers.add_parser("logs", help="View test findings")
    logs_parser.add_argument("--failed", action="store_true", help="Show only failed findings")

    # posture
    subparsers.add_parser("posture", help="View security posture score")

    # guardrails
    gr_parser = subparsers.add_parser("guardrails", help="Export guardrail rules")
    gr_parser.add_argument(
        "--vendor", choices=("humanbound", "openai", "azure", "bedrock"),
        default="humanbound", help="Target vendor format",
    )
    gr_parser.add_argument("--format", choices=("json", "yaml"), default="json")
    gr_parser.add_argument("-o", "--output", help="Output file path")

    # full
    subparsers.add_parser("full", help="Run the full red teaming workflow end-to-end")

    args = parser.parse_args()

    commands = {
        "setup": cmd_setup,
        "init": cmd_init,
        "test": cmd_test,
        "status": cmd_status,
        "logs": cmd_logs,
        "posture": cmd_posture,
        "guardrails": cmd_guardrails,
        "full": cmd_full,
    }

    commands[args.command](args)


if __name__ == "__main__":
    main()
