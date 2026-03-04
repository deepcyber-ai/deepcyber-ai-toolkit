# DeepCyber Relay Proxy

A reverse proxy for red team projects where the target API is only accessible from inside the client network. The relay runs on the tester's laptop and bridges any cloud-based tool to the internal API via a secure tunnel.

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

## How It Works

### Request flow

1. The cloud tool sends a request to the tunnel URL (e.g. `https://xxxx.trycloudflare.com/v1/chat/completions`)
2. Cloudflare routes it through the tunnel to `localhost:8443` on your laptop
3. The relay proxy:
   - Checks the `X-Relay-Secret` header (rejects if wrong or missing)
   - Checks the rate limit
   - Checks the path is allowed and not blocked
   - Strips the `X-Relay-Secret` header so the internal API never sees it
   - Injects `Authorization: Bearer <JWT>` so the cloud tool never sees the real token
   - Forwards the request to the internal API
   - Logs both request and response with tamper-evident hash chaining
   - Returns the response back through the tunnel to the cloud tool

From the cloud tool's perspective, it's just talking to a normal HTTPS API. It has no idea a relay exists.

### Why no Cloudflare configuration is needed

Cloudflare Tunnel has a "quick tunnel" mode that requires **zero configuration** — no account, no DNS setup, no dashboard:

```bash
brew install cloudflared        # one-time install
cloudflared tunnel --url http://localhost:8443
```

What happens:

1. `cloudflared` makes an **outbound** HTTPS connection to Cloudflare's edge on port 443
2. Cloudflare assigns a random `*.trycloudflare.com` URL
3. Any request to that URL gets routed back through the existing outbound connection to your localhost

This works in restrictive networks because:

- **Outbound only** — your laptop initiates the connection, no firewall rules need changing
- **Port 443** — looks like normal HTTPS browsing traffic to the corporate network
- **Ephemeral** — the URL is random and dies when you Ctrl-C, leaving no persistent infrastructure

The relay binds to `127.0.0.1` only, so the tunnel is the *only* way in. The shared secret ensures that even if someone discovers the random URL, they can't use it without the header.

For a persistent URL across restarts, you would need a Cloudflare account and a named tunnel (see [Cloudflare Tunnel Setup](#cloudflare-tunnel-setup) below).

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
cloudflared tunnel run my-project
```

Copy the tunnel URL (e.g. `https://xxxx.trycloudflare.com`) and configure it as the target endpoint in your cloud tool.

### 4. Configure Your Cloud Tool

Point the cloud tool at the tunnel URL and include the shared secret:

```bash
# Example: curl through the relay
curl -H "X-Relay-Secret: $RELAY_SECRET" \
     https://xxxx.trycloudflare.com/v1/chat/completions \
     -d '{"model":"gpt-4","messages":[{"role":"user","content":"hello"}]}'
```

## Management Endpoints

These endpoints are served by the relay itself (not forwarded to the target):

| Endpoint | Auth | Method | Purpose |
|----------|------|--------|---------|
| `/__relay/health` | No | GET | Tunnel liveness check — returns `{"status": "ok"}` |
| `/__relay/stats` | Yes | GET | Request count, log size, current config |
| `/__relay/update-jwt` | Yes | POST | Hot-swap JWT token without restarting |

### Hot-Swapping JWT Tokens

If the internal API token expires mid-project:

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

Logs are written to `~/results/relay_audit/`. Mount a volume to persist them when running in Docker:

```bash
./deepcyber.sh --relay relay.env ~/project-output
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
cloudflared tunnel create my-project
cloudflared tunnel route dns my-project relay.yourdomain.com
cloudflared tunnel run my-project
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

This starts a mock echo server and the relay proxy, runs 17 curl-based tests covering authentication, path filtering, header handling, request forwarding, rate limiting, JWT hot-swap, and audit log integrity, then cleans up.

### Manual / Interactive Testing

Start a mock target and the relay together for hands-on exploration:

```bash
bash scripts/relay/dev_relay.sh
```

This starts both servers in the foreground with sensible defaults (secret: `mysecret`, port: 8443). Then curl from another terminal:

```bash
curl -s -H "X-Relay-Secret: mysecret" \
  http://localhost:8443/v1/chat/completions | python3 -m json.tool
```

---

(c) 2026 Deep Cyber Ltd. All rights reserved.
