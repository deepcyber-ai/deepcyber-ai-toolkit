# Tool Quick Reference

All tools are pre-installed in the DeepCyber VM. Use `dcr` as the CLI entry point for red teaming tools.

## Red Teaming and Attack Simulation

| Tool | DCR Command | Best For |
|------|-------------|----------|
| **HumanBound** | `dcr humanbound full` | Broadest OWASP coverage, compliance-grade assessment, security posture scoring |
| **Promptfoo** | `dcr promptfoo` | 17 attack plugins with 6 encoding/escalation strategies, LLM-graded results |
| **Garak** | `dcr garak` | Known jailbreak patterns (DAN, encoding), rapid scanning |
| **PyRIT (single)** | `dcr pyrit-single` | Custom adversarial prompt lists, batch testing without attacker LLM |
| **PyRIT (multi)** | `dcr pyrit-multi` | LLM-vs-LLM attacks, adaptive adversarial escalation (needs OPENAI_API_KEY) |
| **DeepTeam** | Python API | Additional OWASP coverage with 20+ attack types |
| **TextAttack** | Python API | Text perturbation, adversarial NLP, classifier robustness testing |

## Guardrails and Defensive Testing

| Tool | Usage | Best For |
|------|-------|----------|
| **LLM Guard** | `python3 -c 'from llm_guard import ...'` | Testing input/output sanitisation for injection, toxicity, PII |
| **NeMo Guardrails** | Python API | Building and testing custom conversation rails and topic boundaries |
| **Guardrails AI** | Python API | Structured output validation, schema enforcement testing |

## Evaluation and Quality

| Tool | DCR Command | Best For |
|------|-------------|----------|
| **Giskard** | `dcr giskard` | Visual HTML vulnerability reports, compliance documentation |
| **Giskard RAGET** | Python API | RAG pipeline evaluation and test dataset generation |
| **Inspect AI** | Python API | Government-aligned AI safety evaluations (UK AISI framework) |
| **DeepEval** | Python API | Quantitative metrics (hallucination, toxicity, faithfulness, bias) |

## ML Security and Fairness

| Tool | Usage | Best For |
|------|-------|----------|
| **ModelScan** | `modelscan` | Supply chain security — detecting malicious payloads in model files |
| **ART** | Python API | Evasion attacks, poisoning attacks, model extraction |
| **AIF360** | Python API | Fairness audits, bias detection, demographic parity testing |
| **FAISS** | Python API | Vector similarity search for embedding analysis |

## Security Tools

| Tool | Command | Best For |
|------|---------|----------|
| **Metasploit** | `msfconsole` | Penetration testing framework |
| **Burp Suite** | `burpsuite` | Web application security testing |
| **OWASP ZAP** | `zaproxy` | Web application security scanning |
| **THC Hydra** | `hydra` | Network authentication brute-forcing |
| **Medusa** | `medusa` | Parallel login brute-forcer |
| **John the Ripper** | `john` | Password cracking |
| **Hashcat** | `hashcat` | Advanced password recovery (GPU-accelerated) |

## AI Coding Assistants

| CLI | Command | Provider |
|-----|---------|----------|
| **Claude Code** | `dcr ai claude` | Anthropic |
| **Gemini CLI** | `dcr ai gemini` | Google |
| **Codex CLI** | `dcr ai codex` | OpenAI |

Run `dcr ai setup` to configure API keys, then `dcr ai` to auto-launch the first available CLI.

## Environment

| Tool | Command | Purpose |
|------|---------|---------|
| **JupyterLab** | `jupyter lab` | Interactive notebook environment for custom scripts |

## Recommended Scan Order

For a complete assessment, run tools from fastest/broadest to slowest/deepest:

1. `dcr humanbound test --single` — Broadest OWASP single-turn (~20 min)
2. `dcr promptfoo` — 17 plugins + 6 strategies (~15 min)
3. `dcr garak` — Known jailbreaks + encoding attacks (~10 min)
4. `dcr pyrit-single` — Custom adversarial prompts (~5 min)
5. `dcr giskard` — Vulnerability scan + HTML report (~10 min)
6. `dcr humanbound test` — Multi-turn OWASP (~30 min)
7. `dcr pyrit-multi` — LLM-vs-LLM attack (~10 min)

Or run everything at once: `dcr scan`

---

(c) 2026 Deep Cyber Ltd. All rights reserved.
