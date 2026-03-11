# Credential Validation Patterns

How to test-validate common credentials after the user provides them.
These are lightweight checks — not full integration tests.

## API Tokens

### Jira
```
Test: GET {JIRA_BASE_URL}/rest/api/3/myself
Headers: Authorization: Basic base64({JIRA_USER}:{JIRA_API_TOKEN})
Success: 200 OK with user profile JSON
Failure: 401 (bad token), 403 (no permissions), DNS error (bad URL)
```

### GitHub
```
Test: GET https://api.github.com/user
Headers: Authorization: Bearer {GITHUB_TOKEN}
Success: 200 OK with login field
Failure: 401 (bad/expired token)
Note: Check X-OAuth-Scopes header for required permissions
```

### GitLab
```
Test: GET {GITLAB_URL}/api/v4/user
Headers: PRIVATE-TOKEN: {GITLAB_TOKEN}
Success: 200 OK with username field
Failure: 401 (bad token)
```

### OpenAI
```
Test: GET https://api.openai.com/v1/models
Headers: Authorization: Bearer {OPENAI_API_KEY}
Success: 200 OK with model list
Failure: 401 (invalid key), 429 (rate limited but key works)
```

### Anthropic
```
Test: POST https://api.anthropic.com/v1/messages
Headers: x-api-key: {ANTHROPIC_API_KEY}, anthropic-version: 2023-06-01
Body: {"model":"claude-3-haiku-20240307","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}
Success: 200 OK
Failure: 401 (invalid key)
```

### Slack Webhook
```
Test: POST {SLACK_WEBHOOK_URL}
Body: {"text": "🔧 OpenClaw agent-setup: webhook test (you can ignore this)"}
Success: 200 OK, "ok" response
Failure: 403/404 (invalid URL), 410 (revoked)
Note: This SENDS a message — ask user permission first
```

### Telegram Bot
```
Test: GET https://api.telegram.org/bot{BOT_TOKEN}/getMe
Success: 200 OK with bot username
Failure: 401 (invalid token)
```

### Zendesk
```
Test: GET {ZENDESK_URL}/api/v2/users/me
Headers: Authorization: Bearer {ZENDESK_API_TOKEN}
Success: 200 OK with user object
Failure: 401 (bad token)
```

### Stripe
```
Test: GET https://api.stripe.com/v1/balance
Headers: Authorization: Bearer {STRIPE_SECRET_KEY}
Success: 200 OK with balance object
Failure: 401 (invalid key)
Note: Check if key starts with sk_test_ or sk_live_
```

## Database URLs

### PostgreSQL
```
Test: psql "{DB_URL}" -c "SELECT 1"
Success: Returns 1 row
Failure: Connection refused, auth failed, database not found
Fallback: Try parsing URL components and test TCP connection to host:port
```

### MongoDB
```
Test: mongosh "{MONGO_URL}" --eval "db.runCommand({ping:1})"
Success: { ok: 1 }
Failure: Connection timeout, auth error
```

### Redis
```
Test: redis-cli -u "{REDIS_URL}" ping
Success: PONG
Failure: Connection refused, auth error
```

## Email/SMTP

### SMTP Server
```
Test: Attempt STARTTLS connection to {SMTP_HOST}:{SMTP_PORT}
Use: openssl s_client -starttls smtp -connect {SMTP_HOST}:{SMTP_PORT}
Success: 220 greeting + TLS negotiation
Failure: Connection refused, TLS error
Note: Don't send actual email during validation
```

## Webhooks

### Generic Webhook URL
```
Test: HEAD {WEBHOOK_URL} or OPTIONS {WEBHOOK_URL}
Success: Any 2xx response
Failure: 4xx/5xx or DNS error
Note: Not all webhooks respond to HEAD/OPTIONS — may need to try POST
```

## Cloud Services

### AWS
```
Test: aws sts get-caller-identity
Env: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
Success: Returns account ID and ARN
Failure: InvalidClientTokenId, SignatureDoesNotMatch
```

### GCP
```
Test: gcloud auth print-access-token
Or: curl -H "Authorization: Bearer {TOKEN}" https://www.googleapis.com/oauth2/v1/tokeninfo
Success: Returns token info
Failure: Invalid credentials
```

## Validation Rules

1. **Always ask before sending test messages** (Slack, Telegram, email)
2. **Timeout**: Max 10 seconds per validation attempt
3. **Rate limiting**: If validation returns 429, the key works — report as valid
4. **Test vs Production**: Note if a key appears to be test-mode (e.g., Stripe sk_test_)
5. **Don't store validation results** in git — only report to user
6. **If validation command not available** (e.g., psql not installed): skip, mark as unverified
7. **If no validation pattern exists** for a service: skip, mark as unverified
