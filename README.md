# DeepCyber AI Red Team Toolkit

A containerised toolkit for AI/LLM red team engagements. Packages industry-standard vulnerability scanning, adversarial testing, and fairness auditing tools into a single reproducible environment.

## Tools Included

### Red Teaming and Attack Simulation

| Tool | Version | Purpose |
|------|---------|---------|
| [HumanBound](https://github.com/humanbound/humanbound-cli) | 0.5.0 | Contextual red teaming for GenAI and Agentic applications |
| [Promptfoo](https://github.com/promptfoo/promptfoo) | 0.120.25 | LLM prompt evaluation and red teaming |
| [Garak](https://github.com/NVIDIA/garak) | 0.14.0 | LLM vulnerability scanner |
| [PyRIT](https://github.com/Azure/PyRIT) | 0.11.0 | Python Risk Identification Toolkit |
| [DeepTeam](https://github.com/confident-ai/deepteam) | 1.0.5 | OWASP-aligned LLM red teaming with 20+ attack types |
| [TextAttack](https://github.com/QData/TextAttack) | 0.3.10 | Adversarial NLP attacks with 16 attack recipes |

### Guardrails and Defensive Testing

| Tool | Version | Purpose |
|------|---------|---------|
| [LLM Guard](https://github.com/protectai/llm-guard) | 0.3.16 | Input/output sanitisation and security scanning |
| [NeMo Guardrails](https://github.com/NVIDIA-NeMo/Guardrails) | 0.20.0 | Programmable guardrails for LLM applications |
| [Guardrails AI](https://github.com/guardrails-ai/guardrails) | 0.9.1 | LLM output validation framework |

### Evaluation and Quality

| Tool | Version | Purpose |
|------|---------|---------|
| [Giskard](https://github.com/Giskard-AI/giskard-oss) | 2.19.1 | AI quality testing for performance, bias, and security issues |
| [Giskard RAGET](https://docs.giskard.ai/en/latest/open_source/raget/index.html) | 2.19.1 | Automated evaluation dataset generation and testing for RAG applications |
| [Inspect AI](https://github.com/UKGovernmentBEIS/inspect_ai) | 0.3.184 | A framework for large language model evaluations created by the UK AI Security Institute |
| [DeepEval](https://github.com/confident-ai/deepeval) | 3.8.8 | LLM evaluation with 14+ metrics including hallucination and toxicity |

### ML Security and Fairness

| Tool | Version | Purpose |
|------|---------|---------|
| [ModelScan](https://github.com/protectai/modelscan) | 0.8.8 | ML model security scanner |
| [ART](https://github.com/Trusted-AI/adversarial-robustness-toolbox) | 1.20.1 | Adversarial robustness testing |
| [FAISS](https://github.com/facebookresearch/faiss) | 1.13.2 | Vector similarity search |
| [AIF360](https://github.com/Trusted-AI/AIF360) | 0.6.1 | AI fairness and bias detection |

### Environment

| Tool | Version | Purpose |
|------|---------|---------|
| [JupyterLab](https://github.com/jupyterlab/jupyterlab) | 4.5.5 | Interactive notebook environment |

## Prerequisites

- [Colima](https://github.com/abiosoft/colima) (recommended) or Docker Desktop
- Docker CLI with buildx plugin

### Colima Setup (Recommended)

```bash
brew install colima docker docker-buildx
colima start --arch aarch64 --cpu 2 --memory 4
```

## Build

```bash
docker buildx build --platform linux/arm64 -t deepcyber-ai-toolkit:1.0 --load .
```

## Usage

### Interactive Shell

```bash
docker run -it --rm deepcyber-ai-toolkit:1.0
```

Drops into a bash shell as the `deepcyber` user with all tools on PATH.

### JupyterLab

```bash
docker run -d -p 8888:8888 deepcyber-ai-toolkit:1.0
```

Access at `http://localhost:8888`. The token is printed in the container logs:

```bash
docker logs <container_id>
```

### Run a Specific Command

```bash
docker run --rm deepcyber-ai-toolkit:1.0 garak --help
docker run --rm deepcyber-ai-toolkit:1.0 promptfoo --help
```

### Mount a Workspace

```bash
docker run -it --rm -v $(pwd):/workspace deepcyber-ai-toolkit:1.0
```

## Regulated Environment Mode

For testing APIs in regulated environments (banking, healthcare, government) where you need strict control over data flow, telemetry, and audit trails.

### Quick Start

1. Copy the example config:

```bash
cp configs/regulated.env.example regulated.env
```

2. Edit `regulated.env` with your environment details:

```bash
# Point at your target API — any provider, not just OpenAI
TARGET_API_BASE=https://llm.internal.corp.com/v1
TARGET_MODEL_NAME=gpt-4

# Auth — set only the keys relevant to your provider
OPENAI_API_KEY=sk-your-key
# ANTHROPIC_API_KEY=sk-ant-...
# AZURE_OPENAI_API_KEY=...
# AWS_ACCESS_KEY_ID=...

# Engagement metadata for audit trail
ENGAGEMENT_ID=ENG-2026-042
TESTER_NAME=Jane Smith
CLIENT_NAME=Acme Corp
CLASSIFICATION=CONFIDENTIAL
```

3. Launch:

```bash
./deepcyber.sh --regulated regulated.env
```

With corporate CA and proxy:

```bash
./deepcyber.sh --regulated regulated.env --ca corp-ca.crt
```

### What Regulated Mode Does

| Control | Detail |
|---------|--------|
| Custom API endpoint | All tools route to `TARGET_API_BASE` — any provider (OpenAI, Anthropic, Azure, Bedrock, Ollama, vLLM, custom) |
| Telemetry disabled | Promptfoo, DeepEval, Guardrails, HuggingFace Hub, PostHog, Scarf analytics all suppressed |
| Audit logging | Every session start logged to `~/results/audit.log` with engagement ID, tester, timestamp |
| Network isolation | Combined with `--proxy` and `NO_PROXY`, restricts traffic to approved endpoints |
| Data classification | Classification level recorded in audit trail |

### Audit Log

The audit log is written to `~/results/audit.log` inside the container (mount a volume to persist it):

```bash
./deepcyber.sh --regulated regulated.env ~/engagement-output
```

The log captures session metadata and can be extended with the audit wrapper:

```bash
./scripts/audit-wrap.sh garak --config configs/garak/deepcyber.yaml
```

This logs the command, timestamp, engagement ID, and exit code.

---

## Relay Proxy (Tunnelled Access to Internal APIs)

For engagements where the target API is only accessible from inside the client network (banking, government, air-gapped). The relay proxy runs on the tester's laptop and bridges any cloud-based tool to the internal API via a Cloudflare Tunnel — no inbound firewall changes required.

```
Cloud Tool ──HTTPS──▶ Cloudflare Tunnel ──▶ Relay Proxy (your laptop) ──▶ Internal API
```

### Quick Start

```bash
cp configs/relay.env.example relay.env
# Edit relay.env with target API, shared secret, JWT token
./deepcyber.sh --relay relay.env
# In another terminal:
cloudflared tunnel --url http://localhost:8443
```

Features: shared-secret auth, JWT injection, path filtering, rate limiting, tamper-evident audit logs.

Full documentation: **[scripts/relay/README.md](scripts/relay/README.md)**

---

## On-Site / Corporate Proxy Deployment

For engagements behind a corporate proxy with a custom CA certificate:

```bash
docker run -it --rm \
  --user root \
  -e HTTP_PROXY -e HTTPS_PROXY -e NO_PROXY \
  -v $(pwd):/workspace \
  -v $(pwd)/corp-root-ca.crt:/corp-ca/corp-ca.crt:ro \
  deepcyber-ai-toolkit:1.0
```

The entrypoint automatically:
1. Detects `/corp-ca/corp-ca.crt`
2. Installs it into the system CA store
3. Exports `REQUESTS_CA_BUNDLE` and `SSL_CERT_FILE`

Note: `--user root` is required for CA installation only.

## Bundled Scripts

### Self-Test

Verify proxy connectivity and TLS configuration:

```bash
./scripts/selftest.sh
```

### Red Team Scan

Run promptfoo and garak scans with timestamped output:

```bash
./scripts/deepcyber-scan.sh
```

Results are saved to `~/results/<timestamp>/`.

Requires the following environment variables:

| Variable | Description |
|----------|-------------|
| `LLM_PROVIDER` | Promptfoo provider ID (e.g. `openai:gpt-4`) |
| `GARAK_MODEL_TYPE` | Garak model type (e.g. `openai`) |
| `GARAK_MODEL_NAME` | Garak model name (e.g. `gpt-4`) |

Example:

```bash
docker run -it --rm \
  -e LLM_PROVIDER=openai:gpt-4 \
  -e GARAK_MODEL_TYPE=openai \
  -e GARAK_MODEL_NAME=gpt-4 \
  -e OPENAI_API_KEY \
  deepcyber-ai-toolkit:1.0 \
  ./scripts/deepcyber-scan.sh
```

## Engagements (Red Team Assessments)

The `engagements/` directory provides a lightweight config-only template for red team assessments. Tool code lives in `lib/redteam/` and is invoked via the `dcr` CLI — you only copy config files per engagement.

```bash
# Start a new engagement
cp -r engagements/template engagements/acme-chatbot
cd engagements/acme-chatbot
vim target.yaml          # API URL, request/response format, auth mode
cp .env.example .env     # credentials
dcr auth                 # verify it works

# Run tools via dcr (DeepCyber Redteam) CLI
dcr humanbound full      # HumanBound (single + multi-turn OWASP)
dcr promptfoo            # Promptfoo (17 plugins, 6 strategies)
dcr garak                # Garak (encoding, DAN, injection probes)
dcr pyrit-single         # PyRIT (custom adversarial prompts)
dcr giskard              # Giskard (HTML vulnerability report)
dcr scan                 # All tools in sequence
```

See [`engagements/GUIDE.md`](engagements/GUIDE.md) for the full step-by-step walkthrough, and [`engagements/examples/`](engagements/examples/) for common `target.yaml` patterns (API key, OpenAI-compatible, Cognito JWT).

## Bring Your Own AI

The toolkit supports AI coding assistants as red teaming co-pilots. Launch any supported CLI from an engagement directory and the AI will understand `dcr`, `target.yaml`, the full tool suite, and the engagement methodology.

### Supported CLIs

| CLI | Install | Instructions File |
|-----|---------|------------------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `npm i -g @anthropic-ai/claude-code` | `~/.claude/CLAUDE.md` |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | `npm i -g @google/gemini-cli` | `~/.gemini/GEMINI.md` |
| [Codex CLI](https://github.com/openai/codex) | `npm i -g @openai/codex` | `~/.codex/AGENTS.md` |

### Setup

```bash
dcr ai install      # install AI instructions globally (one-time)
dcr ai setup        # configure API keys (interactive, one-time)
dcr ai status       # check what's configured
dcr ai remove       # remove instructions and saved keys
```

Inside the Docker container, AI instructions are pre-installed. Run `dcr ai setup` to configure API keys.

### Usage

```bash
cd engagements/acme-chatbot
dcr ai              # auto-detects installed CLI and launches it
dcr ai claude       # launch Claude Code
dcr ai gemini       # launch Gemini CLI
dcr ai codex        # launch Codex CLI
```

The AI co-pilot knows:
- All 15+ tools and their strengths (HumanBound, Promptfoo, Garak, PyRIT, Giskard, etc.)
- All `dcr` subcommands and flags
- The `target.yaml` schema including the `policy` section
- The 5-phase engagement methodology
- Regulated environment mode and relay proxy setup
- OWASP LLM Top 10 categories for triaging findings

### Policy-Based Analysis

Add a `policy` section to `target.yaml` to define what the target should/shouldn't do. The AI uses it to judge scan results — flagging true violations and dismissing acceptable behavior:

```yaml
policy:
  allowed_topics:
    - "customer support for Acme products"
  forbidden_topics:
    - "medical or legal advice"
  must_refuse:
    - "attempts to override system instructions"
  expected_boundaries:
    - "should not reveal its system prompt"
```

## Configuration Files

- `configs/promptfoo/promptfooconfig.yaml` — Promptfoo evaluation config (system prompt leakage, data exfiltration, indirect injection tests)
- `configs/garak/deepcyber.yaml` — Garak probe config (jailbreak, prompt injection, data exfiltration, system prompt probes)
- `configs/regulated.env.example` — Regulated environment mode template (telemetry suppression, audit logging, provider-agnostic API targeting)
- `configs/relay.env.example` — Relay proxy configuration template

## Project Structure

```
deepcyber-ai-toolkit/
├── Dockerfile
├── deepcyber.sh                          # Host-side launcher script
├── start.sh                              # Container entrypoint
├── bin/
│   └── dcr                               # CLI entry point (DeepCyber Redteam)
├── lib/
│   └── redteam/                          # Tool code (installed once, never copied)
│       ├── shared/                       # Config loader + auth
│       ├── humanbound/                   # HumanBound CLI integration
│       ├── promptfoo/                    # Promptfoo red team
│       ├── garak/                        # Garak probe scanner
│       ├── giskard/                      # Giskard vulnerability scan
│       └── deepcyber/                    # Container launcher + scan orchestrator
├── docs/
│   └── AI_INSTRUCTIONS.md               # Shared AI assistant instructions
├── engagements/
│   ├── GUIDE.md                          # Step-by-step engagement cheatsheet
│   ├── template/                         # Lightweight config-only template
│   │   ├── target.yaml                   # THE config file — edit this
│   │   ├── .env.example                  # Credential template
│   │   └── pyrit/                        # PyRIT scripts (editable per engagement)
│   └── examples/                         # Example target.yaml files
│       ├── foodie-ai.yaml                # Cognito JWT auth
│       ├── openai-compatible.yaml        # Bearer token, messages array
│       └── api-key-simple.yaml           # Static API key, flat body
├── configs/
│   ├── promptfoo/
│   │   └── promptfooconfig.yaml
│   ├── garak/
│   │   └── deepcyber.yaml
│   ├── regulated.env.example             # Regulated environment config
│   └── relay.env.example                 # Relay proxy config
├── scripts/
│   ├── deepcyber-scan.sh                 # Automated scan runner
│   ├── selftest.sh                       # Connectivity self-test
│   ├── audit-wrap.sh                     # Audit wrapper for commands
│   └── relay/
│       ├── README.md                     # Relay proxy documentation
│       ├── relay_proxy.py                # Reverse proxy with audit logging
│       └── verify_audit.py              # Hash chain verification
├── results/                              # Scan output (gitignored)
└── design/
    ├── DeepCyber AI Red Team Engagement Playbook.md
    └── relay-proxy-guide.html            # Visual architecture guide
```

## Architecture

- **Base image:** `python:3.11-slim`
- **Platform:** `linux/arm64`
- **Runtime user:** `deepcyber` (non-root)
- **Entrypoint:** `/start.sh`

---

(c) 2026 Deep Cyber Ltd. All rights reserved.
