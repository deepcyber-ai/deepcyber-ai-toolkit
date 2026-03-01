# DeepCyber Relay Proxy

A reverse proxy for red team engagements where the target API is only accessible from inside the client network. The relay runs on the tester's laptop and bridges any cloud-based tool to the internal API via a secure tunnel.

## Problem

Many red teaming tools (HumanBound, Promptfoo cloud, third-party scanners) run in the cloud and need to reach an API that is:

- Behind a corporate firewall with no inbound ports open
- Only accessible from the client's internal network
- Restricted to specific IP ranges or VPN connections

The relay proxy solves this without requiring firewall changes or VPN split-tunnelling.

## Architecture

```
Cloud Tool ──HTTPS──> Cloudflare Tunnel ──> Relay Proxy (laptop) ──> Internal API
                      (outbound only)       (inside client network)
```

### Security Controls

| Control | Detail |
|---------|--------|
| Shared-secret auth | Only requests with the correct `X-Relay-Secret` header are forwarded |
| JWT injection | Relay injects the internal API's Bearer token — the cloud tool never sees it |
| Path allowlisting | Restrict which API endpoints are exposed (e.g. only `/v1/chat/completions`) |
| Path blocklisting | Block sensitive endpoints (e.g. `/admin`, `/v1/fine-tuning`) |
| Rate limiting | Configurable requests-per-second cap (default: 10 rps) |
| Tamper-evident audit | SHA-256 hash-chained JSONL logs for every request/response |
| Localhost binding | Relay only listens on localhost — Cloudflare Tunnel handles exposure |

## Quick Start

### 1. Configure

```bash
cp configs/relay.env.example relay.env
```

Edit `relay.env`:

```bash
# The internal API you are testing
TARGET_API=https://internal-api.client.com/v1

# Shared secret — generate a strong one
RELAY_SECRET=$(openssl rand -hex 32)

# Internal API auth token (injected as Authorization: Bearer)
JWT_TOKEN=eyJhbGciOi...

# Only allow chat completions and model listing
ALLOWED_PATHS=/v1/chat/completions,/v1/models

# Block admin and fine-tuning endpoints
BLOCKED_PATHS=/admin,/v1/fine-tuning
```

### 2. Launch the Relay

```bash
./deepcyber.sh --relay relay.env
```

With a corporate CA certificate:

```bash
./deepcyber.sh --relay relay.env -c corp-ca.crt
```

### 3. Start the Cloudflare Tunnel

In a separate terminal:

```bash
# Quick tunnel (no account needed, temporary URL)
cloudflared tunnel --url http://localhost:8443

# Named tunnel (persistent URL, requires Cloudflare account)
cloudflared tunnel run my-engagement
```

Copy the tunnel URL (e.g. `https://xxxx.trycloudflare.com`) and configure it as the target endpoint in your cloud tool.

### 4. Configure Your Cloud Tool

Point the cloud tool at the tunnel URL and include the shared secret:

```bash
# Example: curl through the relay
curl -H "X-Relay-Secret: $RELAY_SECRET" \
     https://xxxx.trycloudflare.com/v1/chat/completions \
     -d '{"model":"gpt-4","messages":[{"role":"user","content":"hello"}]}'

# Example: HumanBound
# Set the tunnel URL as the target API and add X-Relay-Secret to custom headers

# Example: Promptfoo
# Use the tunnel URL as a custom provider endpoint
```

## Management Endpoints

These endpoints are served by the relay itself (not forwarded to the target):

| Endpoint | Auth | Method | Purpose |
|----------|------|--------|---------|
| `/__relay/health` | No | GET | Tunnel liveness check — returns `{"status": "ok"}` |
| `/__relay/stats` | Yes | GET | Request count, log size, current config |
| `/__relay/update-jwt` | Yes | POST | Hot-swap JWT token without restarting |

### Hot-Swapping JWT Tokens

If the internal API token expires mid-engagement:

```bash
curl -X POST \
  -H "X-Relay-Secret: $RELAY_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"token": "new-jwt-token-here"}' \
  http://localhost:8443/__relay/update-jwt
```

## Audit Logs

Every request and response is logged to a JSONL file with tamper-evident SHA-256 hash chaining. Each entry contains:

