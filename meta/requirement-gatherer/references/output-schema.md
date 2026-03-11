# Output Schema Reference

## Full Schema

```json
{
  "requirement": {
    "org": "string — org prefix (mandatory, e.g. ruh, acme)",
    "goal": "string — verb-first present tense",
    "triggers": ["string — event/command that starts this"],
    "frequency": "on-demand | <cron expression> | event-driven",
    "external_systems": ["service names"],
    "dependencies": ["requires X before Y"]
  },
  "capabilities": [
    { "name": "string — abstract capability", "domain": "string — category" }
  ],
  "architecture": {
    "type": "single-skill | multi-skill | multi-agent",
    "reasoning": "string — why this architecture"
  },
  "agents": [
    {
      "id": "kebab-case",
      "role": "string — what this agent does",
      "model": "string — default: openai-codex/gpt-5.4",
      "workspace_files": {
        "SOUL.md": "personality summary (only for NEW agents, omit for main)",
        "IDENTITY.md": "name + emoji (only for NEW agents)",
        "AGENTS.md": "key operating rules (only for NEW agents)"
      },
      "skills": [
        {
          "name": "kebab-case — max 64 chars",
          "goal": "string — what this skill does",
          "steps": [
            {
              "order": 1,
              "action": "string — one sentence",
              "tool_type": "api|mcp|cli|db|file|browser|llm|data-pipeline|notification|cron|auth|infra|custom",
              "details": "string — specific endpoint, command, or model"
            }
          ],
          "env_vars": [
            { "name": "SCREAMING_SNAKE_CASE", "description": "what for" }
          ],
          "inputs": "string — what data this skill receives",
          "outputs": "string — what data this skill produces",
          "source": "new | clawhub | skills.sh"
        }
      ]
    }
  ],
  "workflow": {
    "steps": [
      { "order": 1, "agent": "agent-id", "skill": "skill-name", "trigger": "what starts this" }
    ]
  },
  "openclaw_config": {
    "agent_entries": [
      { "id": "string", "workspace": "absolute path", "model": "string" }
    ],
    "skill_entries": {
      "skill-name": { "enabled": true, "env": { "VAR": "value" } }
    },
    "bindings": [
      { "agentId": "string", "match": { "channel": "telegram", "peer": {} } }
    ],
    "subagent_config": {
      "allowAgents": ["agent-id"],
      "maxSpawnDepth": 2
    },
    "cron": []
  },
  "deployment": {
    "env_vars": [
      { "name": "string", "description": "string", "required": true }
    ],
    "external_apis": ["service names that need accounts/keys"],
    "runtime": "local | container | cloud"
  }
}
```

## Validation Rules

- `requirement.goal` must not be empty, must start with a verb
- `capabilities` must have at least 1 item
- `architecture.type` must be one of: single-skill, multi-skill, multi-agent
- `agents` must have at least 1 entry
- For single-skill and multi-skill: agents[0].id should be "main" (existing agent)
- For multi-agent: each agent needs unique id, workspace_files are required for new agents
- `requirement.org` must be present, 2-10 lowercase chars matching `^[a-z][a-z0-9]{1,9}$`
- `skills[].name` must be org-prefixed kebab-case matching `^{org}-[a-z][a-z0-9-]*$`
- For multi-agent: `agents[].id` must be org-prefixed: `^{org}-[a-z][a-z0-9-]*$`
- `skills[].steps` must have at least 1 item
- `env_vars[].name` must be SCREAMING_SNAKE_CASE
- `workflow.steps` required for multi-skill and multi-agent, optional for single-skill
- `openclaw_config.agent_entries` required for multi-agent, empty for single-skill/multi-skill using main

## Examples

### Example 1: Single Skill — GitHub PR Notifier

Requirement: "Monitor a GitHub repo for new PRs and notify me on Telegram"

