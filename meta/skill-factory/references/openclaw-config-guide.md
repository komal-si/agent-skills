# OpenClaw Config Guide

Reference for generating correct `~/.openclaw/openclaw.json` entries.

## Adding a New Agent

Add to `agents.list[]`:

```json
{
  "id": "agent-id",
  "name": "agent-id",
  "workspace": "~/Desktop/openclaw-automation/{agent-id}-workspace",
  "agentDir": "~/.openclaw/agents/{agent-id}/agent",
  "model": "openai-codex/gpt-5.4"
}
```

Or use the CLI:
```bash
openclaw agents add {agent-id} --workspace ~/Desktop/openclaw-automation/{agent-id}-workspace --model openai-codex/gpt-5.4
```

## Adding Skill Entries

Add to `skills.entries`:

```json
"skill-name": {
  "enabled": true,
  "env": {
    "ENV_VAR_1": "value-or-empty",
    "ENV_VAR_2": "value-or-empty"
  }
}
```

Only include `env` if the skill needs environment variables.

## Loading Skills from External Directories

Add to `skills.load.extraDirs`. Use org-based paths for skill isolation:

**Local machine paths:**
```json
"skills": {
  "load": {
    "extraDirs": [
      "~/Desktop/openclaw-automation/agent-skills/meta",
      "~/Desktop/openclaw-automation/agent-skills/orgs/{org}/skills",
      "~/Desktop/openclaw-automation/agent-skills/skills"
    ]
  }
}
```

**Daytona sandbox paths:**
```json
"skills": {
  "load": {
    "extraDirs": [
      "/home/daytona/agent-skills/meta",
      "/home/daytona/agent-skills/orgs/{org}/skills",
      "/home/daytona/agent-skills/skills"
    ]
  }
}
```

For multi-org on same machine, add multiple org skill dirs:
```json
"extraDirs": [
  "/path/to/agent-skills/meta",
  "/path/to/agent-skills/orgs/ruh/skills",
  "/path/to/agent-skills/orgs/acme/skills",
  "/path/to/agent-skills/skills"
]
```

Skills in `extraDirs` show as source `openclaw-extra` in `openclaw skills list`.
Skill names don't collide because of the org prefix (ruh-jira-monitor vs acme-jira-monitor).

## Channel Bindings

Add to root-level `bindings[]` array:

```json
"bindings": [
  {
    "agentId": "specific-agent",
    "match": {
      "channel": "telegram",
      "peer": { "kind": "group", "id": "-100XXXXXXXXXX" }
    }
  },
  {
    "agentId": "main",
    "match": { "channel": "telegram" }
  }
]
```

**Match order (most-specific wins):**
1. `peer` (exact group/DM id) — always wins
2. `guildId` (Discord) / `teamId` (Slack)
3. `accountId` (exact match)
4. `accountId: "*"` (channel-wide fallback)
5. Default agent (first in list)

**Important:** Put specific matches BEFORE general fallback. The `main` catch-all should be last.

## Sub-Agent Spawning Config

Add to the spawning agent's entry in `agents.list[]`:

```json
{
  "id": "main",
  "subagents": {
    "allowAgents": ["ticket-classifier", "sla-tracker", "notification-agent"],
    "maxSpawnDepth": 2,
    "maxChildrenPerAgent": 5,
    "maxConcurrent": 8
  }
}
```

- `allowAgents`: which agents this one can spawn (default: same agent only)
- `maxSpawnDepth`: 1 = no nesting, 2 = one level of sub-sub-agents (default: 1)
- `maxConcurrent`: global cap on running sub-agents (default: 8)

## Cron Jobs

Add to root-level `cron` config. Cron jobs are defined in openclaw.json, NOT in workspace files:

```json
"cron": {
  "enabled": true,
  "jobs": [
    {
      "schedule": "*/15 * * * *",
      "agentId": "main",
      "task": "Run the github-pr-notifier skill",
      "label": "PR check"
    }
  ]
}
```

## Custom Telegram Commands

Add to `channels.telegram.customCommands[]`:

```json
{
  "command": "command-name",
  "description": "What this command does"
}
```

These appear in Telegram's command menu. They don't auto-route — the agent handles them via AGENTS.md instructions.

## Full Example: Multi-Agent Config

```json
{
  "agents": {
    "list": [
      { "id": "main", "subagents": { "allowAgents": ["classifier", "notifier"] } },
      {
        "id": "classifier",
        "workspace": "~/Desktop/openclaw-automation/classifier-workspace",
        "model": "openai-codex/gpt-5.4"
      },
      {
        "id": "notifier",
        "workspace": "~/Desktop/openclaw-automation/notifier-workspace",
        "model": "openai-codex/gpt-5.4"
      }
    ]
  },
  "bindings": [
    { "agentId": "classifier", "match": { "channel": "telegram", "peer": { "kind": "group", "id": "-1001234567890" } } },
    { "agentId": "main", "match": { "channel": "telegram" } }
  ],
  "skills": {
    "load": {
      "extraDirs": [
        "~/Desktop/openclaw-automation/agent-skills/meta",
        "~/Desktop/openclaw-automation/agent-skills/skills",
        "~/Desktop/openclaw-automation/classifier-workspace/skills",
        "~/Desktop/openclaw-automation/notifier-workspace/skills"
      ]
    },
    "entries": {
      "zendesk-ingester": { "enabled": true, "env": { "ZENDESK_API_TOKEN": "" } },
      "llm-classifier": { "enabled": true, "env": { "OPENAI_API_KEY": "" } },
      "slack-notifier": { "enabled": true, "env": { "SLACK_WEBHOOK_URL": "" } }
    }
  }
}
```

## Gateway Restart

After config changes:
```bash
openclaw gateway restart
```

For skill-only changes (adding SKILL.md to watched dirs), no restart needed — file watcher picks it up automatically.

For agent additions, binding changes, or cron changes: restart required.
