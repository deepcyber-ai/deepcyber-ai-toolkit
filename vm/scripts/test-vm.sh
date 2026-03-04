#!/bin/bash
set -euo pipefail

# DeepCyber VM Post-Build Validation
# Usage: test-vm.sh <qcow2-path> [ssh-port]
#
# Boots the QCOW2 image with QEMU, waits for SSH, and runs validation checks.
# Alternatively, pass a running VM's SSH port to skip boot.

QCOW2_PATH="${1:-}"
SSH_PORT="${2:-2222}"
SSH_USER="deepcyber"
SSH_PASS="deepcyber"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
QEMU_PID=""
PASSED=0
FAILED=0
TOTAL=0

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cleanup() {
    if [[ -n "$QEMU_PID" ]]; then
        echo ""
        echo "Shutting down test VM (PID: $QEMU_PID)..."
        kill "$QEMU_PID" 2>/dev/null || true
        wait "$QEMU_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

run_test() {
    local name="$1"
    local cmd="$2"
    TOTAL=$((TOTAL + 1))

    if output=$(sshpass -p "$SSH_PASS" ssh $SSH_OPTS -p "$SSH_PORT" "$SSH_USER@127.0.0.1" "$cmd" 2>&1); then
        echo -e "  ${GREEN}PASS${NC}  $name"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}FAIL${NC}  $name"
        echo "        $output" | head -3
        FAILED=$((FAILED + 1))
    fi
}

# Check prerequisites
if ! command -v sshpass &>/dev/null; then
    echo "Error: sshpass required. Install: brew install sshpass (or apt install sshpass)"
    exit 1
fi

# Boot VM if QCOW2 path provided
if [[ -n "$QCOW2_PATH" ]] && [[ -f "$QCOW2_PATH" ]]; then
    echo "Booting test VM from: $QCOW2_PATH"
    echo "  SSH port: $SSH_PORT"

    qemu-system-aarch64 \
        -machine virt -cpu host -accel hvf \
        -m 4096 -smp 2 \
        -drive file="$QCOW2_PATH",format=qcow2,if=virtio \
        -bios /opt/homebrew/share/qemu/edk2-aarch64-code.fd \
        -net nic,model=virtio -net user,hostfwd=tcp::${SSH_PORT}-:22 \
        -display none -daemonize \
        &
    QEMU_PID=$!

    echo "  Waiting for SSH (up to 120 seconds)..."
    for i in $(seq 1 24); do
        if sshpass -p "$SSH_PASS" ssh $SSH_OPTS -p "$SSH_PORT" "$SSH_USER@127.0.0.1" "echo ok" &>/dev/null; then
            echo "  VM is ready."
            break
        fi
        if [[ $i -eq 24 ]]; then
            echo "Error: VM did not become reachable via SSH within 120 seconds."
            exit 1
        fi
        sleep 5
    done
else
    echo "No QCOW2 provided — connecting to existing VM on port $SSH_PORT"
fi

echo ""
echo "========================================"
echo "  DeepCyber VM Validation Tests"
echo "========================================"
echo ""

# ---- DCR Toolkit ----
echo "DCR Toolkit:"
run_test "dcr --version" "dcr --version"
run_test "dcr --help" "dcr --help | head -1"
run_test "DEEPCYBER_LIB set" "test -n \"\$DEEPCYBER_LIB\""
run_test "dcr on PATH" "which dcr"

# ---- Project Template ----
echo ""
echo "Project Template:"
run_test "template exists" "test -f ~/projects/template/target.yaml"
run_test "examples exist" "ls ~/projects/examples/*.yaml | head -1"
run_test "results dir exists" "test -d ~/results"

# ---- AI Assistant ----
echo ""
echo "AI Assistant:"
run_test "Claude instructions" "test -f ~/.claude/CLAUDE.md"
run_test "Gemini instructions" "test -f ~/.gemini/GEMINI.md"
run_test "Codex instructions" "test -f ~/.codex/AGENTS.md"
run_test "AI instructions source" "test -f ~/docs/AI_INSTRUCTIONS.md"

# ---- npm Tools ----
echo ""
echo "npm Tools:"
run_test "promptfoo" "which promptfoo"
run_test "claude" "which claude"
run_test "gemini" "which gemini"
run_test "codex" "which codex"

# ---- pip Tools ----
echo ""
echo "pip Tools (import check):"
run_test "garak" "python3 -c 'import garak'"
run_test "pyrit" "python3 -c 'import pyrit'"
run_test "giskard" "python3 -c 'import giskard'"
run_test "deepeval" "python3 -c 'import deepeval'"
run_test "llm_guard" "python3 -c 'import llm_guard'"
run_test "jupyterlab" "python3 -c 'import jupyterlab'"
run_test "art (text2art)" "python3 -c 'from art import text2art'"

# ---- Security Tools ----
echo ""
echo "Security Tools:"
run_test "msfconsole" "which msfconsole"
run_test "hydra" "which hydra"
run_test "medusa" "which medusa"
run_test "john" "which john"
run_test "hashcat" "which hashcat"
run_test "zaproxy" "which zaproxy || which zap || dpkg -l zaproxy | grep -q ii"
run_test "burpsuite" "dpkg -l burpsuite | grep -q ii"

# ---- Branding ----
echo ""
echo "Branding:"
run_test "wallpapers dir" "test -d /usr/share/backgrounds/deepcyber"
run_test "default wallpaper" "test -f '/usr/share/backgrounds/deepcyber/Deep Cyner AI Red Teaming 1.jpg'"
run_test "MOTD" "grep -q 'DeepCyber' /etc/motd"
run_test "branded PS1" "grep -q 'deepcyber' ~/.bashrc"
run_test "Plymouth theme" "test -f /usr/share/plymouth/themes/deepcyber/deepcyber.plymouth"

# ---- Documentation Portal ----
echo ""
echo "Documentation Portal:"
run_test "mkdocs installed" "python3 -c 'import mkdocs'"
run_test "nginx running" "systemctl is-active nginx"
run_test "docs site built" "test -f ~/docs/site/index.html"
run_test "docs accessible" "curl -sf http://localhost/docs/ | grep -q 'DeepCyber'"

# ---- Desktop ----
echo ""
echo "Desktop:"
run_test "LightDM" "dpkg -l lightdm | grep -q ii"
run_test ".desktop files" "ls /usr/share/applications/deepcyber-*.desktop | head -1"
# Detect which desktop is installed and test accordingly
run_test "desktop (XFCE or MATE)" "dpkg -l xfce4 | grep -q ii || dpkg -l mate-desktop | grep -q ii"

echo ""
echo "Edition:"
if sshpass -p "$SSH_PASS" ssh $SSH_OPTS -p "$SSH_PORT" "$SSH_USER@127.0.0.1" "dpkg -l mate-desktop 2>/dev/null | grep -q ii" 2>/dev/null; then
    echo -e "  ${YELLOW}MATE${NC} — Founder's Edition"
    run_test "MATE desktop" "dpkg -l mate-desktop | grep -q ii"
    run_test "MATE terminal" "dpkg -l mate-terminal | grep -q ii"
    run_test "MATE wallpaper config" "test -f /etc/dconf/db/local.d/01-deepcyber"
else
    echo -e "  ${YELLOW}XFCE${NC} — Standard Edition"
    run_test "XFCE desktop" "dpkg -l xfce4 | grep -q ii"
    run_test "XFCE terminal" "dpkg -l xfce4-terminal | grep -q ii"
fi

# ---- Summary ----
echo ""
echo "========================================"
echo -e "  Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}, $TOTAL total"
echo "========================================"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
