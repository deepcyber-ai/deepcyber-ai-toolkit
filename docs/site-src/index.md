# DeepCyber AI Red Team Toolkit

```
    ____                  ______      __
   / __ \___  ___  ____  / ____/_  __/ /_  ___  _____
  / / / / _ \/ _ \/ __ \/ /   / / / / __ \/ _ \/ ___/
 / /_/ /  __/  __/ /_/ / /___/ /_/ / /_/ /  __/ /
/_____/\___/\___/ .___/\____/\__, /_.___/\___/_/
               /_/          /____/
                          AI Red Team Toolkit
```

A comprehensive toolkit for AI/LLM red team assessments. Packages industry-standard vulnerability scanning, adversarial testing, and fairness auditing tools into a single environment with a unified CLI.

---

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

### Security Tools

| Tool | Purpose |
|------|---------|
| Metasploit Framework | Penetration testing framework |
| Burp Suite Community | Web application security testing |
| OWASP ZAP | Web application security scanner |
| THC Hydra | Network authentication brute-forcing |
| Medusa | Parallel login brute-forcer |
| John the Ripper | Password cracker |
| Hashcat | Advanced password recovery |

### AI Red Team Assistant

| CLI | Purpose |
|-----|---------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | AI coding assistant (Anthropic) |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | AI coding assistant (Google) |
| [Codex CLI](https://github.com/openai/codex) | AI coding assistant (OpenAI) |

All three CLIs are pre-configured with DeepCyber instructions. Run `dcr ai setup` to add API keys, then `dcr ai` to launch.

---

## Quick Start

```bash
# Start a new project
cp -r ~/projects/template ~/projects/acme-chatbot
cd ~/projects/acme-chatbot

# Edit the config
vim target.yaml          # API URL, request/response format, auth mode
cp .env.example .env     # credentials

# Verify and scan
dcr auth                 # verify it works
dcr humanbound full      # HumanBound (single + multi-turn OWASP)
dcr promptfoo            # Promptfoo (17 plugins, 6 strategies)
dcr garak                # Garak (encoding, DAN, injection probes)
dcr scan                 # All tools in sequence
```

See the [Red Team Methodology](getting-started/methodology.md) for the full step-by-step walkthrough, and the [Project Setup](getting-started/project-setup.md) for template details.

---

## Directory Layout

```
/home/deepcyber/
├── bin/dcr              # DeepCyber CLI
├── lib/redteam/         # Tool integration library
├── configs/             # Tool configuration templates
├── scripts/             # Utility scripts
├── projects/
│   ├── template/        # Copy to start a new project
│   └── examples/        # Example project configs
├── docs/                # Documentation (this site)
└── results/             # Scan output directory
```

---

(c) 2026 Deep Cyber Ltd. All rights reserved.
