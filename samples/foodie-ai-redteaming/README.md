# Foodie AI — Red Teaming Lab

Black-box adversarial testing samples for the [Foodie AI](https://api.foodie-ai.xyz) chatbot, aligned with the [OWASP Top 10 for LLM Applications](https://owasp.org/www-project-top-10-for-large-language-model-applications/).

Each tool directory contains a ready-to-run integration — pick one and start testing in under 5 minutes.

## Tools

| Tool | Type | Install | What it does |
|------|------|---------|-------------|
| [Promptfoo](promptfoo/) | Automated scan | `npm` / `npx` | Generates adversarial prompts, evaluates responses against safety criteria |
| [Garak](garak/) | Vulnerability scanner | `pip install garak` | Probes for known vulnerability classes (injection, encoding, jailbreaks) |
| [PyRIT](pyrit/) | Attack framework | `pip install pyrit-core` | Single-turn and AI-driven multi-turn attacks |
| [HumanBound](humanbound/) | OWASP test suite | `pip install aiandme` | Full OWASP adversarial testing via AIandMe CLI |

## Prerequisites

- Python 3.10+
- API credentials (username and password) — provided by the lab instructor
- Node.js 18+ (Promptfoo only)
- OpenAI API key (PyRIT multi-turn only)

## Quick start

```bash
# 1. Clone the repo
git clone https://github.com/deepcyber-ai/foodie-ai-redteaming.git
cd foodie-ai-redteaming

# 2. Install shared dependencies
pip install -r shared/requirements.txt

# 3. Configure credentials
cp .env.example .env
# Edit .env with the username and password provided to you

# 4. Verify authentication works
python shared/auth.py

# 5. Pick a tool and follow its README
cd promptfoo && bash setup.sh      # or
cd garak && bash run.sh            # or
cd pyrit && python single_turn.py  # or
cd humanbound && python redteam.py full
```

## API Reference

See [API_REFERENCE.md](API_REFERENCE.md) for full endpoint documentation including authentication, request/response schemas, session management, and examples.

### Key facts

| Property | Value |
|----------|-------|
| Base URL | `https://api.foodie-ai.xyz` |
| Auth | `POST /auth/token` with username/password, then `Bearer <id_token>` |
| Chat | `POST /` with `{"input": "your message"}` |
| Token TTL | 1 hour (refresh via `POST /auth/refresh`) |
| Sessions | Multi-turn via `x-session-id` header, 24-hour TTL |
| Max input | 2000 characters |
| SDK needed | None — plain HTTP/JSON |

## What's tested

| Category | Attack types |
|----------|-------------|
| Prompt injection | Direct injection, indirect injection, system prompt extraction |
| Jailbreaks | DAN, role-play, encoding tricks, crescendo escalation |
| Harmful content | Hate, violence, self-harm, sexual content, illegal activity |
| Data exfiltration | PII extraction, credential harvesting |
| Goal hijacking | Topic drift, instruction override |
| Multi-turn | Context manipulation, gradual escalation, conversational attacks |
| Behavioural | Intent boundary validation, hallucination detection |

## Session isolation

Each tool uses a unique `x-session-id` to keep test conversations separate. Send `clear` to reset a session or `quit` to delete it.

## Credentials

All credentials are loaded from `.env` files (gitignored). Never commit passwords or tokens to this repo.