```json
{
  "requirement": {
    "org": "ruh",
    "goal": "Monitor GitHub repository for new pull requests and send Telegram notifications",
    "triggers": ["cron schedule every 15 minutes"],
    "frequency": "*/15 * * * *",
    "external_systems": ["GitHub API", "Telegram Bot API"],
    "dependencies": []
  },
  "capabilities": [
    { "name": "GitHub PR polling", "domain": "devops" },
    { "name": "Telegram notification", "domain": "communication" }
  ],
  "architecture": {
    "type": "single-skill",
    "reasoning": "2 capabilities, one linear flow (poll → notify), shared auth context"
  },
  "agents": [
    {
      "id": "main",
      "role": "existing main agent",
      "model": "openai-codex/gpt-5.4",
      "workspace_files": {},
      "skills": [
        {
          "name": "ruh-github-pr-notifier",
          "goal": "Poll GitHub for new PRs and send Telegram notification",
          "steps": [
            { "order": 1, "action": "Fetch open PRs from GitHub API", "tool_type": "api", "details": "GET /repos/{owner}/{repo}/pulls?state=open&sort=created" },
            { "order": 2, "action": "Compare against last-seen PR IDs stored in state file", "tool_type": "file", "details": "Read/write ~/.openclaw/workspace/skills/ruh-github-pr-notifier/state.json" },
            { "order": 3, "action": "Send notification for each new PR via Telegram", "tool_type": "notification", "details": "Telegram Bot API sendMessage with PR title, author, URL" }
          ],
          "env_vars": [
            { "name": "GITHUB_TOKEN", "description": "GitHub PAT with repo read access" },
            { "name": "TELEGRAM_CHAT_ID", "description": "Target Telegram chat for notifications" }
          ],
          "inputs": "GitHub repo owner/name from config",
          "outputs": "Telegram message per new PR",
          "source": "new"
        }
      ]
    }
  ],
  "workflow": {
    "steps": [
      { "order": 1, "agent": "main", "skill": "ruh-github-pr-notifier", "trigger": "cron every 15 min" }
    ]
  },
  "openclaw_config": {
    "agent_entries": [],
    "skill_entries": {
      "ruh-github-pr-notifier": { "enabled": true, "env": { "GITHUB_TOKEN": "", "TELEGRAM_CHAT_ID": "" } }
    },
    "bindings": [],
    "subagent_config": {},
    "cron": [{ "schedule": "*/15 * * * *", "skill": "ruh-github-pr-notifier" }]
  },
  "deployment": {
    "env_vars": [
      { "name": "GITHUB_TOKEN", "description": "GitHub Personal Access Token", "required": true },
      { "name": "TELEGRAM_CHAT_ID", "description": "Telegram chat ID for notifications", "required": true }
    ],
    "external_apis": ["GitHub REST API", "Telegram Bot API"],
    "runtime": "local"
  }
}
```

### Example 2: Multi-Skill — Jira Ticket Workflow

Requirement: "Watch Jira tickets assigned to me, update their status, notify on Slack and email"

