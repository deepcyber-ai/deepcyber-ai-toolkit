# Red Team Engagement Template

Reusable template for running OWASP-aligned red team assessments against any conversational AI API.

## Quick Start

```bash
# 1. Copy and rename for your engagement
cp -r samples/template samples/acme-chatbot
cd samples/acme-chatbot

# 2. Edit the ONE config file
vim target.yaml    # API URL, payload shape, auth mode, response field

# 3. Set credentials
cp .env.example .env && vim .env

# 4. Verify auth works
python shared/auth.py

# 5. Run any tool
cd humanbound && python redteam.py full
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

## What You Never Edit

| File | Why |
|------|-----|
| `shared/config.py` | Generic config loader — reads target.yaml |
| `shared/auth.py` | Pluggable auth dispatcher |
| `humanbound/redteam.py` | Reads everything from target.yaml |
| `garak/run.sh` | Generates garak config from target.yaml |
| `giskard/scan.py` | Reads everything from target.yaml |
| `promptfoo/setup.sh` | Generates promptfoo config from target.yaml |
| `deepcyber/*.sh` | Workspace-agnostic launchers |

## Tools Included

| Directory | Tool | What it does |
|-----------|------|-------------|
| `humanbound/` | [HumanBound CLI](https://humanbound.ai) | OWASP-aligned adversarial testing (single-turn, multi-turn, workflow, behavioral) |
| `promptfoo/` | [Promptfoo](https://promptfoo.dev) | Red team with 17 plugins and 6 attack strategies |
| `garak/` | [Garak](https://github.com/NVIDIA/garak) | LLM vulnerability scanner with encoding/DAN/injection probes |
| `pyrit/` | [PyRIT](https://github.com/Azure/PyRIT) | Microsoft's red teaming framework (single + multi-turn) |
| `giskard/` | [Giskard](https://giskard.ai) | LLM security scan with HTML report output |
| `deepcyber/` | DeepCyber Toolkit | Container-based launcher that runs all tools |

## Auth Modes

Configure in `target.yaml` under `auth.mode`:

- **`bearer_cognito`** — Username/password exchanged for JWT via a token endpoint
- **`api_key`** — Static API key sent in a header
- **`basic`** — HTTP Basic authentication
- **`none`** — No authentication (open API)

## Directory Structure

```
engagement-name/
├── target.yaml          # THE config file (edit this)
├── .env                 # Credentials (never commit)
├── .env.example         # Credential template
├── .gitignore
├── API_REFERENCE.md     # Target API docs (optional)
├── shared/
│   ├── config.py        # Config loader
│   ├── auth.py          # Auth dispatcher
│   └── requirements.txt
├── humanbound/
│   ├── redteam.py
│   ├── bot.json         # Auto-generated
│   └── requirements.txt
├── promptfoo/
│   ├── setup.sh
│   └── promptfooconfig.yaml  # Auto-generated
├── garak/
│   ├── run.sh
│   └── target_garak.json     # Auto-generated
├── pyrit/
│   ├── single_turn.py
│   ├── multi_turn.py
│   └── requirements.txt
├── giskard/
│   ├── scan.py
│   └── requirements.txt
├── deepcyber/
│   ├── run.sh
│   └── scan.sh
└── results/             # Test output (gitignored)
```

## Running Individual Tools

```bash
# HumanBound — full workflow
cd humanbound && python redteam.py full

# HumanBound — single-turn only
cd humanbound && python redteam.py test --single

# Promptfoo — generate config + run
cd promptfoo && bash setup.sh

# Garak — default probes
cd garak && bash run.sh

# Garak — specific probes
cd garak && bash run.sh -p dan

# PyRIT — single-turn
cd pyrit && python single_turn.py

# PyRIT — multi-turn (needs OPENAI_API_KEY)
cd pyrit && python multi_turn.py

# Giskard — full scan
cd giskard && python scan.py

# Giskard — specific detectors
cd giskard && python scan.py --only prompt_injection

# All tools via DeepCyber container
cd deepcyber && bash run.sh
```

## Requirements

Install per-tool dependencies:

```bash
pip install -r shared/requirements.txt
pip install -r humanbound/requirements.txt   # for HumanBound
pip install -r pyrit/requirements.txt        # for PyRIT
pip install -r giskard/requirements.txt      # for Giskard
npm install -g promptfoo                     # for Promptfoo
pip install garak                            # for Garak
```

---

Copyright Deep Cyber Ltd 2026
