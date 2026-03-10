# Output Schema Reference

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `goal` | string | Verb-first, present tense. What the skill does. |
| `steps` | array | Minimum 1 step. Each step is atomic. |
| `steps[].order` | integer | Starting at 1, sequential |
| `steps[].action` | string | One sentence describing this step |
| `steps[].tool_type` | string | One of: api, mcp, cli, db, file, browser, llm, data-pipeline, notification, cron, auth, infra, custom |
| `steps[].details` | string | Specific tool, endpoint, command, or model |
| `env_vars_needed` | array | Objects with `name` (SCREAMING_SNAKE_CASE) and `description` |
| `tools_needed` | array | Service/tool names (e.g., "QuickBooks API", "PostgreSQL") |
| `search_query` | string | 2-5 keywords for ClawHub/skills.sh |
| `skill_name_suggestion` | string | kebab-case, lowercase, must match `^[a-z][a-z0-9-]*$` |
| `category` | string | One of: automation, integration, data, communication, devops, ai, finance, project-management, custom |

## Validation Rules

- `goal` must not be empty
- `steps` must have at least 1 item
- `tool_type` must be a recognized type (or `custom`)
- `skill_name_suggestion` must be valid kebab-case
- `env_vars_needed[].name` must be SCREAMING_SNAKE_CASE

## Examples by Domain

### API Integration (finance)
```json
{
  "goal": "Pay verified invoices from QuickBooks automatically",
  "steps": [
    { "order": 1, "action": "Fetch new invoices from QuickBooks API", "tool_type": "api", "details": "GET /v3/company/{id}/query — filter last 24h" },
    { "order": 2, "action": "Verify each invoice against goods receipt database", "tool_type": "db", "details": "SELECT verified FROM receipts WHERE invoice_id = ?" },
    { "order": 3, "action": "Pay verified invoices via crypto wallet", "tool_type": "api", "details": "Wallet API transfer endpoint" },
    { "order": 4, "action": "Send payment summary to Telegram", "tool_type": "notification", "details": "Telegram Bot API sendMessage" }
  ],
  "env_vars_needed": [
    { "name": "QB_API_KEY", "description": "QuickBooks API key" },
    { "name": "RECEIPT_DB_URL", "description": "PostgreSQL connection string for receipts" },
    { "name": "WALLET_PRIVATE_KEY", "description": "Crypto wallet private key" }
  ],
  "tools_needed": ["QuickBooks API", "PostgreSQL", "Crypto Wallet API"],
  "search_query": "quickbooks invoice payment automation",
  "skill_name_suggestion": "invoice-auto-payment",
  "category": "finance"
}
```

### LLM Pipeline (ai)
```json
{
  "goal": "Classify incoming support tickets and route to the correct team",
  "steps": [
    { "order": 1, "action": "Fetch unclassified tickets from Zendesk API", "tool_type": "api", "details": "GET /api/v2/search — status:new" },
    { "order": 2, "action": "Classify each ticket using LLM", "tool_type": "llm", "details": "Prompt: categorize into billing/technical/feature-request/other" },
    { "order": 3, "action": "Assign ticket to team based on classification", "tool_type": "api", "details": "PUT /api/v2/tickets/{id} — update group_id" },
    { "order": 4, "action": "Log classification results to file", "tool_type": "file", "details": "Append to classifications.jsonl" }
  ],
  "env_vars_needed": [
    { "name": "ZENDESK_API_TOKEN", "description": "Zendesk API token" },
    { "name": "OPENAI_API_KEY", "description": "OpenAI API key for classification" }
  ],
  "tools_needed": ["Zendesk API", "OpenAI API"],
  "search_query": "llm ticket classification routing zendesk",
  "skill_name_suggestion": "ticket-classifier",
  "category": "ai"
}
```

### Data Pipeline (data)
```json
{
  "goal": "Parse CSV uploads, validate rows, and insert into PostgreSQL",
  "steps": [
    { "order": 1, "action": "Read CSV file from uploads directory", "tool_type": "file", "details": "Read /data/uploads/*.csv" },
    { "order": 2, "action": "Validate each row against schema", "tool_type": "data-pipeline", "details": "Check required fields, types, ranges" },
    { "order": 3, "action": "Insert valid rows into PostgreSQL", "tool_type": "db", "details": "INSERT INTO target_table using COPY" },
    { "order": 4, "action": "Report: N rows processed, N valid, N rejected", "tool_type": "notification", "details": "Telegram message with summary" }
  ],
  "env_vars_needed": [
    { "name": "DB_CONNECTION_STRING", "description": "PostgreSQL connection URI" },
    { "name": "UPLOAD_DIR", "description": "Path to CSV upload directory" }
  ],
  "tools_needed": ["PostgreSQL", "CSV parser"],
  "search_query": "csv postgres import validation pipeline",
  "skill_name_suggestion": "csv-to-postgres",
  "category": "data"
}
```

### CLI Automation (devops)
```json
{
  "goal": "Run test suite on push and report failures to Slack",
  "steps": [
    { "order": 1, "action": "Pull latest code from git repository", "tool_type": "cli", "details": "git pull origin main" },
    { "order": 2, "action": "Run npm test suite", "tool_type": "cli", "details": "npm test --ci 2>&1" },
    { "order": 3, "action": "Parse test results for failures", "tool_type": "data-pipeline", "details": "Extract failed test names from output" },
    { "order": 4, "action": "Post results to Slack channel", "tool_type": "notification", "details": "Slack webhook with test summary" }
  ],
  "env_vars_needed": [
    { "name": "SLACK_WEBHOOK_URL", "description": "Slack incoming webhook URL" },
    { "name": "REPO_PATH", "description": "Local path to git repository" }
  ],
  "tools_needed": ["git", "npm", "Slack Webhook"],
  "search_query": "test runner slack notification ci",
  "skill_name_suggestion": "test-reporter",
  "category": "devops"
}
```

### Multi-Tool (integration)
```json
{
  "goal": "Summarize daily Jira comments and send email digest",
  "steps": [
    { "order": 1, "action": "Fetch all Jira comments from today", "tool_type": "mcp", "details": "Jira MCP — search comments updated today" },
    { "order": 2, "action": "Summarize comments using LLM", "tool_type": "llm", "details": "Prompt: summarize key updates, decisions, blockers" },
    { "order": 3, "action": "Format as HTML email", "tool_type": "data-pipeline", "details": "Markdown to HTML conversion" },
    { "order": 4, "action": "Send digest email", "tool_type": "notification", "details": "SMTP email to team distribution list" }
  ],
  "env_vars_needed": [
    { "name": "JIRA_API_TOKEN", "description": "Jira API token" },
    { "name": "JIRA_BASE_URL", "description": "Jira instance URL" },
    { "name": "SMTP_HOST", "description": "Email server host" },
    { "name": "SMTP_USER", "description": "Email sender address" },
    { "name": "SMTP_PASS", "description": "Email server password" }
  ],
  "tools_needed": ["Jira API", "OpenAI API", "SMTP"],
  "search_query": "jira daily summary email digest",
  "skill_name_suggestion": "jira-daily-digest",
  "category": "integration"
}
```
