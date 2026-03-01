# Garak

Vulnerability scanning using [Garak](https://github.com/NVIDIA/garak) (NVIDIA) — probes the AI for known vulnerability classes including prompt injection, encoding attacks, and jailbreaks.

## Prerequisites

- Python 3.10+

## Setup

1. Install Garak and shared dependencies:

```bash
pip install garak
pip install -r ../shared/requirements.txt
```

2. Make sure your `.env` is configured in the repo root.

3. Run a scan:

```bash
bash run.sh
```

## How it works

The `run.sh` script:
1. Reads credentials from the root `.env`
2. Calls `/auth/token` to get a JWT
3. Exports the token as `REST_API_KEY` (Garak's env var for `$KEY` substitution)
4. Runs Garak with the REST generator config in `foodie_garak.json`

## Running specific probes

```bash
# Encoding-based attacks
bash run.sh -p encoding

# DAN jailbreak probes
bash run.sh -p dan

# Prompt injection
bash run.sh -p promptinject

# All available probes (long run)
bash run.sh -p all
```

## Configuration

The `foodie_garak.json` file configures the REST generator:
- `$KEY` is replaced with the Bearer token from the `REST_API_KEY` env var
- `$INPUT` is replaced with each probe's attack prompt
- `response_json_field` extracts the `response` field from the API's JSON reply

See the [Garak docs](https://reference.garak.ai/en/latest/garak.generators.rest.html) for all REST generator options.
