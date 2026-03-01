# Foodie AI API Reference

API reference for integrating with the Foodie AI chatbot. No AWS SDK required — plain HTTP/JSON.

## Base URL

```
https://api.foodie-ai.xyz
```

### Endpoints

| Method | Path             | Auth Required | Description                    |
|--------|------------------|---------------|--------------------------------|
| POST   | `/auth/token`    | No            | Get tokens (username/password) |
| POST   | `/auth/refresh`  | No            | Refresh an expired ID token    |
| POST   | `/`              | Yes           | Send a message to the AI       |

## Authentication

Obtain tokens via `/auth/token`, then pass them as `Authorization: Bearer <id_token>` on chat requests.

### POST `/auth/token` — Login

**Request:**

```json
{
  "username": "your-username",
  "password": "your-password"
}
```

**Success Response (200):**

```json
{
  "id_token": "eyJraWQ...",
  "refresh_token": "eyJjdH...",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

**Errors:**

| Status | Body                                    | Cause                     |
|--------|-----------------------------------------|---------------------------|
| `400`  | `username and password are required`    | Missing fields            |
| `401`  | `Invalid username or password`          | Bad credentials           |
| `403`  | `Password change required`              | Temporary password        |
| `500`  | `Authentication service error`          | Internal failure          |

### POST `/auth/refresh` — Refresh Token

**Request:**

```json
{
  "refresh_token": "eyJjdH..."
}
```

**Success Response (200):**

```json
{
  "id_token": "eyJraWQ...",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

Note: Keep using the original refresh token — the API does not return a new one on refresh.

**Errors:**

| Status | Body                                    | Cause                     |
|--------|-----------------------------------------|---------------------------|
| `400`  | `refresh_token is required`             | Missing field             |
| `401`  | `Invalid or expired refresh token`      | Bad/expired token         |
| `500`  | `Authentication service error`          | Internal failure          |

### Token Lifecycle

| Property         | Value       |
|------------------|-------------|
| ID token TTL     | **1 hour**  |
| Refresh token TTL| **30 days** |

## Chat Endpoint

### POST `/` — Send a Message

### Headers

| Header          | Required | Description                                            |
|-----------------|----------|--------------------------------------------------------|
| `Authorization` | Yes      | `Bearer <id_token>` from `/auth/token`                 |
| `Content-Type`  | Yes      | `application/json`                                     |
| `x-session-id`  | No       | Session name for conversation continuity (see below)   |

### Body

```json
{
  "input": "Your message to the AI"
}
```

| Field   | Type   | Required | Constraints            |
|---------|--------|----------|------------------------|
| `input` | string | Yes      | 1-2000 characters      |

### Special Commands

| Command          | Effect                                          |
|------------------|-------------------------------------------------|
| `clear`          | Clears conversation history, keeps the session  |
| `quit` or `exit` | Ends the session and deletes all history         |

### Success Response (200)

```json
{
  "response": "AI-generated reply text",
  "session_id": "abc123#default"
}
```

### Error Responses

| Status | Cause                                             |
|--------|---------------------------------------------------|
| `400`  | Missing/empty input, input too long, invalid JSON |
| `401`  | Missing, invalid, or expired token                |
| `409`  | Session modified concurrently — retry the request |
| `500`  | Internal server error                             |

## Session Management

Sessions maintain conversation history so the AI remembers prior context.

1. **First request** — omit `x-session-id` (defaults to `"default"`) or send a custom name (e.g., `"my-test"`).
2. **Subsequent requests** — pass the returned `session_id` back in `x-session-id` to continue the conversation.
3. Sessions are scoped per user — different credentials get independent sessions.

### Session Properties

| Property              | Value                                     |
|-----------------------|-------------------------------------------|
| Session TTL           | **24 hours** from last write              |
| Concurrent sessions   | Unlimited — use different session names   |
| Concurrency control   | Optimistic locking (409 on conflict)      |

## Examples

### Python

```python
import requests

API_URL = "https://api.foodie-ai.xyz"

# 1. Login
auth = requests.post(f"{API_URL}/auth/token", json={
    "username": "your-user",
    "password": "your-pass",
}).json()
token = auth["id_token"]

headers = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {token}",
}

# 2. Send a message
r = requests.post(API_URL, json={"input": "Hello!"}, headers=headers)
data = r.json()
print(data["response"])
session_id = data["session_id"]

# 3. Continue the conversation
headers["x-session-id"] = session_id
r = requests.post(API_URL, json={"input": "What did I just say?"}, headers=headers)
print(r.json()["response"])

# 4. Refresh token (after ~1 hour)
new_auth = requests.post(f"{API_URL}/auth/refresh", json={
    "refresh_token": auth["refresh_token"],
}).json()
headers["Authorization"] = f"Bearer {new_auth['id_token']}"

# 5. Clean up
requests.post(API_URL, json={"input": "quit"}, headers=headers)
```

### cURL

```bash
# Login
AUTH=$(curl -s -X POST https://api.foodie-ai.xyz/auth/token \
  -H "Content-Type: application/json" \
  -d '{"username": "your-user", "password": "your-pass"}')
TOKEN=$(echo "$AUTH" | jq -r '.id_token')

# Send a message
curl -s -X POST https://api.foodie-ai.xyz \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"input": "Suggest a quick pasta recipe"}' | jq .
```

## Red-Teaming Notes

| Property         | Value                                 |
|------------------|---------------------------------------|
| Protocol         | HTTPS                                 |
| Auth             | Bearer token via `POST /auth/token`   |
| Max input length | 2000 characters                       |
| Rate limiting    | None (currently)                      |
| Multi-turn       | Yes, via `x-session-id`               |
| SDK required     | None — plain HTTP/JSON                |

### Tips

- **Isolate test runs** — use a unique `x-session-id` per test scenario to prevent conversation bleed.
- **Clean up** — send `quit` after each test run to delete session data.
- **Token refresh** — ID tokens expire after 1 hour. Call `POST /auth/refresh` for long suites.
- **Single-turn tests** — omit `x-session-id` or send `clear` first.
- **Multi-turn attacks** — use a consistent `x-session-id` across the attack chain so the AI accumulates context.
