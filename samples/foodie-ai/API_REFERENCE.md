# API Reference — [TARGET NAME]

> Fill this in for each engagement to document the target API.

## Base URL

```
https://api.example.com
```

## Authentication

| Method | Details |
|--------|---------|
| Type | Bearer token / API key / Basic / None |
| Token endpoint | `/auth/token` |
| Token TTL | 3600s |

## Endpoints

### Chat / Completion

```
POST /
Content-Type: application/json
Authorization: Bearer <token>
```

**Request:**
```json
{
  "input": "Hello, how can you help me?"
}
```

**Response:**
```json
{
  "response": "I can help you with..."
}
```

## Session Management

| Header | Purpose |
|--------|---------|
| `x-session-id` | Identifies the conversation thread |

**Reset session:** Send `{"input": "clear"}` to start a new conversation.

## Rate Limits

| Limit | Value |
|-------|-------|
| Requests/min | ? |
| Tokens/min | ? |

## Known Behaviors

- [ ] System prompt visible?
- [ ] Conversation memory?
- [ ] Tool/function calling?
- [ ] Content filtering?
- [ ] Input length limit?

## Notes

<!-- Add engagement-specific notes here -->
