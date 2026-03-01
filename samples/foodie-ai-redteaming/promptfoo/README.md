# Promptfoo

Automated red teaming using [Promptfoo](https://www.promptfoo.dev/) — generates adversarial prompts and evaluates the AI's responses against safety criteria.

## Prerequisites

- Node.js 18+ (or use `npx` without installing)
- Python 3.10+ (for the auth helper)

## Setup

1. Install shared dependencies (from repo root):

```bash
pip install -r shared/requirements.txt
```

2. Make sure your `.env` is configured in the repo root.

3. Run the red team scan:

```bash
bash setup.sh
```

4. View results in the browser:

```bash
npx promptfoo@latest view
```

## What it tests

The `promptfooconfig.yaml` includes these attack categories:

| Plugin | Description |
|--------|-------------|
| `prompt-injection` | Direct and indirect prompt injection |
| `hijacking` | Goal/topic hijacking attempts |
| `harmful:*` | Hate speech, violence, sexual content, self-harm |
| `pii:direct/social` | Personal information extraction |
| `excessive-agency` | Attempts to make the AI act beyond its scope |
| `hallucination` | Factual accuracy checks |

Attack strategies: `jailbreak`, `jailbreak:likert`, `prompt-injection`, `crescendo` (multi-turn escalation).

## Customising

Edit `promptfooconfig.yaml` to add or remove plugins, change strategies, or adjust the target description. See the [Promptfoo red team docs](https://www.promptfoo.dev/docs/red-team/) for all options.
