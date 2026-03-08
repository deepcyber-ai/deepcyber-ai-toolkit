# DeepCyber Workstation — Cloudflare Tunnel Setup

Self-hosted vLLM API + SSH access via `deepcyber-relay.uk`.

```
MacBook ──> Cloudflare ──> deepcyber-workstation tunnel ──> Workstation (RTX 4090)
                                                            ├── vLLM API (:8080)
                                                            └── SSH (:22)
```

---

## Step 1: Install cloudflared

On the workstation:

```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
sudo dpkg -i /tmp/cloudflared.deb
```

Verify:

```bash
cloudflared --version
```

---

## Step 2: Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

- A browser window opens
- Select **deepcyber-relay.uk** as the zone
- Certificate saved to `~/.cloudflared/cert.pem`

If no browser available, copy the URL it prints and open it on another machine.

---

## Step 3: Create the tunnel

```bash
cloudflared tunnel create deepcyber-workstation
```

Note the **Tunnel ID** printed (e.g. `a1b2c3d4-e5f6-...`).

Verify:

```bash
cloudflared tunnel list
```

---

## Step 4: Write the config

```bash
TUNNEL_ID=$(cloudflared tunnel list | grep deepcyber-workstation | awk '{print $1}')

cat > ~/.cloudflared/config.yml <<EOF
tunnel: $TUNNEL_ID
credentials-file: /home/yanni/.cloudflared/$TUNNEL_ID.json

ingress:
  - hostname: api.deepcyber-relay.uk
    service: http://localhost:8080
  - hostname: ssh.deepcyber-relay.uk
    service: ssh://localhost:22
  - service: http_status:404
EOF
```

Verify:

```bash
cat ~/.cloudflared/config.yml
```

---

## Step 5: Add DNS records

```bash
cloudflared tunnel route dns deepcyber-workstation api.deepcyber-relay.uk
cloudflared tunnel route dns deepcyber-workstation ssh.deepcyber-relay.uk
```

This creates CNAME records in Cloudflare pointing to the tunnel.

---

## Step 6: Test the tunnel (foreground)

```bash
cloudflared tunnel run deepcyber-workstation
```

Leave it running. In another terminal:

```bash
curl https://api.deepcyber-relay.uk/v1/models -H "Authorization: Bearer deepcyber"
```

Expected response:

```json
{"data":[{"id":"attacker"}]}
```

If it works, Ctrl-C the tunnel and proceed to Step 7.

---

## Step 7: Install as system service (persistent)

```bash
TUNNEL_ID=$(cloudflared tunnel list | grep deepcyber-workstation | awk '{print $1}')

sudo mkdir -p /etc/cloudflared
sudo cp ~/.cloudflared/config.yml /etc/cloudflared/config.yml
sudo cp ~/.cloudflared/$TUNNEL_ID.json /etc/cloudflared/$TUNNEL_ID.json

sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

Verify:

```bash
sudo systemctl status cloudflared
```

The tunnel now survives reboots.

---

## Step 8: SSH from MacBook

On your MacBook, install cloudflared:

```bash
brew install cloudflared
```

Add to `~/.ssh/config`:

```
Host deepcyber-tunnel
  HostName ssh.deepcyber-relay.uk
  ProxyCommand /usr/local/bin/cloudflared access ssh --hostname %h
  User yanni
```

Then connect:

```bash
ssh deepcyber-tunnel
```

---

## Step 9: Verify everything

From your MacBook:

```bash
# SSH
ssh deepcyber-tunnel "hostname && nvidia-smi | head -5"

# List models
curl https://api.deepcyber-relay.uk/v1/models \
  -H "Authorization: Bearer deepcyber"

# Chat test
curl https://api.deepcyber-relay.uk/v1/chat/completions \
  -H "Authorization: Bearer deepcyber" \
  -H "Content-Type: application/json" \
  -d '{"model":"attacker","messages":[{"role":"user","content":"Hello"}]}'
```

---

## Red-team tool config

Set in your `.env` or tool config:

```bash
OPENAI_API_BASE=https://api.deepcyber-relay.uk/v1
OPENAI_API_KEY=deepcyber
```

Works with: promptfoo, garak, pyrit, giskard, humanbound.

---

## Management

```bash
# Check tunnel status
sudo systemctl status cloudflared

# View logs
journalctl -u cloudflared -f

# Restart
sudo systemctl restart cloudflared

# Check vLLM container
docker logs --tail 20 vllm-secure

# GPU utilisation
nvidia-smi
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `cloudflared tunnel login` no browser | Copy the URL and open on another machine |
| DNS not resolving | Wait 1-2 minutes for propagation, then `dig api.deepcyber-relay.uk` |
| API returns 502 | vLLM container not running: `docker ps` then `docker start vllm-secure` |
| SSH hangs | Check `cloudflared` is installed on MacBook: `brew install cloudflared` |
| Tunnel not starting after reboot | `sudo systemctl enable cloudflared` |

---

(c) 2026 Deep Cyber Ltd. All rights reserved.
