#!/usr/bin/env bash
set -euo pipefail
#
# Run all red teaming tools in sequence.
# This script can run inside the DeepCyber container (via run.sh) or standalone.
#
# Usage:
#   bash deepcyber/scan.sh              # run all tools
#   bash deepcyber/scan.sh promptfoo    # run only promptfoo
#   bash deepcyber/scan.sh garak        # run only garak
#   bash deepcyber/scan.sh pyrit        # run only pyrit
#   bash deepcyber/scan.sh giskard      # run only giskard
#   bash deepcyber/scan.sh humanbound   # run only humanbound

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TOOL="${1:-all}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="$REPO_ROOT/results/$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

# Load .env
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
echo "==> Results directory: $RESULTS_DIR"
echo ""

run_promptfoo() {
  echo "===== Promptfoo ====="
  cd "$REPO_ROOT/promptfoo"
  bash "$REPO_ROOT/promptfoo/setup.sh" run 2>&1 \
    | tee "$RESULTS_DIR/promptfoo.log"
  echo ""
}

run_garak() {
  echo "===== Garak ====="
  cd "$REPO_ROOT"
  bash "$REPO_ROOT/garak/run.sh" 2>&1 \
    | tee "$RESULTS_DIR/garak.log"
  echo ""
}

run_pyrit() {
  echo "===== PyRIT (single-turn) ====="
  cd "$REPO_ROOT/pyrit"
  python3 single_turn.py 2>&1 | tee "$RESULTS_DIR/pyrit_single.log"
  echo ""
}

run_giskard() {
  echo "===== Giskard ====="
  cd "$REPO_ROOT/giskard"
  python3 scan.py --output "$RESULTS_DIR/giskard_report.html" 2>&1 \
    | tee "$RESULTS_DIR/giskard.log"
  echo ""
}

run_humanbound() {
  echo "===== HumanBound ====="
  cd "$REPO_ROOT/humanbound"
  python3 redteam.py full 2>&1 | tee "$RESULTS_DIR/humanbound.log"
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
