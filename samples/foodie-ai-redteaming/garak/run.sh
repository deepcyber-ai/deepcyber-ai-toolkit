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
REST_API_KEY=$(python3 -c "
import sys; sys.path.insert(0, '$REPO_ROOT')
from shared.auth import get_token
auth = get_token('$FOODIE_API_URL', '$FOODIE_USERNAME', '$FOODIE_PASSWORD')
print(auth['id_token'])
")
export REST_API_KEY

echo "==> Token acquired (expires in 1 hour)"
echo "==> Running Garak scan..."

# Default: run the encoding probe. Pass extra args to override.
# Examples:
#   bash run.sh                                  # default probes
#   bash run.sh -p dan                           # DAN jailbreak probes
#   bash run.sh -p encoding -d always.Pass       # encoding probes, pass detector
python3 -m garak \
  -m rest \
  -G "$SCRIPT_DIR/foodie_garak.json" \
  "$@"

echo ""
echo "==> Done! Check the garak output directory for results."
