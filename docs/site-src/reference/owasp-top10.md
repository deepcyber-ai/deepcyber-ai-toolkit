# OWASP LLM Top 10 Quick Reference

The OWASP Top 10 for Large Language Model Applications identifies the most critical security risks to LLM-based applications. Use this as a reference when triaging findings from DeepCyber scans.

## The Top 10

| ID | Category | What to look for |
|----|----------|-----------------|
| **LLM01** | Prompt Injection | System prompt override, instruction bypass, indirect injection via external content |
| **LLM02** | Insecure Output Handling | Unfiltered/unsanitised responses, XSS in outputs, code injection via LLM output |
| **LLM03** | Training Data Poisoning | Model produces known poisoned or biased content, backdoor triggers |
| **LLM04** | Model Denial of Service | Resource exhaustion, infinite loops, token flooding, regex bombs |
| **LLM05** | Supply Chain Vulnerabilities | Compromised plugins, malicious dependencies, poisoned model files |
| **LLM06** | Sensitive Information Disclosure | PII leakage, system prompt exposure, training data extraction |
| **LLM07** | Insecure Plugin Design | Tool/function calling abuse, parameter injection, privilege escalation via plugins |
| **LLM08** | Excessive Agency | AI taking unauthorised actions, scope creep, autonomous execution without approval |
| **LLM09** | Overreliance | Confidently wrong answers, hallucinated facts, fabricated citations |
| **LLM10** | Model Theft | Model weight extraction, behaviour cloning, systematic knowledge extraction |

## Tool Coverage by OWASP Category

| OWASP | HumanBound | Promptfoo | Garak | PyRIT | Giskard | DeepTeam |
|-------|------------|-----------|-------|-------|---------|----------|
| LLM01 | Yes | Yes | Yes | Yes | Yes | Yes |
| LLM02 | Yes | Yes | — | — | — | Yes |
| LLM03 | — | — | — | — | — | — |
| LLM04 | Yes | — | Yes | — | — | Yes |
| LLM05 | — | — | — | — | — | — |
| LLM06 | Yes | Yes | Yes | Yes | Yes | Yes |
| LLM07 | Yes | Yes | — | — | — | Yes |
| LLM08 | Yes | Yes | — | — | — | Yes |
| LLM09 | Yes | Yes | — | — | Yes | Yes |
| LLM10 | — | — | Yes | — | — | — |

Use **ModelScan** for LLM05 (scanning model files for malicious payloads) and **ART** for LLM03/LLM10 (adversarial robustness and model extraction attacks).

## Severity Triage

When analysing findings, categorise by severity:

- **Critical/High** (severity > 80): Immediate remediation needed — the system is actively exploitable
- **Medium** (severity 50-80): Should fix before production — potential for exploitation under specific conditions
- **Low** (severity < 50): Nice to fix, low risk — theoretical or low-impact issues

## Common Finding Categories

| Finding | OWASP | Description |
|---------|-------|------------|
| `restriction_bypass` | LLM01 | AI answered something it shouldn't — system prompt or guardrail circumvented |
| `system_exposure` | LLM01 | System prompt or internal instructions leaked to the user |
| `pii_disclosure` | LLM06 | Personal data from training or context exposed in response |
| `off_topic_manipulation` | LLM01 | AI steered outside its intended scope or persona |
| `format_violation` | — | AI broke its own response format rules |
| `harmful_content` | LLM02 | AI generated toxic, violent, or otherwise harmful content |
| `hallucination` | LLM09 | AI fabricated facts, citations, or references |
| `excessive_agency` | LLM08 | AI attempted actions beyond its authorised scope |

## Using Policy for Triage

If your `target.yaml` has a `policy` section, use it to classify every finding:

1. **True violations** — the target did something the policy explicitly forbids
2. **Acceptable behavior** — the target stayed within policy bounds (dismiss these as false positives)
3. **Policy gaps** — areas of concern not covered by the current policy (recommend policy updates)

---

(c) 2026 Deep Cyber Ltd. All rights reserved.
