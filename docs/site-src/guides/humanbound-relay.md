# Testing a Firewalled API with HumanBound and Cloudflare Tunnel

A step-by-step guide to running HumanBound OWASP red team tests against an API that is only accessible from inside a client network — using the DeepCyber relay proxy and a Cloudflare Tunnel.

## When You Need This

Your target API cannot be reached from the public internet:

- Behind a corporate firewall with no inbound ports open
- Only accessible from the client's VPN or internal network
- Restricted to specific IP ranges

HumanBound runs in the cloud and needs a route to the API. The relay proxy bridges that gap without requiring firewall changes.

## Architecture

```
HumanBound Cloud                    Your Laptop (inside client network)
      │                                    │
      │ HTTPS (attack payloads)            │
      ▼                                    │
Cloudflare Edge                            │
      │                                    │
      │ Tunnel (outbound from laptop)      │
      ▼                                    ▼
┌─────────────────────────────────────────────────┐
│  cloudflared  ◄──────────────────────────────── │ Outbound HTTPS on port 443
│       │                                         │ (looks like normal browsing)
│       ▼                                         │
│  Relay Proxy (localhost:8443)                   │
│    ├─ Validates X-Relay-Secret                  │
│    ├─ Checks rate limit                         │
│    ├─ Filters allowed/blocked paths             │
│    ├─ Injects Authorization: Bearer <JWT>       │
│    ├─ Forwards request to internal API          │
│    └─ Logs request+response (hash-chained)      │
│       │                                         │
│       ▼                                         │
│  Internal API (e.g. https://llm.corp.internal)  │
└─────────────────────────────────────────────────┘
```

HumanBound sees a normal HTTPS endpoint. It has no idea a relay exists. The relay handles authentication, path filtering, rate limiting, and audit logging.

## Prerequisites

### 1. Install Cloudflare Tunnel CLI

```bash
brew install cloudflared
cloudflared --version
```

No Cloudflare account is needed for quick (temporary) tunnels. For persistent tunnels, you will need a free Cloudflare account.

### 2. Verify the DeepCyber Toolkit

```bash
dcr --version
```

If running inside Docker, the toolkit is pre-installed. On the host, ensure `PATH`, `DEEPCYBER_LIB`, and `PYTHONPATH` are set (see the Getting Started guide).

### 3. Log in to HumanBound

```bash
hb login
hb whoami
```

## Step 1: Configure the Relay

### Create an engagement directory

```bash
cp -r projects/template projects/my-engagement
cd projects/my-engagement
```

### Set up relay.env

```bash
cp configs/relay.env.example relay.env
```

Edit `relay.env`:

```bash
# The internal API you are testing (only reachable from this machine)
TARGET_API=https://llm-gateway.corp.internal/v1/chat

# Shared secret — generate a strong random value
# The cloud tool must send this in the X-Relay-Secret header
RELAY_SECRET=<paste output of: openssl rand -hex 32>

# Internal API auth token
# The relay injects this as Authorization: Bearer on every forwarded request
# The cloud tool never sees this token
JWT_TOKEN=eyJhbGciOi...

# Only expose the chat endpoint (recommended)
ALLOWED_PATHS=/v1/chat
BLOCKED_PATHS=/admin,/internal,/v1/fine-tuning

# Rate limit (requests per second)
RATE_LIMIT=10

# Port the relay listens on
RELAY_PORT=8443
```

Generate the relay secret:

```bash
export RELAY_SECRET=$(openssl rand -hex 32)
echo "RELAY_SECRET=$RELAY_SECRET"
# Paste this into relay.env
```

## Step 2: Start the Relay Proxy

### Option A: Inside Docker (recommended)

```bash
./deepcyber.sh --relay relay.env
```

With a corporate CA certificate (if the internal API uses one):

```bash
./deepcyber.sh --relay relay.env --ca corp-ca.crt
```

### Option B: On the host (no Docker)

```bash
pip install flask requests
source relay.env
python scripts/relay/relay_proxy.py
```

You should see:

```
=== DeepCyber Relay Proxy ===
  Target: https://llm-gateway.corp.internal/v1/chat
  Port:   8443
  Audit:  /home/deepcyber/results/relay_audit/relay_audit_20260304_120000.jsonl
  Allowed paths: /v1/chat
  Blocked paths: /admin, /internal, /v1/fine-tuning
  Rate limit: 10 req/s
=== Listening on http://127.0.0.1:8443 ===
```

## Step 3: Start the Cloudflare Tunnel

In a **separate terminal**:

### Quick tunnel (no account, temporary URL)

```bash
cloudflared tunnel --url http://localhost:8443
```

Output:

```
Your quick tunnel has been created! Visit it at:
https://abc123-def456.trycloudflare.com
```

