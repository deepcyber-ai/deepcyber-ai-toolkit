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

## Configuration Files

- `configs/promptfoo/promptfooconfig.yaml` — Promptfoo evaluation config (system prompt leakage, data exfiltration, indirect injection tests)
- `configs/garak/deepcyber.yaml` — Garak probe config (jailbreak, prompt injection, data exfiltration, system prompt probes)

## Project Structure

```
deepcyber-ai-toolkit/
├── Dockerfile
├── start.sh                              # Container entrypoint
├── configs/
│   ├── promptfoo/
│   │   └── promptfooconfig.yaml
│   └── garak/
│       └── deepcyber.yaml
├── scripts/
│   ├── deepcyber-scan.sh                 # Automated scan runner
│   └── selftest.sh                       # Connectivity self-test
├── results/                              # Scan output (gitignored)
└── design/
    └── DeepCyber AI Red Team Engagement Playbook.md
```

## Architecture

- **Base image:** `python:3.11-slim`
- **Platform:** `linux/arm64`
- **Runtime user:** `deepcyber` (non-root)
- **Entrypoint:** `/start.sh`
