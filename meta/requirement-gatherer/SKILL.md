---
name: requirement-gatherer
description: >
  Convert any user requirement into a structured skill specification.
  Always trigger FIRST when a user gives any new task, requirement,
  workflow request, or says "I want to automate X", "/skill",
  "create a skill for", "make a skill that", "new requirement",
  "automate this", "I need a skill". This is the entry point for
  all new skill work. NOT for project-level requirements (use /pm).
metadata: {"openclaw": {"requires": {"env": []}, "emoji": "📋"}}
---

# Requirement Gatherer

## Purpose

Entry point for all new skill creation. Convert plain English into a structured JSON spec that skill-creator can use to search for or generate a SKILL.md.

## Steps

### Step 1: Extract Goal

What is the end outcome the user wants?
One sentence, present tense, starting with a verb.

Examples:
- "Pay verified invoices from QuickBooks automatically"
- "Summarize daily Jira comments and email a digest"
- "Parse CSV uploads, validate rows, and insert into PostgreSQL"
- "Classify support tickets using LLM and route to the right team"
- "Monitor server health and alert on Slack when a service goes down"

### Step 2: Break Into Steps

What must happen, in order, to achieve the goal?
Each step must be atomic (one action only).

For each step, identify the tool type:

| Type | When to Use |
|------|-------------|
| `api` | REST/GraphQL HTTP calls (Jira, Stripe, QuickBooks, webhooks) |
| `mcp` | Model Context Protocol server calls |
| `cli` | Shell commands (git, curl, docker, npm, custom CLIs) |
| `db` | Database queries — SQL or NoSQL |
| `file` | Read/write local files (JSON, CSV, markdown, config) |
| `browser` | Web browser automation (scraping, form fill, screenshots) |
| `llm` | LLM/AI model calls (summarize, classify, generate, extract) |
| `data-pipeline` | ETL / data transformation (parse, transform, load) |
| `notification` | Send alerts (Telegram, Slack, email, SMS, webhook) |
| `cron` | Scheduled/periodic trigger |
| `auth` | Authentication flows (OAuth, token refresh, key rotation) |
| `infra` | Infrastructure operations (deploy, scale, monitor, health check) |
| `custom` | Anything not covered — describe in details field |

Pick the best-fit type. If unclear, use `custom` and describe in details.

### Step 3: Identify ENV Requirements

What credentials, tokens, or config values does each step need?
Name them in SCREAMING_SNAKE_CASE convention.

Examples:
- `JIRA_API_TOKEN` — Jira Personal Access Token
- `QB_API_KEY` — QuickBooks API key
- `OPENAI_API_KEY` — OpenAI API key for LLM calls
- `DB_CONNECTION_STRING` — PostgreSQL connection URI
- `SLACK_WEBHOOK_URL` — Slack incoming webhook

### Step 4: Generate Search Query

Create a short keyword query to search ClawHub and skills.sh.
2-5 keywords that describe the core capability.

Examples:
- "quickbooks invoice payment automation"
- "jira daily summary email"
- "csv postgres import validation"
- "llm ticket classification routing"
- "server health monitoring slack alert"

### Step 5: Output Structured JSON

Output exactly this structure:

```json
{
  "goal": "string — verb-first sentence describing what the skill does",
  "steps": [
    {
      "order": 1,
      "action": "string — one sentence describing this step",
      "tool_type": "api|mcp|cli|db|file|browser|llm|data-pipeline|notification|cron|auth|infra|custom",
      "details": "string — specific tool, endpoint, command, or model to use"
    }
  ],
  "env_vars_needed": [
    { "name": "ENV_VAR_NAME", "description": "what this credential is for" }
  ],
  "tools_needed": ["tool or service name — e.g., QuickBooks API, PostgreSQL, OpenAI"],
  "search_query": "string — 2-5 keywords for ClawHub/skills.sh search",
  "skill_name_suggestion": "kebab-case-name",
  "category": "automation|integration|data|communication|devops|ai|finance|project-management|custom"
}
```

## Rules

- Ask ONE clarifying question if goal is ambiguous — not multiple
- Never assume tool type — mark `custom` and flag it if unsure
- If user sends multiple requirements in one message, split into separate JSON outputs
- Keep step actions short — one sentence each
- Never start execution — only gather and structure
- This system handles ANY domain: finance, devops, AI/ML, data engineering, communication, infrastructure — no restrictions

## Clarification Loop

If the requirement is unclear:
"I want to make sure I understand correctly. [Restate what you heard].
Is this right, or did you mean something different?"

Wait for confirmation before outputting JSON.

## Direct Input Mode

If the user gives a clear, complete requirement in one message (e.g., "Create a skill that monitors GitHub for new PRs and posts to Telegram"), skip questions and extract directly:
1. Parse the obvious fields (goal, tools, trigger)
2. Ask only about genuinely missing pieces (env vars? error handling?)
3. Output the JSON

## Handoff

After outputting the structured JSON, trigger the `skill-creator` skill to search for or create the skill.
Tell user: "Requirement captured. Searching for existing skills..."
