#!/usr/bin/env bash
set -euo pipefail
#
# Authenticate and run Promptfoo red team against the target API.
#
# Reads target.yaml to export TARGET_* environment variables that the
# promptfooconfig.yaml references via {{env.TARGET_*}} placeholders.
#
# Expects ENGAGEMENT_DIR and DEEPCYBER_LIB to be set (by the dcr CLI).
# Falls back to REPO_ROOT for backward compatibility.
#
# Usage:
#   bash setup.sh                        # generate config + run
#   bash setup.sh generate               # generate promptfooconfig.yaml only
#   bash setup.sh run                    # run only (assumes config exists)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACTION="${1:-all}"

# Resolve directories (dcr sets these; fall back to legacy layout)
ENGAGEMENT_DIR="${ENGAGEMENT_DIR:-$(dirname "$SCRIPT_DIR")}"
DEEPCYBER_LIB="${DEEPCYBER_LIB:-$(dirname "$SCRIPT_DIR")}"
export ENGAGEMENT_DIR DEEPCYBER_LIB

# Load .env from engagement dir
if [ -f "$ENGAGEMENT_DIR/.env" ]; then
  set -a; source "$ENGAGEMENT_DIR/.env"; set +a
fi

# Output directory inside engagement
PF_DIR="$ENGAGEMENT_DIR/promptfoo"
mkdir -p "$PF_DIR"

# Export TARGET_* vars from target.yaml for promptfoo
echo "==> Reading target.yaml..."
eval "$(python3 -c '
import sys, os, json
sys.path.insert(0, os.environ["DEEPCYBER_LIB"])
os.environ.setdefault("ENGAGEMENT_DIR", os.environ.get("ENGAGEMENT_DIR", ""))
from shared.config import load_target_config, get_api_url, get_response_field
from shared.auth import get_token

config = load_target_config()
api_url = get_api_url(config)
token = get_token(config)
resp_field = get_response_field(config)
name = config["target"]["name"]
description = config["target"].get("description", "")
body_template = json.dumps(config["request"]["body"])

# Session header
session_cfg = config.get("session", {})
session_header = session_cfg.get("header", "")

print(f"export TARGET_URL=\"{api_url}\"")
print(f"export TARGET_TOKEN=\"{token}\"")
print(f"export TARGET_RESPONSE_FIELD=\"{resp_field}\"")
print(f"export TARGET_NAME=\"{name}\"")
print(f"export TARGET_DESCRIPTION={json.dumps(description)}")
print(f"export TARGET_BODY_TEMPLATE={json.dumps(body_template)}")
print(f"export TARGET_SESSION_HEADER=\"{session_header}\"")
')"

echo "==> Target: $TARGET_NAME"
echo "==> URL:    $TARGET_URL"

generate_config() {
  echo "==> Generating promptfooconfig.yaml..."
  python3 -c '
import sys, os, json, yaml
sys.path.insert(0, os.environ["DEEPCYBER_LIB"])
os.environ.setdefault("ENGAGEMENT_DIR", os.environ.get("ENGAGEMENT_DIR", ""))
from shared.config import load_target_config, get_api_url, get_response_field, load_policy, build_policy_text

config = load_target_config()
api_url = get_api_url(config)
resp_field = get_response_field(config)
name = config["target"]["name"]
description = config["target"].get("description", "")

# Load policy and enrich purpose
policy = load_policy(config)
policy_text = build_policy_text(policy) if policy else ""
if policy:
    # Combine target description with policy for a richer purpose
    purpose_parts = [description.strip()] if description.strip() else []
    if policy.get("allowed_topics"):
        purpose_parts.append("Allowed: " + "; ".join(policy["allowed_topics"]))
    if policy.get("expected_boundaries"):
        purpose_parts.append("Boundaries: " + "; ".join(policy["expected_boundaries"]))
    description = " | ".join(purpose_parts) if purpose_parts else description

# Build headers
headers = {
    "Content-Type": config["request"].get("content_type", "application/json"),
    "Authorization": "Bearer {{env.TARGET_TOKEN}}",
}
for k, v in config.get("headers", {}).items():
    headers[k] = v
session_header = config.get("session", {}).get("header", "")
if session_header:
    headers[session_header] = "promptfoo-run"

# Build body with {{prompt}} as the placeholder (promptfoo native)
def substitute(obj, old, new):
    if isinstance(obj, str):
        return obj.replace(old, new)
    if isinstance(obj, dict):
        return {k: substitute(v, old, new) for k, v in obj.items()}
    if isinstance(obj, list):
        return [substitute(i, old, new) for i in obj]
    return obj
body = substitute(config["request"]["body"], "{{PROMPT}}", "{{prompt}}")

pf_config = {
    "description": f"{name} Red Team",
    "targets": [{
        "id": "https",
        "config": {
            "url": "{{env.TARGET_URL}}",
            "method": config["api"].get("method", "POST"),
            "headers": headers,
            "body": body,
            "transformResponse": f"json.{resp_field}",
        },
    }],
    "redteam": {
        "purpose": description.strip() if isinstance(description, str) else str(description).strip(),
        "injectVar": "prompt",
        "plugins": [
            {"id": "contracts"},
            {"id": "excessive-agency"},
            {"id": "hallucination"},
            {"id": "harmful:cybercrime"},
            {"id": "harmful:hate"},
            {"id": "harmful:illegal-activities"},
            {"id": "harmful:self-harm"},
            {"id": "harmful:sexual-content"},
            {"id": "harmful:violent-crime"},
            {"id": "hijacking"},
            {"id": "off-topic"},
            {"id": "overreliance"},
            {"id": "pii:direct"},
            {"id": "pii:social"},
            {"id": "politics"},
            {"id": "prompt-extraction"},
            {"id": "system-prompt-override"},
        ],
        "strategies": [
            {"id": "base64"},
            {"id": "crescendo"},
            {"id": "jailbreak-templates"},
            {"id": "jailbreak:likert"},
            {"id": "leetspeak"},
            {"id": "rot13"},
        ],
    },
}

# Add policy-based plugins if policy exists
if policy:
    for topic in policy.get("forbidden_topics", []):
        pf_config["redteam"]["plugins"].append({"id": "policy", "config": {"policy": f"The AI must not discuss: {topic}"}})
    for rule in policy.get("must_refuse", []):
        pf_config["redteam"]["plugins"].append({"id": "policy", "config": {"policy": f"The AI must refuse: {rule}"}})

out_path = os.path.join(os.environ["ENGAGEMENT_DIR"], "promptfoo", "promptfooconfig.yaml")
os.makedirs(os.path.dirname(out_path), exist_ok=True)
with open(out_path, "w") as f:
    yaml.dump(pf_config, f, default_flow_style=False, sort_keys=False)
print(f"    Written to {out_path}")
'
}

run_scan() {
  echo "==> Running Promptfoo red team..."
  cd "$PF_DIR"
  npx promptfoo@latest redteam run
}

case "$ACTION" in
  generate) generate_config ;;
  run)      run_scan ;;
  all|*)    generate_config && run_scan ;;
esac

echo ""
echo "==> Done! Run 'npx promptfoo@latest redteam report' to view the report."
