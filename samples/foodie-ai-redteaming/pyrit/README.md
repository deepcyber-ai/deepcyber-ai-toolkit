# PyRIT

Red teaming using [PyRIT](https://github.com/Azure/PyRIT) (Microsoft) — supports both single-turn prompt injection testing and multi-turn AI-driven attacks.

## Prerequisites

- Python 3.10+
- OpenAI API key (for multi-turn attacks only)

## Setup

1. Install dependencies:

```bash
pip install -r requirements.txt
```

2. Make sure your `.env` is configured in the repo root.

## Single-turn attacks

Sends a set of adversarial prompts and collects responses. No attacker LLM needed.

```bash
python single_turn.py
```

Edit the `TEST_PROMPTS` list in `single_turn.py` to add your own attack prompts.

## Multi-turn attacks

Uses an OpenAI model as the "attacker" that generates a sequence of prompts, adapting based on the target's responses to try to achieve a specific objective.

```bash
export OPENAI_API_KEY=sk-...
python multi_turn.py
```

Edit `OBJECTIVE` and `MAX_TURNS` in `multi_turn.py` to change the attack goal and depth.

## How it works

Both scripts:
1. Call `/auth/token` to get a JWT (via `shared/auth.py`)
2. Build a raw HTTP request template with the `{prompt}` placeholder
3. Create an `HTTPTarget` that sends requests to the Foodie AI API
4. Use a PyRIT orchestrator to manage the attack flow
5. Clean up the session with `quit` when done

The `x-session-id` header is set per-script (`pyrit-single-turn`, `pyrit-multi-turn`) to isolate conversations.

## References

- [PyRIT documentation](https://azure.github.io/PyRIT/)
- [HTTPTarget guide](https://azure.github.io/PyRIT/code/targets/0_prompt_targets.html)
- [Red teaming orchestrators](https://azure.github.io/PyRIT/code/orchestrators/)
