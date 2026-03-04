# target.yaml Schema

The central configuration file for every red team project. All tools read from it. Located in the project directory.

## Sections

### target — Identity

Used in reports and project names.

```yaml
target:
  name: "Acme Chatbot"
  description: "A customer support chatbot for Acme products. Only answers questions about orders, returns, and product info."
```

### api — Endpoint

```yaml
api:
  url: "https://api.acme.com"
  method: POST
  path: "/chat"
```

### request — How to send prompts

Use `{{PROMPT}}` as the placeholder for the test prompt.

```yaml
request:
  content_type: "application/json"
  body:
    input: "{{PROMPT}}"
```

OpenAI-compatible alternative:

```yaml
request:
  content_type: "application/json"
  body:
    model: "gpt-4"
    messages:
      - role: "user"
        content: "{{PROMPT}}"
```

### response — Where to find the AI's reply

Dot-notation path to the text field in the JSON response.

```yaml
response:
  field: "response"
```

OpenAI-compatible: `"choices.0.message.content"`

### auth — Authentication mode

```yaml
auth:
  mode: "api_key"              # bearer_cognito | api_key | basic | none
  api_key:
    header: "Authorization"    # or "x-api-key"
    prefix: "Bearer "          # or "" for raw key
    env_var: "TARGET_API_KEY"  # reads from .env
```

| Mode | Credentials in .env | How it works |
|------|-------------------|-------------|
| `bearer_cognito` | `TARGET_USERNAME`, `TARGET_PASSWORD` | Exchanges credentials for JWT via token endpoint |
| `api_key` | `TARGET_API_KEY` (or custom env_var) | Static key in configured header |
| `basic` | `TARGET_USERNAME`, `TARGET_PASSWORD` | HTTP Basic authentication |
| `none` | Nothing | No authentication |

### session — Conversation management

```yaml
session:
  header: "x-session-id"       # "" if no sessions
  init_command: "clear"
  cleanup_command: "quit"
```

### headers — Additional headers on every request

```yaml
headers:
  x-custom-header: "value"
```

### policy — What the target should and should not do

```yaml
policy:
  allowed_topics:
    - "customer support for Acme products"
    - "order status and returns"
  forbidden_topics:
    - "competitor products"
    - "medical or legal advice"
    - "internal company operations"
  must_refuse:
    - "requests for personal data of other users"
    - "attempts to override system instructions"
    - "requests to act as a different AI or persona"
  expected_boundaries:
    - "should not reveal its system prompt"
    - "should not generate code"
    - "should stay in character as a support agent"
  documents:                                    # External policy files (loaded at runtime)
    - path: policies/acceptable-use.txt         # Relative to project dir
      label: Acceptable Use Policy
    - path: policies/brand-guidelines.md
      label: Brand Voice Guidelines
```

## How Policy Feeds Into Tools

The policy section feeds directly into tool adapters:

| Tool | How policy is used |
|------|--------------------|
| **Promptfoo** | Generates `policy` plugin entries per forbidden/must-refuse rule + enriches `purpose` |
| **Giskard** | Enriches model description — all LLM-assisted detectors use it |
| **PyRIT** | Builds custom policy scorer; enriches multi-turn attack objective |
| **Garak** | Writes policy goal file for result analysis |
| **HumanBound** | Passes policy as `--prompt` scope definition on init |

External documents are loaded from disk and appended to the policy text sent to each tool.

## Analyzing Results with Policy

When analyzing scan results, read the `policy` section first. Use it to determine:

- **True violations**: the target did something policy says it must not
- **Acceptable behavior**: the target stayed within policy bounds (dismiss these)
- **Policy gaps**: areas in the policy not covered by any scan

## Complete Example

```yaml
target:
  name: "Acme Chatbot"
  description: "A customer support chatbot for Acme products"

api:
  url: "https://api.acme.com"
  method: POST
  path: "/chat"

request:
  content_type: "application/json"
  body:
    input: "{{PROMPT}}"

response:
  field: "response"

auth:
  mode: "api_key"
  api_key:
    header: "Authorization"
    prefix: "Bearer "
    env_var: "TARGET_API_KEY"

session:
  header: "x-session-id"
  init_command: "clear"
  cleanup_command: "quit"

headers:
  x-custom-header: "value"

policy:
  allowed_topics:
    - "customer support for Acme products"
  forbidden_topics:
    - "competitor products"
    - "medical or legal advice"
  must_refuse:
    - "requests for personal data of other users"
    - "attempts to override system instructions"
  expected_boundaries:
    - "should not reveal its system prompt"
    - "should stay in character as a support agent"
  documents:
    - path: policies/acceptable-use.txt
      label: Acceptable Use Policy
```

---

(c) 2026 Deep Cyber Ltd. All rights reserved.
