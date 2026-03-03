#!/usr/bin/env bash
set -euo pipefail
#
# Run all red teaming tools in sequence.
# This script can run inside the DeepCyber container (via run.sh) or standalone.
#
# Expects ENGAGEMENT_DIR and DEEPCYBER_LIB to be set (by the dcr CLI).
# Falls back to legacy layout for backward compatibility.
#
# Usage:
#   bash scan.sh              # run all tools
#   bash scan.sh promptfoo    # run only promptfoo
#   bash scan.sh garak        # run only garak
#   bash scan.sh pyrit        # run only pyrit
#   bash scan.sh giskard      # run only giskard
#   bash scan.sh humanbound   # run only humanbound

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOL="${1:-all}"

# Resolve directories (dcr sets these; fall back to legacy layout)
ENGAGEMENT_DIR="${ENGAGEMENT_DIR:-$(dirname "$SCRIPT_DIR")}"
DEEPCYBER_LIB="${DEEPCYBER_LIB:-$(dirname "$SCRIPT_DIR")}"
export ENGAGEMENT_DIR DEEPCYBER_LIB

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="$ENGAGEMENT_DIR/results/$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

# Load .env from engagement dir
if [ -f "$ENGAGEMENT_DIR/.env" ]; then
  set -a; source "$ENGAGEMENT_DIR/.env"; set +a
fi

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
echo "==> Results directory: $RESULTS_DIR"
echo ""

run_promptfoo() {
  echo "===== Promptfoo ====="
  bash "$DEEPCYBER_LIB/promptfoo/setup.sh" run 2>&1 \
    | tee "$RESULTS_DIR/promptfoo.log"
  echo ""
}

run_garak() {
  echo "===== Garak ====="
  bash "$DEEPCYBER_LIB/garak/run.sh" 2>&1 \
    | tee "$RESULTS_DIR/garak.log"
  echo ""
}

run_pyrit() {
  echo "===== PyRIT (single-turn) ====="
  cd "$ENGAGEMENT_DIR/pyrit"
  python3 single_turn.py 2>&1 | tee "$RESULTS_DIR/pyrit_single.log"
  echo ""
}

run_giskard() {
  echo "===== Giskard ====="
  python3 "$DEEPCYBER_LIB/giskard/scan.py" \
    --output "$RESULTS_DIR/giskard_report.html" 2>&1 \
    | tee "$RESULTS_DIR/giskard.log"
  echo ""
}

run_humanbound() {
  echo "===== HumanBound ====="
  python3 "$DEEPCYBER_LIB/humanbound/redteam.py" full 2>&1 \
    | tee "$RESULTS_DIR/humanbound.log"
  echo ""
}

case "$TOOL" in
  all)
    run_promptfoo
    run_garak
    run_pyrit
    run_giskard
    run_humanbound
    ;;
  promptfoo)   run_promptfoo ;;
  garak)       run_garak ;;
  pyrit)       run_pyrit ;;
  giskard)     run_giskard ;;
  humanbound)  run_humanbound ;;
  *)
    echo "Unknown tool: $TOOL"
    echo "Usage: bash scan.sh [all|promptfoo|garak|pyrit|giskard|humanbound]"
    exit 1
    ;;
esac

echo "==> Done! Results saved to $RESULTS_DIR"
