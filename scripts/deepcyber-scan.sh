#!/bin/bash
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="/home/deepcyber/results/${TIMESTAMP}"
mkdir -p "${RESULTS_DIR}"

echo "=== DeepCyber AI Red Team Scan ==="
echo "Results directory: ${RESULTS_DIR}"

echo "Running promptfoo evaluation..."
promptfoo eval \
    --config /home/deepcyber/configs/promptfoo/promptfooconfig.yaml \
    --output "${RESULTS_DIR}/promptfoo_results.json" \
    --output-format json

echo "Running garak scan..."
garak \
    --config /home/deepcyber/configs/garak/deepcyber.yaml \
    --report_prefix "${RESULTS_DIR}/garak_report"

echo "=== Scan complete ==="
echo "Results saved to: ${RESULTS_DIR}"
