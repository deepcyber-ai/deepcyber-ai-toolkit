#!/bin/bash
set -euo pipefail

# DeepCyber VM Build Orchestrator
# Usage: ./build.sh [--headless|--gui]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKER_DIR="$VM_DIR/packer"

HEADLESS="true"
if [[ "${1:-}" == "--gui" ]]; then
    HEADLESS="false"
fi

echo "========================================"
echo "  DeepCyber VM Build"
echo "========================================"
echo ""
echo "  Packer dir: $PACKER_DIR"
echo "  Headless:   $HEADLESS"
echo ""

# Initialise Packer plugins
echo "[1/3] Initialising Packer plugins..."
cd "$PACKER_DIR"
packer init deepcyber-vm.pkr.hcl

# Validate template
echo "[2/3] Validating Packer template..."
packer validate -var-file=variables.pkrvars.hcl deepcyber-vm.pkr.hcl

# Build
echo "[3/3] Building VM image (this will take 45-90 minutes)..."
packer build \
    -var-file=variables.pkrvars.hcl \
    -var "headless=$HEADLESS" \
    deepcyber-vm.pkr.hcl

echo ""
echo "Build complete. Output: $PACKER_DIR/output-deepcyber-vm/"
echo ""
echo "Next steps:"
echo "  make export-utm   # Package for UTM (macOS)"
echo "  make export-ova   # Package for VMware/VirtualBox"
echo "  make test         # Run validation tests"
