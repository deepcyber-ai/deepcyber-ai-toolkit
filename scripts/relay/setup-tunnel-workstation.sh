#!/bin/bash
set -e

# =============================================================================
# DeepCyber Workstation — Cloudflare Named Tunnel Setup (Self-Hosted LLM)
# =============================================================================
# Sets up a persistent Cloudflare Tunnel on the DeepCyber workstation (RTX 4090)
# exposing the self-hosted vLLM API and SSH access at stable URLs:
#
#   https://api.deepcyber-relay.uk   → vLLM API (port 8080)
#   ssh.deepcyber-relay.uk           → SSH access (port 22)
#
# Prerequisites:
#   - Cloudflare account with deepcyber-relay.uk added
#   - Docker with GPU support installed
#   - vllm-secure container running on port 8080
# =============================================================================

TUNNEL_NAME="deepcyber-workstation"
DOMAIN="deepcyber-relay.uk"
API_SUBDOMAIN="api.${DOMAIN}"
SSH_SUBDOMAIN="ssh.${DOMAIN}"
API_PORT="${API_PORT:-8080}"

echo "=== DeepCyber Workstation Tunnel Setup ==="
echo ""
echo "  Tunnel:    ${TUNNEL_NAME}"
echo "  API:       ${API_SUBDOMAIN} → localhost:${API_PORT}"
echo "  SSH:       ${SSH_SUBDOMAIN} → localhost:22"
echo ""

# ---- Step 1: Install cloudflared (Linux) ------------------------------------
if ! command -v cloudflared &>/dev/null; then
  echo "=== Installing cloudflared ==="
  curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
  sudo dpkg -i /tmp/cloudflared.deb
  rm /tmp/cloudflared.deb
else
  echo "=== cloudflared already installed ==="
fi

# ---- Step 2: Authenticate --------------------------------------------------
if [ ! -f "$HOME/.cloudflared/cert.pem" ]; then
  echo ""
  echo "=== Authenticating with Cloudflare ==="
  echo "A browser window will open — select ${DOMAIN}"
  cloudflared tunnel login
else
  echo "=== Already authenticated with Cloudflare ==="
fi

# ---- Step 3: Create tunnel (skip if exists) ---------------------------------
if cloudflared tunnel list | grep -q "${TUNNEL_NAME}"; then
  echo "=== Tunnel '${TUNNEL_NAME}' already exists ==="
else
  echo ""
  echo "=== Creating tunnel '${TUNNEL_NAME}' ==="
  cloudflared tunnel create "${TUNNEL_NAME}"
fi

TUNNEL_ID=$(cloudflared tunnel list | grep "${TUNNEL_NAME}" | awk '{print $1}')
echo "  Tunnel ID: ${TUNNEL_ID}"

# ---- Step 4: Write config ---------------------------------------------------
CONFIG_FILE="$HOME/.cloudflared/config-workstation.yml"

echo ""
echo "=== Writing config to ${CONFIG_FILE} ==="

cat > "${CONFIG_FILE}" <<EOF
tunnel: ${TUNNEL_ID}
credentials-file: ${HOME}/.cloudflared/${TUNNEL_ID}.json

ingress:
  # vLLM self-hosted attacker model API
  - hostname: ${API_SUBDOMAIN}
    service: http://localhost:${API_PORT}
  # SSH access to workstation
  - hostname: ${SSH_SUBDOMAIN}
    service: ssh://localhost:22
  - service: http_status:404
EOF

echo "  Done."

# ---- Step 5: Add DNS records ------------------------------------------------
echo ""
echo "=== Adding DNS records ==="
cloudflared tunnel route dns "${TUNNEL_NAME}" "${API_SUBDOMAIN}" 2>/dev/null || \
  echo "  DNS record for ${API_SUBDOMAIN} may already exist — skipping."
cloudflared tunnel route dns "${TUNNEL_NAME}" "${SSH_SUBDOMAIN}" 2>/dev/null || \
  echo "  DNS record for ${SSH_SUBDOMAIN} may already exist — skipping."

# ---- Step 6: Install as system service (persistent across reboots) ----------
echo ""
echo "=== Installing as system service ==="

# cloudflared service install reads from /etc/cloudflared/config.yml
sudo mkdir -p /etc/cloudflared
sudo cp "${CONFIG_FILE}" /etc/cloudflared/config.yml
sudo cp "${HOME}/.cloudflared/${TUNNEL_ID}.json" /etc/cloudflared/${TUNNEL_ID}.json

sudo cloudflared service install 2>/dev/null || \
  echo "  Service may already be installed — restarting."
sudo systemctl enable cloudflared
sudo systemctl restart cloudflared

# ---- Step 7: Print usage instructions ---------------------------------------
echo ""
echo "==========================================="
echo "  Setup complete!"
echo "==========================================="
echo ""
echo "Tunnel is running as a system service (survives reboots)."
echo ""
echo "  API endpoint:  https://${API_SUBDOMAIN}/v1/chat/completions"
echo "  List models:   curl https://${API_SUBDOMAIN}/v1/models -H 'Authorization: Bearer deepcyber'"
echo ""
echo "  SSH (from MacBook, add to ~/.ssh/config):"
echo ""
echo "    Host deepcyber-tunnel"
echo "      HostName ${SSH_SUBDOMAIN}"
echo "      ProxyCommand /usr/local/bin/cloudflared access ssh --hostname %h"
echo "      User yanni"
echo ""
echo "  Then: ssh deepcyber-tunnel"
echo ""
echo "Red-team tool config:"
echo ""
echo "  OPENAI_API_BASE=https://${API_SUBDOMAIN}/v1"
echo "  OPENAI_API_KEY=deepcyber"
echo ""
echo "Manage the service:"
echo ""
echo "  sudo systemctl status cloudflared"
echo "  sudo systemctl restart cloudflared"
echo "  journalctl -u cloudflared -f"
echo ""
echo "==========================================="