- Sequential counter
- UTC timestamp
- Request/response metadata (method, path, status, body size, body preview)
- Previous entry's hash (chain link)
- SHA-256 hash of the current entry

### Log Location

Logs are written to `~/results/relay_audit/` inside the container. Mount a volume to persist them:

```bash
./deepcyber.sh --relay relay.env ~/engagement-output
```

### Verifying Log Integrity

```bash
python scripts/relay/verify_audit.py results/relay_audit/relay_audit_20260301_091500.jsonl
```

Output on success:

```
All 142 entries verified. Hash chain intact.
  First entry: GENESIS
  Final hash:  a3b1c4d5e6f7...
```

Output on tampering:

```
  seq 47: hash mismatch
    stored:   deadbeef12345678...
    expected: 9f8e7d6c5b4a3210...

1 error(s) found in 142 entries. LOG MAY BE TAMPERED.
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TARGET_API` | `http://localhost:8080` | Internal API base URL |
| `RELAY_PORT` | `8443` | Port the relay listens on |
| `RELAY_SECRET` | (insecure default) | Shared secret for authentication |
| `JWT_TOKEN` | (empty) | Bearer token injected into forwarded requests |
| `ALLOWED_PATHS` | (all) | Comma-separated allowed path prefixes |
| `BLOCKED_PATHS` | (none) | Comma-separated blocked path prefixes |
| `RATE_LIMIT` | `10` | Max requests per second |
| `LOG_DIR` | `./audit_logs` | Directory for audit log files |

## Cloudflare Tunnel Setup

### Quick Tunnel (No Account)

```bash
brew install cloudflared   # macOS
cloudflared tunnel --url http://localhost:8443
```

This gives you a temporary `*.trycloudflare.com` URL. Good for testing, but the URL changes each time.

### Named Tunnel (Persistent)

```bash
cloudflared tunnel login
cloudflared tunnel create my-engagement
cloudflared tunnel route dns my-engagement relay.yourdomain.com
cloudflared tunnel run my-engagement
```

This gives you a stable subdomain that persists across restarts.

## Running Outside Docker

The relay can also run directly on the host (no container needed):

```bash
pip install flask requests
export TARGET_API=https://internal-api.client.com/v1
export RELAY_SECRET=$(openssl rand -hex 32)
export JWT_TOKEN=your-token
python scripts/relay/relay_proxy.py
```

## Testing

### Automated Tests

Run the integration test suite (no Docker required):

```bash
bash scripts/relay/test_relay.sh
```

This starts a mock echo server and the relay proxy, runs 17 curl-based tests covering authentication, path filtering, header handling, request forwarding, rate limiting, JWT hot-swap, and audit log integrity, then cleans up. Exit code is 0 on success, 1 on any failure.

Override ports if the defaults (19876/19877) conflict:

```bash
MOCK_PORT=29876 RELAY_PORT=29877 bash scripts/relay/test_relay.sh
```

### Manual / Interactive Testing

Start a mock target and the relay together for hands-on exploration:

```bash
bash scripts/relay/dev_relay.sh
```

This starts both servers in the foreground with sensible defaults (secret: `mysecret`, port: 8443). Then curl from another terminal:

```bash
# Proxied request — inspect what headers and body reach the target
curl -s -H "X-Relay-Secret: mysecret" \
  http://localhost:8443/v1/chat/completions | python3 -m json.tool

# POST with body
curl -s -X POST \
  -H "X-Relay-Secret: mysecret" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4","messages":[{"role":"user","content":"hello"}]}' \
  http://localhost:8443/v1/chat/completions | python3 -m json.tool

# Verify auth is enforced
curl -v http://localhost:8443/v1/models

# Health check
curl -s http://localhost:8443/__relay/health | python3 -m json.tool
```

The mock echo server returns the exact method, path, headers, and body it received, so you can verify JWT injection, header stripping, and body forwarding at a glance.

Override any setting via environment variables:

```bash
RELAY_SECRET=abc JWT_TOKEN=my-token ALLOWED_PATHS=/v1/chat RELAY_PORT=9000 \
  bash scripts/relay/dev_relay.sh
```

Ctrl-C stops both servers.

## Architecture Guide

For a detailed visual guide with architecture diagrams and approach comparison, see `design/relay-proxy-guide.html`.
