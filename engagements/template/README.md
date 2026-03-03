# Red Team Engagement Template

Lightweight config-only template for running OWASP-aligned red team assessments against any conversational AI API.

Tool code lives in `lib/redteam/` and is invoked via the `dcr` CLI — you only copy config files per engagement.

## Quick Start

```bash
# 1. Copy and rename for your engagement
cp -r engagements/template engagements/acme-chatbot
cd engagements/acme-chatbot

# 2. Edit the ONE config file
vim target.yaml    # API URL, payload shape, auth mode, response field

# 3. Set credentials
cp .env.example .env && vim .env

# 4. Verify auth works
dcr auth

# 5. Run any tool
dcr humanbound full
```

## What You Edit

| File | What to change |
|------|---------------|
| `target.yaml` | API URL, request/response format, auth mode, target name & description |
| `.env` | Credentials (username/password, API key, OpenAI key) |

## What You Sometimes Edit

| File | When |
|------|------|
| `pyrit/multi_turn.py` | To change the attack `OBJECTIVE` or `MAX_TURNS` |
| `pyrit/single_turn.py` | To add/remove `TEST_PROMPTS` |
| `API_REFERENCE.md` | To document the target API for the team |

## Directory Structure

```
engagement-name/
├── target.yaml          # THE config file (edit this)
├── .env                 # Credentials (never commit)
├── .env.example         # Credential template
├── .gitignore
├── API_REFERENCE.md     # Target API docs (optional)
├── pyrit/               # Editable per engagement
│   ├── single_turn.py   # Edit TEST_PROMPTS
│   └── multi_turn.py    # Edit OBJECTIVE, MAX_TURNS
├── humanbound/          # Runtime-generated (gitignored)
│   └── bot.json
├── garak/               # Runtime-generated (gitignored)
│   └── target_garak.json
├── promptfoo/           # Runtime-generated (gitignored)
│   └── promptfooconfig.yaml
└── results/             # Test output (gitignored)
```

## Running Tools (via dcr CLI)

```bash
# Verify authentication
dcr auth

# HumanBound — full workflow
dcr humanbound full

# HumanBound — single-turn only
dcr humanbound test --single

# Promptfoo — generate config + run
dcr promptfoo

# Garak — default probes
dcr garak

# Garak — specific probes
dcr garak -p dan

# PyRIT — single-turn
dcr pyrit-single

# PyRIT — multi-turn (needs OPENAI_API_KEY)
dcr pyrit-multi

# Giskard — full scan
dcr giskard

# All tools in sequence
dcr scan
```

## Auth Modes

Configure in `target.yaml` under `auth.mode`:

- **`bearer_cognito`** — Username/password exchanged for JWT via a token endpoint
- **`api_key`** — Static API key sent in a header
- **`basic`** — HTTP Basic authentication
- **`none`** — No authentication (open API)

## Tools

| Tool | What it does |
|------|-------------|
| [HumanBound CLI](https://humanbound.ai) | OWASP-aligned adversarial testing (single-turn, multi-turn, workflow, behavioral) |
| [Promptfoo](https://promptfoo.dev) | Red team with 17 plugins and 6 attack strategies |
| [Garak](https://github.com/NVIDIA/garak) | LLM vulnerability scanner with encoding/DAN/injection probes |
| [PyRIT](https://github.com/Azure/PyRIT) | Microsoft's red teaming framework (single + multi-turn) |
| [Giskard](https://giskard.ai) | LLM security scan with HTML report output |

---

(c) 2026 Deep Cyber Ltd. All rights reserved.
