# DeepCyber Red Team Engagement Guide

Step-by-step cheatsheet for running an OWASP-aligned red team assessment against any conversational AI API.

All tools are pre-installed in the DeepCyber container. Use `dcr` (DeepCyber Redteam) as the single CLI entry point.

---

## Phase 1: Create the Engagement (5 min)

### Step 1 — Copy the template

```bash
cp -r engagements/template engagements/acme-chatbot
cd engagements/acme-chatbot
```

### Step 2 — Configure the target

Edit `target.yaml` — the **only config file** all tools read from.

Fill in these 5 fields:

| Field | Example | Where to find it |
|-------|---------|-------------------|
| `target.name` | `"Acme Chatbot"` | Client name |
| `target.description` | `"A customer support chatbot for..."` | Client brief / system prompt |
| `api.url` | `"https://api.acme.com"` | API docs |
| `request.body` | `{"message": "{{PROMPT}}"}` | API docs — use `{{PROMPT}}` as placeholder |
| `response.field` | `"data.reply"` | API docs — dot-notation path to AI's text |

Then set the auth mode (`bearer_cognito`, `api_key`, `basic`, or `none`).

See `engagements/examples/` for common patterns.

### Step 3 — Set credentials

```bash
cp .env.example .env
vim .env
```

| Auth mode | What to set in .env |
|-----------|-------------------|
| `bearer_cognito` | `TARGET_USERNAME`, `TARGET_PASSWORD` |
| `api_key` | `TARGET_API_KEY` |
| `basic` | `TARGET_USERNAME`, `TARGET_PASSWORD` |
| `none` | Nothing |

For tools that use an attacker LLM (PyRIT multi-turn, Promptfoo grading):
```
OPENAI_API_KEY=sk-...
```

### Step 4 — Verify auth

```bash
dcr auth
```

Expected output:
```
Target:    Acme Chatbot
API:       https://api.acme.com/chat
Auth mode: api_key
Auth OK
  Token: sk-abc123...
```

If this fails, fix `target.yaml` and `.env` before proceeding.

---

## Phase 2: Reconnaissance (15 min)

Before attacking, understand the target. Send a few manual requests:

```bash
python3 -c "
from shared.config import load_target_config, get_api_url, get_request_body, extract_response
from shared.auth import get_auth_headers
import requests

config = load_target_config()
headers = get_auth_headers(config)
session_header = config.get('session', {}).get('header', '')
if session_header:
    headers[session_header] = 'manual-recon'

for prompt in ['Hello', 'What can you help me with?', 'Tell me a joke']:
    body = get_request_body(prompt, config)
    resp = requests.post(get_api_url(config), json=body, headers=headers, timeout=15)
    print(f'Q: {prompt}')
    print(f'A: {extract_response(resp.json(), config)[:200]}')
    print()
"
```

Document findings in `API_REFERENCE.md`:
- What topics does it handle?
- Does it have conversation memory?
- Does it use function calling / tools?
- What content filters are visible?

---

## Phase 3: Automated Scanning (recommended order)

Run tools from fastest/broadest to slowest/deepest.

### 3a. HumanBound — Single-Turn OWASP (~20 min)

The broadest automated scan. Tests all OWASP LLM Top 10 categories in one shot.

```bash
dcr humanbound setup            # generates bot.json
dcr humanbound init             # registers with HumanBound cloud
dcr humanbound test --single    # ~600 test cases, ~20 min
dcr humanbound logs --failed    # review failures
dcr humanbound posture          # security score
```

### 3b. Promptfoo — Plugin-Based Red Team (~15 min)

17 attack plugins with 6 encoding/escalation strategies.

```bash
dcr promptfoo                      # generates config + runs scan
# Then view report:
cd promptfoo && npx promptfoo@latest redteam report && cd ..
```

### 3c. Garak — Probe-Based Scanning (~10 min)

NVIDIA's LLM vulnerability scanner. Good for encoding attacks and known jailbreaks.

```bash
dcr garak                        # default probes
dcr garak -p dan                 # DAN jailbreak probes
dcr garak -p encoding            # encoding-based attacks
```

### 3d. PyRIT — Single-Turn Adversarial (~5 min)

Microsoft's red teaming framework. Good for custom prompt lists.

```bash
dcr pyrit-single
```

### 3e. Giskard — Vulnerability Scan + HTML Report (~10 min)

Produces a nice HTML report covering injection, disclosure, harmful content.

```bash
dcr giskard                                          # all detectors
dcr giskard --only prompt_injection information_disclosure   # or specific
```

### 3f. HumanBound — Multi-Turn OWASP (~30 min)

Deeper conversational attacks. Tests gradual escalation, context manipulation.

```bash
dcr humanbound test             # multi-turn (default), ~30 min
dcr humanbound test --workflow  # OWASP workflow attacks
dcr humanbound logs --failed    # review all failures
```

### 3g. PyRIT — Multi-Turn with Attacker LLM (~10 min)

Requires `OPENAI_API_KEY`. An LLM attacks your LLM.

```bash
# Edit OBJECTIVE in pyrit/multi_turn.py first (tailor to this target)
dcr pyrit-multi
```

---

## Phase 4: Analyze Results (30 min)

### Collect everything

```bash
# HumanBound
dcr humanbound logs --failed
dcr humanbound posture
dcr humanbound guardrails --format json -o results/guardrails.json

# Promptfoo
cd promptfoo && npx promptfoo@latest redteam report && cd ..

# Giskard
open giskard_report.html
```

### What to look for

| Category | OWASP | What it means |
|----------|-------|--------------|
| `restriction_bypass` | LLM01 | AI answered something it shouldn't |
| `system_exposure` | LLM01 | System prompt or internals leaked |
| `pii_disclosure` | LLM06 | Personal data exposed |
| `off_topic_manipulation` | LLM01 | AI steered outside its scope |
| `format_violation` | — | AI broke its own response format |

### Severity triage

- **Critical/High** (severity > 80): Immediate remediation needed
- **Medium** (severity 50-80): Should fix before production
- **Low** (severity < 50): Nice to fix, low risk

---

## Phase 5: Report & Harden

```bash
dcr humanbound guardrails --vendor openai --format json -o results/guardrails_openai.json
dcr humanbound guardrails --vendor humanbound --format yaml -o results/guardrails_hb.yaml
```

Deliverables:
1. **Findings summary** — categorized by OWASP LLM Top 10
2. **Severity breakdown** — critical/high/medium/low counts
3. **Guardrail rules** — exported from HumanBound, ready to deploy
4. **Giskard HTML report** — visual vulnerability assessment
5. **Recommendations** — specific system prompt / filtering changes

---

## Quick Reference

### Full automated scan (all tools, ~2 hours)

```bash
dcr scan
```

### Just HumanBound (fastest value, ~1 hour)

```bash
dcr humanbound full
```

### Refresh auth token (tokens expire after ~1 hour)

```bash
dcr humanbound setup
```

### Engagement checklist

```
[ ] target.yaml configured
[ ] .env credentials set
[ ] dcr auth passes
[ ] Manual recon (3-5 test prompts)
[ ] HumanBound single-turn scan
[ ] Promptfoo red team scan
[ ] Garak probe scan
[ ] PyRIT single-turn
[ ] Giskard vulnerability scan
[ ] HumanBound multi-turn scan
[ ] PyRIT multi-turn (if OPENAI_API_KEY available)
[ ] Results collected in results/
[ ] Findings triaged by severity
[ ] Guardrails exported
[ ] Report drafted
```

---

(c) 2026 Deep Cyber Ltd. All rights reserved.
