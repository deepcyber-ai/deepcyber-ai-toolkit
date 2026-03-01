# HumanBound Red Teaming

A Python CLI that drives [AIandMe](https://github.com/aiandme-io/aiandme-cli) (HumanBound) to run OWASP-aligned adversarial tests against the Foodie AI API as a black-box penetration test.

## Prerequisites

- Python 3.10+
- An [AIandMe](https://aiandme.io) account

## Setup

1. Install dependencies:

```bash
pip install -r requirements.txt
pip install -r ../shared/requirements.txt
```

2. Create a `.env` file from the template (or use the one in the repo root):

```bash
cp .env.example .env
```

3. Edit `.env` with your Foodie AI username and password.

4. Log in to AIandMe (opens a browser):

```bash
aiandme login
```

## Quick start

Generate the bot configuration and run the full workflow:

```bash
python redteam.py full
```

This will:
1. Generate `bot.json` from your `.env` credentials
2. Verify AIandMe authentication
3. Scan the API and create a project
4. Run single-turn OWASP attacks
5. Run multi-turn OWASP attacks
6. Display the security posture score and failed findings

## Commands

| Command | Description |
|---------|-------------|
| `python redteam.py setup` | Generate `bot.json` from `.env` |
| `python redteam.py init` | Scan the bot and create an AIandMe project |
| `python redteam.py test` | Run multi-turn OWASP attacks (default) |
| `python redteam.py test --single` | Run single-turn attacks |
| `python redteam.py test --adaptive` | Run adaptive (evolutionary) attacks |
| `python redteam.py test --agentic` | Run agentic multi-turn attacks |
| `python redteam.py test --behavioral` | Run behavioral QA tests |
| `python redteam.py test --level system` | Run deeper system-level tests (~45 min) |
| `python redteam.py status --watch` | Poll experiment status until complete |
| `python redteam.py logs` | View all test findings |
| `python redteam.py logs --failed` | View only failed findings |
| `python redteam.py posture` | View security posture score (0–100) |
| `python redteam.py guardrails` | Export guardrail rules |
| `python redteam.py full` | Run the complete workflow end-to-end |

## Test categories

| Flag | Category | Description |
|------|----------|-------------|
| *(default)* | `owasp_multi_turn` | Conversational attacks — context manipulation, gradual escalation |
| `--single` | `owasp_single_turn` | Single-prompt attacks — injection, jailbreaks, data exfiltration |
| `--agentic` | `owasp_agentic_multi_turn` | Tool-using agent attacks — goal hijacking, privilege escalation |
| `--behavioral` | `behavioral` | Intent boundary and response quality validation |
| `--adaptive` | `owasp_multi_turn` + adaptive | Evolutionary attacks that adapt based on bot responses |

## Testing depth

| Level | Time | Scope |
|-------|------|-------|
| `unit` (default) | ~20 min | Standard coverage |
| `system` | ~45 min | Deep testing, more variations |
| `acceptance` | ~90 min | Full coverage, all attack vectors |

## How bot.json works

The `setup` command authenticates with `/auth/token` and generates `bot.json`:

- **`thread_init`** — sends `"clear"` to reset conversation memory before each test session
- **`chat_completion`** — sends adversarial prompts via the `$PROMPT` placeholder in `{"input": "$PROMPT"}`
- **`thread_auth`** — left empty (authentication is handled via Bearer token in headers)

The bot.json is gitignored since it contains your JWT token. Tokens expire after 1 hour — re-run `python redteam.py setup` to refresh.
