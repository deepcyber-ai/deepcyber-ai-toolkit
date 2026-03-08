#!/bin/bash
set -e

# =============================================================================
# DeepCyber Relay Proxy — Cloudflare Named Tunnel Setup (Laptop)
# =============================================================================
# Sets up a persistent Cloudflare Tunnel on your MacBook so that cloud tools
# (HumanBound, Promptfoo, etc.) can reach the relay proxy at a stable URL:
#
#   https://relay.deepcyber-relay.uk
#
# Prerequisites:
#   - Cloudflare account with deepcyber-relay.uk added
#   - brew install cloudflared  (macOS)
# =============================================================================

TUNNEL_NAME="deepcyber-relay"
DOMAIN="deepcyber-relay.uk"
SUBDOMAIN="relay.${DOMAIN}"
RELAY_PORT="${RELAY_PORT:-8443}"

echo "=== DeepCyber Relay Tunnel Setup (Laptop) ==="
echo ""
echo "  Tunnel:    ${TUNNEL_NAME}"
echo "  Subdomain: ${SUBDOMAIN}"
echo "  Relay port: ${RELAY_PORT}"
echo ""

# ---- Step 1: Install cloudflared (macOS) ------------------------------------
if ! command -v cloudflared &>/dev/null; then
  echo "=== Installing cloudflared ==="
  brew install cloudflared
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
CONFIG_FILE="$HOME/.cloudflared/config-relay.yml"

echo ""
echo "=== Writing config to ${CONFIG_FILE} ==="

cat > "${CONFIG_FILE}" <<EOF
tunnel: ${TUNNEL_ID}
credentials-file: ${HOME}/.cloudflared/${TUNNEL_ID}.json

ingress:
  # Relay proxy for cloud red-team tools (HumanBound, Promptfoo, etc.)
  - hostname: ${SUBDOMAIN}
    service: http://localhost:${RELAY_PORT}
  - service: http_status:404
EOF

echo "  Done."

# ---- Step 5: Add DNS record -------------------------------------------------
echo ""
echo "=== Adding DNS record: ${SUBDOMAIN} ==="
cloudflared tunnel route dns "${TUNNEL_NAME}" "${SUBDOMAIN}" 2>/dev/null || \
  echo "  DNS record may already exist — skipping."

# ---- Step 6: Print usage instructions ---------------------------------------
echo ""
echo "==========================================="
echo "  Setup complete!"
echo "==========================================="
echo ""
echo "To start the tunnel (run alongside the relay proxy):"
echo ""
echo "  cloudflared tunnel --config ${CONFIG_FILE} run ${TUNNEL_NAME}"
echo ""
echo "To start the relay proxy:"
echo ""
echo "  ./deepcyber.sh --relay relay.env"
echo ""
echo "Your cloud tools should target:"
echo ""
echo "  https://${SUBDOMAIN}/v1/chat/completions"
echo ""
echo "To run the tunnel as a background service (macOS):"
echo ""
echo "  sudo cloudflared service install"
echo "  sudo launchctl start com.cloudflare.cloudflared"
echo ""
echo "==========================================="