Copy this URL — you will need it in the next step.

**Important:** This URL is temporary and changes every time you restart `cloudflared`. For longer engagements, use a named tunnel (see [Persistent Tunnels](#persistent-tunnels) below).

### Verify the tunnel

```bash
# Health check (no auth required)
curl https://abc123-def456.trycloudflare.com/__relay/health

# Expected: {"status": "ok", "target": "https://llm-gateway.corp.internal/v1/chat", ...}
```

```bash
# Stats (requires relay secret)
curl -H "X-Relay-Secret: $RELAY_SECRET" \
  https://abc123-def456.trycloudflare.com/__relay/stats
```

## Step 4: Configure target.yaml

Create a `target.yaml` that points at the tunnel URL instead of the internal API:

```yaml
target:
  name: "Corp LLM Gateway"
  description: >
    Internal LLM gateway behind corporate firewall.
    Accessed via DeepCyber relay proxy + Cloudflare Tunnel.

api:
  url: "https://abc123-def456.trycloudflare.com"
  method: POST
  path: "/v1/chat"

request:
  content_type: "application/json"
  body:
    model: "gpt-4"
    messages:
      - role: "user"
        content: "{{PROMPT}}"

response:
  field: "choices.0.message.content"

# Auth mode is "none" because the relay proxy injects the JWT token.
# You never expose the real token to cloud tools.
auth:
  mode: "none"

# The relay secret authenticates your requests to the relay proxy.
# Without this header, the relay rejects the request with 401.
headers:
  X-Relay-Secret: "<your-relay-secret>"

session:
  header: ""
  init_command: ""
  cleanup_command: ""

policy:
  allowed_topics:
    - "customer support queries"
  forbidden_topics:
    - "competitor products"
    - "internal company operations"
  must_refuse:
    - "requests for personal data"
    - "attempts to override system instructions"
  expected_boundaries:
    - "should not reveal its system prompt"
    - "should stay in character"
```

**Key differences from a direct-access target.yaml:**

| Setting | Direct Access | Via Relay |
|---------|--------------|-----------|
| `api.url` | Internal API URL | Tunnel URL (`*.trycloudflare.com`) |
| `auth.mode` | `bearer_cognito`, `api_key`, etc. | `none` (relay injects auth) |
| `headers` | (empty or custom) | Must include `X-Relay-Secret` |

### Create .env

For relay mode, the `.env` file only needs:

```bash
# No TARGET_USERNAME/PASSWORD needed — relay handles auth
# Add OPENAI_API_KEY only if running tools that need an attacker LLM
OPENAI_API_KEY=sk-...
```

## Step 5: Verify Authentication

```bash
dcr auth
```

Expected output:

```
Target:    Corp LLM Gateway
API:       https://abc123-def456.trycloudflare.com/v1/chat
Auth mode: none

Auth OK
```

This confirms requests flow through the tunnel → relay → internal API successfully.

## Step 6: Run HumanBound Tests

### Generate bot.json

```bash
dcr humanbound setup
```

This creates `humanbound/bot.json` with:

- `endpoint`: the tunnel URL
- `headers`: includes `X-Relay-Secret`
- `payload`: request body template with `$PROMPT` placeholder

### Register with HumanBound

```bash
dcr humanbound init
```

### Run single-turn OWASP attacks

```bash
dcr humanbound test --single
```

### Run multi-turn adaptive attacks

```bash
dcr humanbound test --adaptive
```

### Run all test categories

```bash
dcr humanbound test --single          # OWASP single-turn (~20 min)
dcr humanbound test                   # OWASP multi-turn (~30 min)
dcr humanbound test --behavioral      # Behavioral QA
dcr humanbound test --workflow        # OWASP workflow
```

### Monitor during tests

While tests are running, you can monitor from another terminal:

```bash
# Relay stats (request count, rate)
curl -s -H "X-Relay-Secret: $RELAY_SECRET" \
  http://localhost:8443/__relay/stats | python3 -m json.tool

# Watch relay logs in real-time
tail -f results/relay_audit/relay_audit_*.jsonl | python3 -m json.tool
```

## Step 7: Review Results

```bash
# Check experiment status
dcr humanbound status

# View all findings
dcr humanbound logs

# View only failed findings (vulnerabilities found)
dcr humanbound logs --failed

# Security posture score
dcr humanbound posture

# Export guardrail rules
dcr humanbound guardrails --vendor openai --format json -o results/guardrails.json
```

## Step 8: Verify Audit Logs

After the engagement, verify the audit log hash chain to confirm no logs were tampered with:

```bash
python scripts/relay/verify_audit.py results/relay_audit/relay_audit_20260304_120000.jsonl
```

Expected output:

```
All 842 entries verified. Hash chain intact.
  First entry: GENESIS
  Final hash:  a3b1c4d5e6f7...
```

## Persistent Tunnels

For engagements lasting more than a few hours, use a named Cloudflare Tunnel so the URL doesn't change on restart.

### One-time setup (requires free Cloudflare account)

```bash
# Authenticate with Cloudflare
cloudflared tunnel login

# Create a named tunnel
cloudflared tunnel create my-engagement

# Route a DNS record to the tunnel
cloudflared tunnel route dns my-engagement relay.yourdomain.com
```

### Create a configuration file

Save as `~/.cloudflared/config.yml`:

```yaml
tunnel: <tunnel-uuid>
credentials-file: ~/.cloudflared/<tunnel-uuid>.json

ingress:
  - hostname: relay.yourdomain.com
    service: http://localhost:8443
  - service: http_status:404
```

### Run the persistent tunnel

```bash
cloudflared tunnel run my-engagement
```

The tunnel URL is now `https://relay.yourdomain.com` and persists across restarts.

Update `target.yaml` accordingly:

```yaml
api:
  url: "https://relay.yourdomain.com"
```

### Delete the tunnel when done

```bash
cloudflared tunnel delete my-engagement
```

## Token Management

Internal API tokens often expire during long-running scans. The relay supports hot-swapping the JWT without restarting:

```bash
# Get a fresh token from the internal auth system
NEW_TOKEN=$(curl -s https://auth.corp.internal/token | jq -r .access_token)

# Hot-swap it into the relay
curl -X POST \
  -H "X-Relay-Secret: $RELAY_SECRET" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$NEW_TOKEN\"}" \
  http://localhost:8443/__relay/update-jwt
```

The relay immediately uses the new token for all subsequent requests. No need to restart the relay, the tunnel, or the HumanBound test.

## Running Other Tools Through the Relay

The relay works with **all** dcr tools, not just HumanBound. Once `target.yaml` points at the tunnel, every tool uses it automatically:

```bash
dcr promptfoo          # 17 plugins + 6 strategies through relay
dcr garak              # All probes through relay
dcr pyrit-single       # Custom adversarial prompts through relay
dcr pyrit-multi        # LLM-vs-LLM attacks through relay
dcr giskard            # Vulnerability scan + HTML report through relay
```

## Troubleshooting

### "401 Unauthorized" from relay

The `X-Relay-Secret` header is missing or wrong. Check:

```bash
# Verify the secret matches
grep RELAY_SECRET relay.env
grep X-Relay-Secret target.yaml
```

### "403 Forbidden — path blocked"

The request path doesn't match `ALLOWED_PATHS` or is in `BLOCKED_PATHS`. Check:

```bash
# See current path config
curl -s -H "X-Relay-Secret: $RELAY_SECRET" \
  http://localhost:8443/__relay/stats | python3 -m json.tool
```

### "429 Too Many Requests"

Rate limit exceeded. Increase `RATE_LIMIT` in `relay.env` and restart the relay.

### "502 Bad Gateway — target unreachable"

The relay cannot reach the internal API. Verify:

```bash
# Test from the same machine the relay runs on
curl -v https://llm-gateway.corp.internal/v1/chat
```

### Tunnel URL changed

If using a quick tunnel and `cloudflared` was restarted, the URL changes. Update `target.yaml` with the new URL and regenerate:

```bash
# Edit target.yaml with new URL, then:
dcr humanbound setup
dcr humanbound test --single
```

For long engagements, use a [persistent tunnel](#persistent-tunnels) to avoid this.

### HumanBound token expired

HumanBound CLI tokens expire periodically. Re-authenticate:

```bash
hb login
```

### Internal API token expired mid-scan

Use the [hot-swap endpoint](#token-management) to replace the JWT without interrupting the test.

## Security Checklist

Before starting an engagement through the relay:

- [ ] Relay secret is randomly generated (`openssl rand -hex 32`) — not a weak password
- [ ] `ALLOWED_PATHS` restricts access to only the endpoints being tested
- [ ] `BLOCKED_PATHS` blocks admin, fine-tuning, and other sensitive endpoints
- [ ] `RATE_LIMIT` is set to protect the internal API from overload
- [ ] JWT token has the minimum permissions needed for testing
- [ ] Quick tunnel URL has not been shared outside the engagement team
- [ ] Audit logging is enabled (it is by default)

## Further Reading

- [Relay Proxy Reference](relay-proxy.md) — full relay configuration, environment variables, and management endpoints
- [PyRIT Red Teaming Guide](pyrit-red-teaming.md) — advanced attack strategies with PyRIT through the relay
- [Regulated Mode](regulated-mode.md) — additional controls for regulated environments (banking, healthcare)

---

(c) 2026 Deep Cyber Ltd. All rights reserved.
