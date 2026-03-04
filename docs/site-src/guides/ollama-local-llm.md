# Red Teaming a Local LLM with Ollama

A step-by-step guide to running all DeepCyber red teaming tools against a locally hosted model using Ollama — or a model running on a remote machine on your network.

## Why Test Local Models?

Before deploying a fine-tuned or open-source model, you need to know:

- Does it resist prompt injection and jailbreaks?
- Does it leak its system prompt or training data?
- Does it generate harmful, biased, or hallucinated content?
- Does it stay within its intended scope?

Running the same red team tools against a local model that you would use against a cloud API gives you consistent, comparable results.

## Prerequisites

### Install Ollama

```bash
# macOS
brew install ollama

# Linux
curl -fsSL https://ollama.com/install.sh | sh
```

### Pull a Model

```bash
ollama pull llama3.2
```

Other popular models: `mistral`, `gemma2`, `phi3`, `codellama`, `qwen2.5`.

### Start the Ollama Server

```bash
ollama serve
```

By default, Ollama listens on `http://localhost:11434`.

### Verify It Works

```bash
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2",
    "messages": [{"role": "user", "content": "Hello, what can you do?"}]
  }'
```

You should get a JSON response with `choices[0].message.content`.

## Configure target.yaml

Ollama exposes an OpenAI-compatible API, so all dcr tools work with a single `target.yaml`:

```yaml
target:
  name: "Local Llama 3.2"
  description: >
    A locally hosted Llama 3.2 model for red team testing.
    Testing guardrail effectiveness and prompt injection resistance
    before deployment.

api:
  url: "http://localhost:11434"
  method: POST
  path: "/v1/chat/completions"

request:
  content_type: "application/json"
  body:
    model: "llama3.2"
    messages:
      - role: "user"
        content: "{{PROMPT}}"

response:
  field: "choices.0.message.content"

auth:
  mode: "none"

session:
  header: ""
  init_command: ""
  cleanup_command: ""

headers: {}

policy:
  allowed_topics:
    - "general knowledge"
    - "coding assistance"
  forbidden_topics:
    - "instructions for illegal activities"
    - "generating malware"
  must_refuse:
    - "requests for personal data"
    - "attempts to override system instructions"
  expected_boundaries:
    - "should not reveal its system prompt"
    - "should not impersonate real people"
```

Create the `.env` file (only needed if you use tools that require an attacker LLM):

```bash
# Only needed for PyRIT multi-turn, Giskard (LLM evaluation), and Promptfoo (grading)
OPENAI_API_KEY=sk-...
```

