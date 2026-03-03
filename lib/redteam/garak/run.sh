#!/usr/bin/env bash
set -euo pipefail
#
# Run Garak probes against the target API.
#
# Reads target.yaml to generate a Garak REST config (target_garak.json),
# authenticates, and launches the scan.
#
# Expects ENGAGEMENT_DIR and DEEPCYBER_LIB to be set (by the dcr CLI).
# Falls back to REPO_ROOT for backward compatibility.
#
# Usage:
#   bash run.sh                          # default probes
#   bash run.sh -p dan                   # DAN jailbreak probes
#   bash run.sh -p encoding -d always.Pass

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Resolve directories (dcr sets these; fall back to legacy layout)
ENGAGEMENT_DIR="${ENGAGEMENT_DIR:-$(dirname "$SCRIPT_DIR")}"
DEEPCYBER_LIB="${DEEPCYBER_LIB:-$(dirname "$SCRIPT_DIR")}"
export ENGAGEMENT_DIR DEEPCYBER_LIB

# Load .env from engagement dir
if [ -f "$ENGAGEMENT_DIR/.env" ]; then
  set -a; source "$ENGAGEMENT_DIR/.env"; set +a
fi

# Output directory inside engagement
GARAK_DIR="$ENGAGEMENT_DIR/garak"
mkdir -p "$GARAK_DIR"

# Generate target_garak.json from target.yaml and get a token
echo "==> Generating Garak config from target.yaml..."
REST_API_KEY=$(python3 -c '
import sys, os, json
sys.path.insert(0, os.environ["DEEPCYBER_LIB"])
os.environ.setdefault("ENGAGEMENT_DIR", os.environ.get("ENGAGEMENT_DIR", ""))
from shared.config import load_target_config, get_api_url, get_response_field, load_policy, build_policy_text
from shared.auth import get_token

config = load_target_config()
api_url = get_api_url(config)
token = get_token(config)

# Build request template: replace {{PROMPT}} with $INPUT (Garak placeholder)
body_template = config["request"]["body"]
def substitute(obj, old, new):
    if isinstance(obj, str):
        return obj.replace(old, new)
    if isinstance(obj, dict):
        return {k: substitute(v, old, new) for k, v in obj.items()}
    if isinstance(obj, list):
        return [substitute(i, old, new) for i in obj]
    return obj
req_body = substitute(body_template, "{{PROMPT}}", "$INPUT")

# Build headers
headers = {"Content-Type": config["request"].get("content_type", "application/json")}
for k, v in config.get("headers", {}).items():
    headers[k] = v
if token:
    headers["Authorization"] = "Bearer $KEY"

# Session header
session_cfg = config.get("session", {})
session_header = session_cfg.get("header", "")
if session_header:
    headers[session_header] = "garak-run"

garak_config = {
    "rest": {
        "RestGenerator": {
            "name": config["target"]["name"],
            "uri": api_url,
            "method": config["api"].get("method", "POST").lower(),
            "headers": headers,
            "req_template_json_object": req_body,
            "response_json": True,
            "response_json_field": get_response_field(config),
        }
    }
}

out_path = os.path.join(os.environ["ENGAGEMENT_DIR"], "garak", "target_garak.json")
os.makedirs(os.path.dirname(out_path), exist_ok=True)
with open(out_path, "w") as f:
    json.dump(garak_config, f, indent=2)

# Write policy text for detector goal if policy exists
policy = load_policy(config)
if policy:
    policy_text = build_policy_text(policy)
    policy_path = os.path.join(os.environ["ENGAGEMENT_DIR"], "garak", "policy_goal.txt")
    with open(policy_path, "w") as f:
        f.write(policy_text)
    import sys as _sys
    print("POLICY_LOADED=true", file=_sys.stderr)

print(token)
')
export REST_API_KEY

echo "==> Token acquired"

# Check if policy was loaded
if [ -f "$GARAK_DIR/policy_goal.txt" ]; then
  echo "==> Policy loaded — saved to garak/policy_goal.txt"
fi

echo "==> Running Garak scan..."

python3 -m garak \
  -m rest \
  -G "$GARAK_DIR/target_garak.json" \
  "$@"

echo ""
echo "==> Done! Check the garak output directory for results."
