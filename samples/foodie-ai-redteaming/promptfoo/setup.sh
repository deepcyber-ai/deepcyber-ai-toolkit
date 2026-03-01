#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Load credentials
if [ ! -f "$REPO_ROOT/.env" ]; then
  echo "Error: .env not found. Copy .env.example to .env and fill in credentials."
  exit 1
fi
set -a; source "$REPO_ROOT/.env"; set +a

# Get a fresh token
echo "==> Authenticating..."
FOODIE_TOKEN=$(python3 -c "
import sys; sys.path.insert(0, '$REPO_ROOT')
from shared.auth import get_token
auth = get_token('$FOODIE_API_URL', '$FOODIE_USERNAME', '$FOODIE_PASSWORD')
print(auth['id_token'])
")
export FOODIE_TOKEN
export FOODIE_API_URL

echo "==> Token acquired (expires in 1 hour)"
echo "==> Running Promptfoo red team..."
cd "$SCRIPT_DIR"
npx promptfoo@latest redteam run

echo ""
echo "==> Done! View results with:"
echo "    cd promptfoo && npx promptfoo@latest view"