```json
{
  "requirement": {
    "org": "ruh",
    "goal": "Watch Jira tickets, auto-update statuses, and notify via Slack and email",
    "triggers": ["cron every 30 minutes", "/jira-check command"],
    "frequency": "*/30 * * * *",
    "external_systems": ["Jira API", "Slack API", "SMTP Email"],
    "dependencies": ["ticket fetch must complete before status update or notification"]
  },
  "capabilities": [
    { "name": "Jira ticket polling", "domain": "project-management" },
    { "name": "Jira status update", "domain": "project-management" },
    { "name": "Slack notification", "domain": "communication" },
    { "name": "Email notification", "domain": "communication" },
    { "name": "Workflow orchestration", "domain": "automation" }
  ],
  "architecture": {
    "type": "multi-skill",
    "reasoning": "5 capabilities across 3 domains. Slack and email notifiers are reusable. All share the same auth context under main agent."
  },
  "agents": [
    {
      "id": "main",
      "role": "existing main agent",
      "model": "openai-codex/gpt-5.4",
      "workspace_files": {},
      "skills": [
        {
          "name": "ruh-jira-ticket-fetcher",
          "goal": "Fetch Jira tickets assigned to current user",
          "steps": [
            { "order": 1, "action": "Query Jira API for tickets assigned to me with recent updates", "tool_type": "api", "details": "GET /rest/api/3/search?jql=assignee=currentUser() AND updated>=-30m" },
            { "order": 2, "action": "Parse ticket list and extract key, summary, status, comments", "tool_type": "data-pipeline", "details": "Extract fields from JSON response" }
          ],
          "env_vars": [
            { "name": "JIRA_API_TOKEN", "description": "Jira API token" },
            { "name": "JIRA_BASE_URL", "description": "Jira instance URL" },
            { "name": "JIRA_USER", "description": "Jira username/email" }
          ],
          "inputs": "JQL query parameters",
          "outputs": "Array of ticket objects with key, summary, status, comments",
          "source": "new"
        },
        {
          "name": "ruh-jira-status-updater",
          "goal": "Update Jira ticket status via transitions",
          "steps": [
            { "order": 1, "action": "Get available transitions for the ticket", "tool_type": "api", "details": "GET /rest/api/3/issue/{key}/transitions" },
            { "order": 2, "action": "Execute the target transition", "tool_type": "api", "details": "POST /rest/api/3/issue/{key}/transitions" }
          ],
          "env_vars": [
            { "name": "JIRA_API_TOKEN", "description": "Jira API token" }
          ],
          "inputs": "Ticket key + target status",
          "outputs": "Confirmation of status change",
          "source": "new"
        },
        {
          "name": "ruh-slack-notifier",
          "goal": "Send formatted notification to a Slack channel",
          "steps": [
            { "order": 1, "action": "Post message to Slack via webhook", "tool_type": "notification", "details": "POST to Slack incoming webhook URL with blocks payload" }
          ],
          "env_vars": [
            { "name": "SLACK_WEBHOOK_URL", "description": "Slack incoming webhook" }
          ],
          "inputs": "Message text + optional blocks",
          "outputs": "Delivery confirmation",
          "source": "new"
        },
        {
          "name": "ruh-email-sender",
          "goal": "Send email notification via SMTP",
          "steps": [
            { "order": 1, "action": "Compose and send email via SMTP", "tool_type": "notification", "details": "SMTP connection using host/port/credentials, send HTML email" }
          ],
          "env_vars": [
            { "name": "SMTP_HOST", "description": "SMTP server host" },
            { "name": "SMTP_USER", "description": "SMTP username" },
            { "name": "SMTP_PASS", "description": "SMTP password" }
          ],
          "inputs": "Recipient, subject, HTML body",
          "outputs": "Delivery confirmation",
          "source": "new"
        },
        {
          "name": "ruh-jira-update-workflow",
          "goal": "Orchestrate Jira monitoring: fetch tickets, update statuses, notify",
          "steps": [
            { "order": 1, "action": "Use ruh-jira-ticket-fetcher to get recently updated tickets", "tool_type": "custom", "details": "Invoke ruh-jira-ticket-fetcher skill" },
            { "order": 2, "action": "For tickets needing status change, use ruh-jira-status-updater", "tool_type": "custom", "details": "Invoke ruh-jira-status-updater skill per ticket" },
            { "order": 3, "action": "Use ruh-slack-notifier to post update summary", "tool_type": "custom", "details": "Invoke ruh-slack-notifier with formatted summary" },
            { "order": 4, "action": "Use ruh-email-sender for individual ticket notifications", "tool_type": "custom", "details": "Invoke ruh-email-sender per assignee" }
          ],
          "env_vars": [],
          "inputs": "Triggered by cron or /jira-check command",
          "outputs": "Slack + email notifications sent",
          "source": "new"
        }
      ]
    }
  ],
  "workflow": {
    "steps": [
      { "order": 1, "agent": "main", "skill": "ruh-jira-ticket-fetcher", "trigger": "cron or /jira-check" },
      { "order": 2, "agent": "main", "skill": "ruh-jira-status-updater", "trigger": "tickets needing update from step 1" },
      { "order": 3, "agent": "main", "skill": "ruh-slack-notifier", "trigger": "after steps 1-2 complete" },
      { "order": 4, "agent": "main", "skill": "ruh-email-sender", "trigger": "after steps 1-2 complete" }
    ]
  },
  "openclaw_config": {
    "agent_entries": [],
    "skill_entries": {
      "ruh-jira-ticket-fetcher": { "enabled": true, "env": { "JIRA_API_TOKEN": "", "JIRA_BASE_URL": "", "JIRA_USER": "" } },
      "ruh-jira-status-updater": { "enabled": true },
      "ruh-slack-notifier": { "enabled": true, "env": { "SLACK_WEBHOOK_URL": "" } },
      "ruh-email-sender": { "enabled": true, "env": { "SMTP_HOST": "", "SMTP_USER": "", "SMTP_PASS": "" } },
      "ruh-jira-update-workflow": { "enabled": true }
    },
    "bindings": [],
    "subagent_config": {},
    "cron": [{ "schedule": "*/30 * * * *", "skill": "ruh-jira-update-workflow" }]
  },
  "deployment": {
    "env_vars": [
      { "name": "JIRA_API_TOKEN", "description": "Jira API token", "required": true },
      { "name": "JIRA_BASE_URL", "description": "Jira instance URL", "required": true },
      { "name": "JIRA_USER", "description": "Jira username", "required": true },
      { "name": "SLACK_WEBHOOK_URL", "description": "Slack incoming webhook", "required": true },
      { "name": "SMTP_HOST", "description": "SMTP server", "required": true },
      { "name": "SMTP_USER", "description": "SMTP username", "required": true },
      { "name": "SMTP_PASS", "description": "SMTP password", "required": true }
    ],
    "external_apis": ["Jira REST API", "Slack Webhooks", "SMTP"],
    "runtime": "local"
  }
}
```

