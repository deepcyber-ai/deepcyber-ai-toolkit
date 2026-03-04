# AI Assistant Guide

The DeepCyber toolkit supports AI coding assistants as red teaming co-pilots. Launch any supported CLI from a project directory and the AI will understand `dcr`, `target.yaml`, the full tool suite, and the project methodology.

## Supported CLIs

| CLI | Install | Instructions File |
|-----|---------|------------------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `npm i -g @anthropic-ai/claude-code` | `~/.claude/CLAUDE.md` |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | `npm i -g @google/gemini-cli` | `~/.gemini/GEMINI.md` |
| [Codex CLI](https://github.com/openai/codex) | `npm i -g @openai/codex` | `~/.codex/AGENTS.md` |

All three CLIs are pre-installed in the VM with instructions pre-configured.

## Setup

```bash
dcr ai setup        # configure API keys (interactive, one-time)
dcr ai status       # check what's configured
dcr ai install      # (re)install AI instructions globally
dcr ai remove       # remove instructions and saved keys
```

## Usage

```bash
cd ~/projects/acme-chatbot
dcr ai              # auto-detects installed CLI and launches it
dcr ai claude       # launch Claude Code
dcr ai gemini       # launch Gemini CLI
dcr ai codex        # launch Codex CLI
```

## What the AI Co-Pilot Knows

- All 15+ tools and their strengths (HumanBound, Promptfoo, Garak, PyRIT, Giskard, etc.)
- All `dcr` subcommands and flags
- The `target.yaml` schema including the `policy` section
- The 5-phase project methodology
- Regulated environment mode and relay proxy setup
- OWASP LLM Top 10 categories for triaging findings

## The AI's Role

The AI assistant acts as an offensive security specialist focused on AI and LLM red teaming. It helps with:

- Configuring `target.yaml` for new projects
- Choosing the right tools for a given target
- Interpreting scan results and triaging findings
- Writing custom adversarial prompts for PyRIT
- Correlating findings across tools by OWASP category
- Generating reports and remediation recommendations

## Policy-Based Testing

When a `policy` section exists in `target.yaml`, the AI co-pilot uses it to evaluate findings:

- **True violations**: the target did something policy says it must not
- **Acceptable behavior**: the target stayed within policy bounds (dismiss these)
- **Policy gaps**: areas in the policy not covered by any scan

## DCR CLI Reference

```
dcr auth                          Verify target API authentication (run first)
dcr humanbound setup              Generate bot.json from target.yaml
dcr humanbound init               Register with HumanBound cloud
dcr humanbound test [--single|--adaptive|--workflow|--behavioral|--auditor]
dcr humanbound test --level unit|system|acceptance
dcr humanbound test --fail-on critical|high|medium|low|any
dcr humanbound status [--watch]   Check experiment status
dcr humanbound logs [--failed]    View findings (--failed for failures only)
dcr humanbound posture            View security posture score
dcr humanbound guardrails         Export guardrail rules
dcr humanbound full               Complete end-to-end workflow
dcr promptfoo                     Generate Promptfoo config + run red team scan
dcr garak [flags]                 Run Garak probes (flags passed through)
dcr pyrit-single                  Run PyRIT single-turn
dcr pyrit-multi                   Run PyRIT multi-turn
dcr giskard [--only detectors...] Run Giskard vulnerability scan
dcr scan [tool]                   Run all tools in sequence
dcr ai [claude|gemini|codex]      Launch an AI coding assistant
dcr ai setup                      Configure API keys
dcr ai install                    Install AI instructions globally
dcr ai remove                     Remove AI instructions and saved keys
dcr ai status                     Show what's configured
```

### Global Options

```
dcr -d DIR <command>              Use explicit project directory
dcr -v / dcr --version            Show version
dcr -h / dcr --help               Show help
```

---

(c) 2026 Deep Cyber Ltd. All rights reserved.