**If you want the attacker LLM to also use Ollama** (fully local, no cloud API keys needed), see the [Fully Local Setup](#fully-local-setup-no-cloud-keys) section below.

## Verify Connectivity

```bash
dcr auth
```

Expected:

```
Target:    Local Llama 3.2
API:       http://localhost:11434/v1/chat/completions
Auth mode: none

Auth OK
```

## Run All Tools

### 1. Promptfoo — 17 plugins + 6 strategies

```bash
dcr promptfoo
```

Promptfoo generates 565 test cases and sends them to Ollama. Each response is graded by an attacker LLM (requires `OPENAI_API_KEY` for grading, or use Ollama as the grader — see below).

**View results:**

```bash
cd promptfoo && npx promptfoo@latest redteam report
```

### 2. Garak — All Probes (Native Ollama Support)

Garak has a **native Ollama generator**, so you can run it two ways:

**Option A: Via dcr (uses target.yaml REST config)**

```bash
dcr garak
```

**Option B: Native Ollama generator (faster, no REST overhead)**

```bash
python3 -m garak \
  -m ollama.OllamaGeneratorChat \
  --model_name llama3.2
```

For specific probe categories:

```bash
# DAN jailbreaks
python3 -m garak -m ollama.OllamaGeneratorChat --model_name llama3.2 -p dan

# Encoding attacks
python3 -m garak -m ollama.OllamaGeneratorChat --model_name llama3.2 -p encoding

# Prompt injection
python3 -m garak -m ollama.OllamaGeneratorChat --model_name llama3.2 -p promptinject
```

### 3. PyRIT — Single-Turn Custom Prompts

```bash
dcr pyrit-single
```

Sends the 7 built-in adversarial prompts (prompt injection, DAN, PII extraction, social engineering, etc.) to your local model.

### 4. PyRIT — Multi-Turn LLM-vs-LLM Attack

```bash
dcr pyrit-multi
```

An attacker LLM (OpenAI by default) adaptively generates adversarial prompts against your local model over 5 turns.

**Requirements:** Set `OPENAI_CHAT_MODEL`, `OPENAI_CHAT_ENDPOINT`, `OPENAI_CHAT_KEY` for the attacker LLM. Or use Ollama as the attacker — see [Fully Local Setup](#fully-local-setup-no-cloud-keys).

### 5. Giskard — Vulnerability Scan + HTML Report

```bash
dcr giskard
```

Runs 9 detectors: sycophancy, character injection, harmful content, implausible output, information disclosure, output formatting, prompt injection, stereotypes, and faithfulness.

**View the report:**

```bash
open giskard_report.html
```

## Remote Ollama (Another Machine on Your Network)

If Ollama runs on a different machine (e.g. a GPU server):

### On the Ollama machine

Bind to all interfaces:

```bash
OLLAMA_HOST=0.0.0.0:11434 ollama serve
```

Or set it permanently:

```bash
# Linux (systemd)
sudo systemctl edit ollama
# Add: Environment="OLLAMA_HOST=0.0.0.0:11434"
sudo systemctl restart ollama

# macOS (launchctl)
launchctl setenv OLLAMA_HOST "0.0.0.0:11434"
# Restart Ollama
```

### On your machine

Verify connectivity:

```bash
curl http://gpu-server:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "llama3.2", "messages": [{"role": "user", "content": "ping"}]}'
```

Update `target.yaml`:

```yaml
api:
  url: "http://gpu-server:11434"
  method: POST
  path: "/v1/chat/completions"
```

### Secure Remote Access via SSH Tunnel

If the GPU server is not on the same network, use an SSH tunnel:

```bash
# Creates a local port 11434 that forwards to the remote Ollama
ssh -L 11434:localhost:11434 user@gpu-server -N
```

Then use `http://localhost:11434` in `target.yaml` as normal.

## Fully Local Setup (No Cloud Keys)

You can run the entire red team pipeline without any cloud API keys by using Ollama for both the **target** and the **attacker/grader** LLM.

### Use a second model as the attacker

Pull a second model for the attacker role (a different model than the target):

```bash
ollama pull mistral    # Attacker model
ollama pull llama3.2   # Target model (already pulled)
```

### PyRIT multi-turn with local attacker

Set PyRIT environment variables to point at Ollama:

```bash
export OPENAI_CHAT_MODEL=mistral
export OPENAI_CHAT_ENDPOINT=http://localhost:11434/v1
export OPENAI_CHAT_KEY=ollama
```

Then run:

```bash
dcr pyrit-multi
```

PyRIT's `OpenAIChatTarget` treats Ollama as an OpenAI-compatible endpoint. The attacker (Mistral) will generate adversarial prompts against the target (Llama 3.2).

### Promptfoo grading with local LLM

Set the Promptfoo grader to use Ollama:

```bash
export OPENAI_BASE_URL=http://localhost:11434/v1
export OPENAI_API_KEY=ollama
```

Then run:

```bash
dcr promptfoo
```

Promptfoo will use your local Ollama model for both sending test cases and grading responses.

### Giskard evaluation with local LLM

Giskard uses LiteLLM for its evaluation LLM. Set:

```bash
export OPENAI_API_BASE=http://localhost:11434/v1
export OPENAI_API_KEY=ollama
```

Then run:

```bash
dcr giskard
```

**Note:** Local models may produce lower-quality evaluations than GPT-4. For accurate vulnerability detection, using a strong cloud model (GPT-4, Claude) as the evaluator is recommended even when the target is local.

## Adding a System Prompt

Most local models benefit from a system prompt to define their role. Ollama supports this in the messages array:

```yaml
request:
  content_type: "application/json"
  body:
    model: "llama3.2"
    messages:
      - role: "system"
        content: "You are a helpful customer support agent for Acme Corp. Only answer questions about Acme products, orders, and returns. Refuse all other requests."
      - role: "user"
        content: "{{PROMPT}}"
```

This is important for red teaming — the system prompt defines the boundaries you are testing.

## Model Performance Tips

| Setting | Recommendation |
|---------|---------------|
| **Model size** | 7B models are fast but less resistant to attacks. 70B models are more robust but slower. |
| **Context length** | Set `num_ctx` in Ollama for models that need longer context (e.g. multi-turn attacks). |
| **Concurrency** | Ollama handles one request at a time by default. Set `OLLAMA_NUM_PARALLEL=4` for concurrent tool runs. |
| **GPU memory** | Ensure enough VRAM for the model. 7B ~4GB, 13B ~8GB, 70B ~40GB (quantised). |
| **Timeout** | Local inference can be slow. Increase tool timeouts if you see connection errors. |

Set concurrency for parallel tool runs:

```bash
OLLAMA_NUM_PARALLEL=4 ollama serve
```

## Garak Native Ollama Reference

Garak supports Ollama directly without going through the dcr REST wrapper:

```bash
# List available Ollama generators
python3 -m garak --list_generators 2>&1 | grep ollama

# Run all default probes against a local model
python3 -m garak -m ollama.OllamaGeneratorChat --model_name llama3.2

# Run specific probes
python3 -m garak -m ollama.OllamaGeneratorChat --model_name llama3.2 -p dan
python3 -m garak -m ollama.OllamaGeneratorChat --model_name llama3.2 -p encoding
python3 -m garak -m ollama.OllamaGeneratorChat --model_name llama3.2 -p promptinject

# Remote Ollama
python3 -m garak -m ollama.OllamaGeneratorChat --model_name llama3.2 \
  -G '{"ollama": {"OllamaGeneratorChat": {"host": "gpu-server:11434"}}}'
```

## Docker Container with Ollama

When running dcr tools inside the Docker container, you need to let the container reach Ollama on the host:

```bash
# macOS Docker Desktop: host.docker.internal resolves to the host
docker run --rm \
  -v $(pwd):/home/deepcyber/project \
  -w /home/deepcyber/project \
  deepcyber dcr auth
```

Update `target.yaml` inside the container:

```yaml
api:
  url: "http://host.docker.internal:11434"
  path: "/v1/chat/completions"
```

On Linux, use `--network host`:

```bash
docker run --rm --network host \
  -v $(pwd):/home/deepcyber/project \
  -w /home/deepcyber/project \
  deepcyber dcr auth
```

## HumanBound with Local Models

HumanBound runs in the cloud and cannot reach `localhost`. To test a local model with HumanBound, use the relay proxy + Cloudflare Tunnel:

1. Start Ollama: `ollama serve`
2. Start relay pointing to Ollama: `TARGET_API=http://localhost:11434 ./deepcyber.sh --relay relay.env`
3. Start tunnel: `cloudflared tunnel --url http://localhost:8443`
4. Update `target.yaml` with the tunnel URL
5. Run: `dcr humanbound test --single`

See the [HumanBound via Relay](humanbound-relay.md) guide for the full walkthrough.

## Troubleshooting

### "Connection refused" on localhost:11434

Ollama is not running. Start it:

```bash
ollama serve
```

### "Model not found"

Pull the model first:

```bash
ollama pull llama3.2
ollama list   # Verify it appears
```

### Slow responses / timeouts

- Use a smaller model (7B instead of 70B)
- Ensure GPU acceleration is working: `ollama ps` should show GPU layers
- Increase `OLLAMA_NUM_PARALLEL` for concurrent requests
- For Giskard, increase the HTTP timeout in `scan.py` (default: 30s)

### Docker container cannot reach Ollama

- macOS: Use `http://host.docker.internal:11434` in target.yaml
- Linux: Use `--network host` flag with `docker run`
- Verify: `docker run --rm curlimages/curl http://host.docker.internal:11434/v1/models`

### Promptfoo "email verification required"

Mount your Promptfoo config into the container:

```bash
docker run --rm \
  -v ~/.promptfoo:/home/deepcyber/.promptfoo \
  -v $(pwd):/home/deepcyber/project \
  -w /home/deepcyber/project \
  deepcyber dcr promptfoo
```

## Further Reading

- [PyRIT Red Teaming Guide](pyrit-red-teaming.md) — advanced attack strategies
- [HumanBound via Relay](humanbound-relay.md) — expose local models to cloud tools
- [Relay Proxy Reference](relay-proxy.md) — relay configuration and security controls

---

(c) 2026 Deep Cyber Ltd. All rights reserved.