### Example 3: Multi-Agent — Customer Support System

Requirement: "Build a customer support system: classify tickets via LLM, route to teams, track SLA, send escalation emails"

```json
{
  "requirement": {
    "org": "acme",
    "goal": "Classify support tickets, route to teams, track SLA compliance, and escalate via email",
    "triggers": ["new ticket webhook", "cron every 10 minutes for SLA check"],
    "frequency": "event-driven + */10 * * * *",
    "external_systems": ["Zendesk API", "OpenAI API", "Slack API", "SMTP Email", "PostgreSQL"],
    "dependencies": ["classification before routing", "SLA tracking independent of classification"]
  },
  "capabilities": [
    { "name": "Ticket ingestion from Zendesk", "domain": "integration" },
    { "name": "LLM-based ticket classification", "domain": "ai" },
    { "name": "Team routing based on category", "domain": "automation" },
    { "name": "SLA deadline tracking", "domain": "data" },
    { "name": "SLA breach detection", "domain": "data" },
    { "name": "Escalation email sending", "domain": "communication" },
    { "name": "Slack team notification", "domain": "communication" },
    { "name": "Classification logging to DB", "domain": "data" }
  ],
  "architecture": {
    "type": "multi-agent",
    "reasoning": "8 capabilities across 4 domains. Classification needs LLM model (ai-focused). SLA tracking runs independently on its own schedule. Notification agent handles both Slack and email with different auth. Each agent has independent lifecycle — SLA checker must keep running even if classifier restarts."
  },
  "agents": [
    {
      "id": "acme-ticket-classifier",
      "role": "Ingest new tickets, classify via LLM, route to correct team",
      "model": "openai-codex/gpt-5.4",
      "workspace_files": {
        "SOUL.md": "You are a ticket classification specialist. Your job is to accurately categorize support tickets and route them to the right team. Be precise — misrouting costs time.",
        "IDENTITY.md": "Name: Ticket Classifier. Emoji: 🏷️",
        "AGENTS.md": "On new ticket: classify using LLM, update Zendesk with category, route to team, log to DB. Never respond to tickets directly — only classify and route."
      },
      "skills": [
        {
          "name": "acme-zendesk-ticket-ingester",
          "goal": "Fetch new unclassified tickets from Zendesk",
          "steps": [
            { "order": 1, "action": "Query Zendesk for tickets with status new and no category tag", "tool_type": "api", "details": "GET /api/v2/search?query=status:new -tags:classified" },
            { "order": 2, "action": "Extract ticket ID, subject, description, requester", "tool_type": "data-pipeline", "details": "Parse JSON response into ticket objects" }
          ],
          "env_vars": [{ "name": "ZENDESK_API_TOKEN", "description": "Zendesk API token" }],
          "inputs": "None (polls Zendesk)",
          "outputs": "Array of unclassified ticket objects",
          "source": "new"
        },
        {
          "name": "acme-llm-ticket-classifier",
          "goal": "Classify a ticket into billing/technical/feature-request/other using LLM",
          "steps": [
            { "order": 1, "action": "Send ticket subject + description to LLM with classification prompt", "tool_type": "llm", "details": "Prompt: classify into billing, technical, feature-request, or other. Return JSON." },
            { "order": 2, "action": "Update Zendesk ticket with classification tag and group assignment", "tool_type": "api", "details": "PUT /api/v2/tickets/{id} — update tags and group_id" },
            { "order": 3, "action": "Log classification result to PostgreSQL", "tool_type": "db", "details": "INSERT INTO classifications (ticket_id, category, confidence, classified_at)" }
          ],
          "env_vars": [
            { "name": "OPENAI_API_KEY", "description": "OpenAI API key for classification" },
            { "name": "CLASSIFICATION_DB_URL", "description": "PostgreSQL connection for logging" }
          ],
          "inputs": "Ticket object with subject and description",
          "outputs": "Classification result (category + confidence)",
          "source": "new"
        }
      ]
    },
    {
      "id": "acme-sla-tracker",
      "role": "Monitor SLA deadlines and detect breaches",
      "model": "openai-codex/gpt-5.4",
      "workspace_files": {
        "SOUL.md": "You are an SLA compliance monitor. Your job is to track response deadlines and escalate before they breach. Precision and timeliness are everything.",
        "IDENTITY.md": "Name: SLA Tracker. Emoji: ⏱️",
        "AGENTS.md": "Run SLA check every 10 minutes. Query DB for tickets approaching deadline. Trigger escalation for tickets within 30 minutes of breach."
      },
      "skills": [
        {
          "name": "acme-sla-breach-detector",
          "goal": "Check for tickets approaching or past SLA deadline",
          "steps": [
            { "order": 1, "action": "Query DB for tickets where deadline is within 30 minutes or past", "tool_type": "db", "details": "SELECT * FROM tickets WHERE sla_deadline < NOW() + interval '30 min' AND NOT escalated" },
            { "order": 2, "action": "For each breaching ticket, mark as escalated in DB", "tool_type": "db", "details": "UPDATE tickets SET escalated = true WHERE id = ?" }
          ],
          "env_vars": [{ "name": "SLA_DB_URL", "description": "PostgreSQL connection for SLA data" }],
          "inputs": "None (queries DB directly)",
          "outputs": "List of tickets needing escalation",
          "source": "new"
        }
      ]
    },
    {
      "id": "acme-notification-agent",
      "role": "Handle all outbound notifications: Slack messages and escalation emails",
      "model": "openai-codex/gpt-5.4",
      "workspace_files": {
        "SOUL.md": "You are a notification dispatcher. Deliver messages reliably to the right channel. Format messages clearly — recipients need to act fast on escalations.",
        "IDENTITY.md": "Name: Notifier. Emoji: 📢",
        "AGENTS.md": "When spawned with a notification task: determine channel (Slack or email), format the message, deliver, confirm delivery. Never take other actions."
      },
      "skills": [
        {
          "name": "acme-slack-team-notifier",
          "goal": "Send formatted message to a Slack channel",
          "steps": [
            { "order": 1, "action": "Post message with blocks to Slack channel via webhook", "tool_type": "notification", "details": "POST Slack webhook with formatted blocks" }
          ],
          "env_vars": [{ "name": "SLACK_WEBHOOK_URL", "description": "Slack incoming webhook" }],
          "inputs": "Channel, message text, blocks",
          "outputs": "Delivery confirmation",
          "source": "new"
        },
        {
          "name": "acme-escalation-emailer",
          "goal": "Send SLA escalation email to team lead",
          "steps": [
            { "order": 1, "action": "Compose escalation email with ticket details and SLA status", "tool_type": "data-pipeline", "details": "Format HTML email from ticket data" },
            { "order": 2, "action": "Send email via SMTP", "tool_type": "notification", "details": "SMTP send to team lead address" }
          ],
          "env_vars": [
            { "name": "SMTP_HOST", "description": "SMTP server" },
            { "name": "SMTP_USER", "description": "Sender email" },
            { "name": "SMTP_PASS", "description": "SMTP password" }
          ],
          "inputs": "Ticket details + escalation reason",
          "outputs": "Email delivery confirmation",
          "source": "new"
        }
      ]
    }
  ],
  "workflow": {
    "steps": [
      { "order": 1, "agent": "acme-ticket-classifier", "skill": "acme-zendesk-ticket-ingester", "trigger": "cron every 5 min" },
      { "order": 2, "agent": "acme-ticket-classifier", "skill": "acme-llm-ticket-classifier", "trigger": "new tickets from step 1" },
      { "order": 3, "agent": "acme-ticket-classifier", "skill": "sessions_spawn acme-notification-agent", "trigger": "after classification, notify team via Slack" },
      { "order": 4, "agent": "acme-sla-tracker", "skill": "acme-sla-breach-detector", "trigger": "cron every 10 min (independent)" },
      { "order": 5, "agent": "acme-sla-tracker", "skill": "sessions_spawn acme-notification-agent", "trigger": "breaching tickets found, send escalation email" }
    ]
  },
  "openclaw_config": {
    "agent_entries": [
      { "id": "acme-ticket-classifier", "workspace": "~/Desktop/openclaw-automation/acme-ticket-classifier-workspace", "model": "openai-codex/gpt-5.4" },
      { "id": "acme-sla-tracker", "workspace": "~/Desktop/openclaw-automation/acme-sla-tracker-workspace", "model": "openai-codex/gpt-5.4" },
      { "id": "acme-notification-agent", "workspace": "~/Desktop/openclaw-automation/acme-notification-agent-workspace", "model": "openai-codex/gpt-5.4" }
    ],
    "skill_entries": {
      "acme-zendesk-ticket-ingester": { "enabled": true, "env": { "ZENDESK_API_TOKEN": "" } },
      "acme-llm-ticket-classifier": { "enabled": true, "env": { "OPENAI_API_KEY": "", "CLASSIFICATION_DB_URL": "" } },
      "acme-sla-breach-detector": { "enabled": true, "env": { "SLA_DB_URL": "" } },
      "acme-slack-team-notifier": { "enabled": true, "env": { "SLACK_WEBHOOK_URL": "" } },
      "acme-escalation-emailer": { "enabled": true, "env": { "SMTP_HOST": "", "SMTP_USER": "", "SMTP_PASS": "" } }
    },
    "bindings": [
      { "agentId": "acme-ticket-classifier", "match": { "channel": "telegram", "peer": { "kind": "group", "id": "support-ops-group" } } },
      { "agentId": "main", "match": { "channel": "telegram" } }
    ],
    "subagent_config": {
      "allowAgents": ["acme-ticket-classifier", "acme-sla-tracker", "acme-notification-agent"],
      "maxSpawnDepth": 2
    },
    "cron": [
      { "schedule": "*/5 * * * *", "agent": "acme-ticket-classifier", "skill": "acme-zendesk-ticket-ingester" },
      { "schedule": "*/10 * * * *", "agent": "acme-sla-tracker", "skill": "acme-sla-breach-detector" }
    ]
  },
  "deployment": {
    "env_vars": [
      { "name": "ZENDESK_API_TOKEN", "description": "Zendesk API token", "required": true },
      { "name": "OPENAI_API_KEY", "description": "OpenAI API key for LLM classification", "required": true },
      { "name": "CLASSIFICATION_DB_URL", "description": "PostgreSQL for classification logs", "required": true },
      { "name": "SLA_DB_URL", "description": "PostgreSQL for SLA tracking", "required": true },
      { "name": "SLACK_WEBHOOK_URL", "description": "Slack incoming webhook for team notifications", "required": true },
      { "name": "SMTP_HOST", "description": "SMTP server for escalation emails", "required": true },
      { "name": "SMTP_USER", "description": "SMTP sender address", "required": true },
      { "name": "SMTP_PASS", "description": "SMTP password", "required": true }
    ],
    "external_apis": ["Zendesk REST API", "OpenAI API", "Slack Webhooks", "SMTP", "PostgreSQL"],
    "runtime": "local"
  }
}
```
