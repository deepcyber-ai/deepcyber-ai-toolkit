#!/usr/bin/env python3
"""
Foodie AI — Red Teaming CLI (using AIandMe / HumanBound)

A command-line tool that generates the bot.json configuration from
environment variables and drives aiandme CLI commands to run OWASP-aligned
adversarial tests against the live Foodie AI API.

Usage:
    python redteam.py setup          # Generate bot.json from .env
    python redteam.py init           # Scan the bot and create an aiandme project
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

from dotenv import load_dotenv

# Add repo root to path for shared auth helper
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from shared.auth import get_token

# ── Constants ───────────────────────────────────────────────────────────

BOT_CONFIG_FILE = os.path.join(os.path.dirname(__file__), "bot.json")

TEST_CATEGORIES = {
    "single": "aiandme/adversarial/owasp_single_turn",
    "multi": "aiandme/adversarial/owasp_multi_turn",
    "agentic": "aiandme/adversarial/owasp_agentic_multi_turn",
    "behavioral": "aiandme/behavioral/behavioral",
}

TEST_LEVELS = ("unit", "system", "acceptance")


# ── Helpers ─────────────────────────────────────────────────────────────

def load_config():
    """Load API credentials from .env and return (url, token).

    Reads username/password from .env, calls /auth/token to get a JWT,
    and returns the API URL and Bearer token.
    """
    # Try local .env first, fall back to repo root .env
    local_env = os.path.join(os.path.dirname(__file__), ".env")
    root_env = os.path.join(os.path.dirname(__file__), "..", ".env")
    load_dotenv(local_env)
    load_dotenv(root_env)

    url = os.environ.get("FOODIE_API_URL")
    username = os.environ.get("FOODIE_USERNAME")
    password = os.environ.get("FOODIE_PASSWORD")
    if not url or not username or not password:
        sys.exit(
            "Error: FOODIE_API_URL, FOODIE_USERNAME, and FOODIE_PASSWORD must be set.\n"
            "Copy .env.example to .env and fill in your values."
        )

    print(f"Authenticating as {username}...")
    auth = get_token(url, username, password)
    token = auth["id_token"]
    print(f"Token acquired (expires in {auth['expires_in']}s)")
    return url, token


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
    if not os.path.exists(BOT_CONFIG_FILE):
        print("bot.json not found — generating it now.\n")
        cmd_setup(None)


def ensure_logged_in():
    """Check aiandme login status, prompt to log in if needed."""
    result = subprocess.run(
        "aiandme whoami",
        shell=True,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print("You are not logged in to AIandMe.")
        print("Opening browser for authentication...\n")
        run("aiandme login")


# ── Commands ────────────────────────────────────────────────────────────

def cmd_setup(_args):
    """Generate bot.json from environment variables."""
    url, token = load_config()

    bot_config = {
        "streaming": False,
        "thread_auth": {
            "endpoint": "",
            "headers": {},
            "payload": {},
        },
        "thread_init": {
            "endpoint": url,
            "headers": {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}",
                "x-session-id": "humanbound-run",
            },
            "payload": {"input": "clear"},
        },
        "chat_completion": {
            "endpoint": url,
            "headers": {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}",
                "x-session-id": "humanbound-run",
            },
            "payload": {"input": "$PROMPT"},
        },
    }

    with open(BOT_CONFIG_FILE, "w") as f:
        json.dump(bot_config, f, indent=2)

    print(f"Generated {BOT_CONFIG_FILE}")
    print(f"  API URL: {url}")
    print(f"  Auth: Bearer token (1 hour TTL)")
    print(f"  Thread init: sends 'clear' to reset session before tests")
    print(f"  Chat completion: uses $PROMPT placeholder for attack payloads")


def cmd_init(_args):
    """Scan the bot and create an aiandme project."""
    ensure_logged_in()
    ensure_bot_json()
    run(f'aiandme init -n "Foodie AI" -e {BOT_CONFIG_FILE}')


def cmd_test(args):
    """Run adversarial tests against the API."""
    ensure_logged_in()
    ensure_bot_json()

    # Determine test category
    if getattr(args, "single", False):
        category = TEST_CATEGORIES["single"]
    elif getattr(args, "agentic", False):
        category = TEST_CATEGORIES["agentic"]
    elif getattr(args, "behavioral", False):
        category = TEST_CATEGORIES["behavioral"]
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
        f"aiandme test"
        f" -e {BOT_CONFIG_FILE}"
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
    cmd = "aiandme status"
    if getattr(args, "watch", False):
        cmd += " --watch"
    run(cmd)


def cmd_logs(args):
    """View test findings."""
    ensure_logged_in()
    cmd = "aiandme logs"
    if getattr(args, "failed", False):
        cmd += " --verdict fail"
    run(cmd)


def cmd_posture(_args):
    """View security posture score."""
    ensure_logged_in()
    run("aiandme posture")


def cmd_guardrails(args):
    """Export guardrail rules."""
    ensure_logged_in()
    vendor = getattr(args, "vendor", "aiandme")
    fmt = getattr(args, "format", "json")
    cmd = f"aiandme guardrails --vendor {vendor} --format {fmt}"
    if getattr(args, "output", None):
        cmd += f" -o {args.output}"
    run(cmd)


def cmd_full(_args):
    """Run the full red teaming workflow end-to-end."""
    print("=" * 60)
    print("  Foodie AI — Full Red Teaming Workflow")
    print("=" * 60)

    # Step 1: Setup
    print("\n--- Step 1/6: Generating bot.json ---")
    cmd_setup(None)

    # Step 2: Login check
    print("\n--- Step 2/6: Checking authentication ---")
    ensure_logged_in()

    # Step 3: Init project
    print("\n--- Step 3/6: Scanning bot and creating project ---")
    run(f'aiandme init -n "Foodie AI" -e {BOT_CONFIG_FILE}')

    # Step 4: Run single-turn attacks
    print("\n--- Step 4/6: Running single-turn OWASP attacks ---")
    run(
        f"aiandme test -e {BOT_CONFIG_FILE}"
        f" -t {TEST_CATEGORIES['single']}"
        f" -l unit --wait",
        check=False,
    )

    # Step 5: Run multi-turn attacks
    print("\n--- Step 5/6: Running multi-turn OWASP attacks ---")
    run(
        f"aiandme test -e {BOT_CONFIG_FILE}"
        f" -t {TEST_CATEGORIES['multi']}"
        f" -l unit --wait",
        check=False,
    )

    # Step 6: Results
    print("\n--- Step 6/6: Results ---")
    print("\n>> Security Posture:")
    run("aiandme posture", check=False)

    print("\n>> Failed Findings:")
    run("aiandme logs --verdict fail", check=False)

    print("\n" + "=" * 60)
    print("  Red teaming complete!")
    print("  Run 'python redteam.py guardrails' to export hardening rules.")
    print("=" * 60)


# ── CLI Parser ──────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Foodie AI — Red Teaming CLI (powered by AIandMe / HumanBound)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  python redteam.py setup              Generate bot.json from .env\n"
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
    subparsers.add_parser("setup", help="Generate bot.json from .env credentials")

    # init
    subparsers.add_parser("init", help="Scan bot and create an aiandme project")

    # test
    test_parser = subparsers.add_parser("test", help="Run adversarial tests")
    test_type = test_parser.add_mutually_exclusive_group()
    test_type.add_argument("--single", action="store_true", help="Single-turn OWASP attacks")
    test_type.add_argument("--agentic", action="store_true", help="Agentic multi-turn attacks")
    test_type.add_argument("--behavioral", action="store_true", help="Behavioral QA tests")
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
        "--vendor", choices=("aiandme", "openai", "azure", "bedrock"),
        default="aiandme", help="Target vendor format",
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
