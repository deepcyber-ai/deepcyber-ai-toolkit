# Regulated Environment Mode

For testing APIs in regulated environments (banking, healthcare, government) where you need strict control over data flow, telemetry, and audit trails.

## Quick Start

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

# Project metadata for audit trail
PROJECT_ID=PRJ-2026-042
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

## What Regulated Mode Does

| Control | Detail |
|---------|--------|
| Custom API endpoint | All tools route to `TARGET_API_BASE` — any provider (OpenAI, Anthropic, Azure, Bedrock, Ollama, vLLM, custom) |
| Telemetry disabled | Promptfoo, DeepEval, Guardrails, HuggingFace Hub, PostHog, Scarf analytics all suppressed |
| Audit logging | Every session start logged to `~/results/audit.log` with project ID, tester, timestamp |
| Network isolation | Combined with `--proxy` and `NO_PROXY`, restricts traffic to approved endpoints |
| Data classification | Classification level recorded in audit trail |
| Corporate CA support | Mount a CA certificate with `--ca corp-ca.crt` — auto-installed into system trust store |
| Connectivity self-test | Run `./scripts/selftest.sh` to verify proxy and TLS configuration |

## Key Config Fields

| Field | Purpose |
|-------|---------|
| `TARGET_API_BASE` | Base URL for the target API |
| `TARGET_MODEL_NAME` | Model identifier (gpt-4, claude-sonnet, llama-3, etc.) |
| `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` / `AZURE_*` / `AWS_*` | Provider credentials |
| `LLM_PROVIDER` | Promptfoo provider string (e.g. `openai:gpt-4`) |
| `GARAK_MODEL_TYPE` / `GARAK_MODEL_NAME` | Garak model config |
| `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY` | Corporate proxy |
| `CA_CERT_PATH` | Path to corporate CA certificate |
| `PROJECT_ID` / `TESTER_NAME` / `CLIENT_NAME` / `CLASSIFICATION` | Audit metadata |

## Audit Log

The audit log is written to `~/results/audit.log` inside the container (mount a volume to persist it):

```bash
./deepcyber.sh --regulated regulated.env ~/project-output
```

The log captures session metadata and can be extended with the audit wrapper:

```bash
./scripts/audit-wrap.sh garak --config configs/garak/deepcyber.yaml
```

This logs the command, timestamp, project ID, and exit code.

## Connectivity Test

```bash
./scripts/selftest.sh    # Verifies proxy and TLS configuration
```

---

(c) 2026 Deep Cyber Ltd. All rights reserved.
