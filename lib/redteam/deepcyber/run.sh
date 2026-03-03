#!/usr/bin/env bash
set -euo pipefail
#
# Launch the DeepCyber AI Toolkit container with this engagement as workspace.
#
# The container has all tools pre-installed (promptfoo, garak, pyrit, giskard, humanbound).
# Authenticates using target.yaml and passes the token to the container.
#
# Expects ENGAGEMENT_DIR and DEEPCYBER_LIB to be set (by the dcr CLI).
# Falls back to legacy layout for backward compatibility.
#
# Usage:
#   bash run.sh              # launch interactive container
#   bash run.sh scan.sh      # run scan.sh inside the container

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Resolve directories (dcr sets these; fall back to legacy layout)
ENGAGEMENT_DIR="${ENGAGEMENT_DIR:-$(dirname "$SCRIPT_DIR")}"
DEEPCYBER_LIB="${DEEPCYBER_LIB:-$(dirname "$SCRIPT_DIR")}"
export ENGAGEMENT_DIR DEEPCYBER_LIB

# Load .env from engagement dir
if [ ! -f "$ENGAGEMENT_DIR/.env" ]; then
  echo "Error: .env not found at $ENGAGEMENT_DIR/.env"
  echo "Copy .env.example to .env and fill in credentials."
  exit 1
fi
set -a; source "$ENGAGEMENT_DIR/.env"; set +a

# Get a fresh token
echo "==> Authenticating..."
TARGET_TOKEN=$(python3 -c '
import sys, os
sys.path.insert(0, os.environ["DEEPCYBER_LIB"])
os.environ.setdefault("ENGAGEMENT_DIR", os.environ.get("ENGAGEMENT_DIR", ""))
from shared.config import load_target_config
from shared.auth import get_token
config = load_target_config()
print(get_token(config))
')
export TARGET_TOKEN
export REST_API_KEY="$TARGET_TOKEN"

echo "==> Token acquired"

# Locate toolkit — derive from DEEPCYBER_LIB (lib/redteam -> toolkit root)
TOOLKIT_DIR="$(cd "$DEEPCYBER_LIB/../.." && pwd)"
if [ ! -f "$TOOLKIT_DIR/deepcyber.sh" ]; then
  # Fall back: check sibling directory, then PATH
  if [ -d "$ENGAGEMENT_DIR/../deepcyber-ai-toolkit" ]; then
    TOOLKIT_DIR="$(cd "$ENGAGEMENT_DIR/../deepcyber-ai-toolkit" && pwd)"
  elif command -v deepcyber.sh &>/dev/null; then
    TOOLKIT_DIR="$(dirname "$(command -v deepcyber.sh)")"
  fi
fi

if [ -z "$TOOLKIT_DIR" ] || [ ! -f "$TOOLKIT_DIR/deepcyber.sh" ]; then
  echo "Error: DeepCyber AI Toolkit not found."
  echo ""
  echo "Clone it with:"
  echo "  git clone https://github.com/deepcyber-ai/deepcyber-ai-toolkit.git"
  exit 1
fi

echo "==> Toolkit found at: $TOOLKIT_DIR"
echo "==> Launching DeepCyber container..."
echo ""

exec bash "$TOOLKIT_DIR/deepcyber.sh" "$@" "$ENGAGEMENT_DIR"
