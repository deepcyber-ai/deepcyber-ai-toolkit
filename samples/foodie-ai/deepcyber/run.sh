#!/usr/bin/env bash
set -euo pipefail
#
# Launch the DeepCyber AI Toolkit container with this engagement as workspace.
#
# The container has all tools pre-installed (promptfoo, garak, pyrit, giskard, humanbound).
# Authenticates using target.yaml and passes the token to the container.
#
# Usage:
#   bash run.sh              # launch interactive container
#   bash run.sh scan.sh      # run scan.sh inside the container

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Load .env
if [ ! -f "$REPO_ROOT/.env" ]; then
  echo "Error: .env not found. Copy .env.example to .env and fill in credentials."
  exit 1
fi
set -a; source "$REPO_ROOT/.env"; set +a
export REPO_ROOT

# Get a fresh token
echo "==> Authenticating..."
TARGET_TOKEN=$(python3 -c '
import sys, os; sys.path.insert(0, os.environ["REPO_ROOT"])
from shared.config import load_target_config
from shared.auth import get_token
config = load_target_config()
print(get_token(config))
')
export TARGET_TOKEN
export REST_API_KEY="$TARGET_TOKEN"

echo "==> Token acquired"

# Locate toolkit — check sibling directory first, then PATH
TOOLKIT_DIR=""
if [ -d "$REPO_ROOT/../deepcyber-ai-toolkit" ]; then
  TOOLKIT_DIR="$(cd "$REPO_ROOT/../deepcyber-ai-toolkit" && pwd)"
elif command -v deepcyber.sh &>/dev/null; then
  TOOLKIT_DIR="$(dirname "$(command -v deepcyber.sh)")"
fi

if [ -z "$TOOLKIT_DIR" ] || [ ! -f "$TOOLKIT_DIR/deepcyber.sh" ]; then
  echo "Error: DeepCyber AI Toolkit not found."
  echo ""
  echo "Expected at: $REPO_ROOT/../deepcyber-ai-toolkit/"
  echo ""
  echo "Clone it with:"
  echo "  git clone https://github.com/deepcyber-ai/deepcyber-ai-toolkit.git $REPO_ROOT/../deepcyber-ai-toolkit"
  exit 1
fi

echo "==> Toolkit found at: $TOOLKIT_DIR"
echo "==> Launching DeepCyber container..."
echo ""

exec bash "$TOOLKIT_DIR/deepcyber.sh" "$@" "$REPO_ROOT"
