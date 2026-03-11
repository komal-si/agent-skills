# Architecture Decision Guide

## Decision Matrix

Use this matrix to determine the correct architecture for a requirement.

### Signals → Architecture Type

| Signal | Single Skill | Multi-Skill | Multi-Agent |
|--------|:---:|:---:|:---:|
| Capabilities ≤ 3 | Yes | — | — |
| Capabilities 4-6 | — | Yes | — |
| Capabilities > 6 | — | Maybe | Yes |
| One domain (e.g., only Jira) | Yes | — | — |
| Multiple domains (Jira + Email + DB) | — | Yes | Maybe |
| Linear flow (A → B → C) | Yes | — | — |
| Parallel paths (A → B, A → C) | — | Yes | — |
| Shared auth context | Yes | Yes | — |
| Different auth contexts | — | — | Yes |
| Same model for all tasks | Yes | Yes | — |
| Different models needed | — | — | Yes |
| All tasks have same lifecycle | Yes | Yes | — |
| Tasks restart independently | — | — | Yes |
| High-volume + low-volume mixed | — | — | Yes |

### Quick Decision Flow

```
Count capabilities from Step 2

≤ 3 capabilities + one domain + linear?
  → SINGLE SKILL

4-6 capabilities OR multiple domains OR parallel paths?
  → MULTI-SKILL SINGLE AGENT

Any of these true?
  - Different auth contexts needed
  - Different models needed
  - Independent restart/lifecycle
  - Scale independently
  → MULTI-AGENT
```

## Architecture Patterns

### Pattern 1: Single Skill

One SKILL.md with multiple steps under the existing main agent.

```
main agent
└── skills/
    └── github-pr-notifier/SKILL.md
        Step 1: Poll GitHub API for new PRs
        Step 2: Format notification message
        Step 3: Send to Telegram
```

**When:** Simple, linear, few integrations.
**OpenClaw output:** One SKILL.md in agent-skills/skills/, one entry in openclaw.json.

### Pattern 2: Multi-Skill Single Agent

Multiple SKILL.md files under one agent workspace. An orchestrator skill coordinates them.

```
main agent
└── skills/
    ├── jira-ticket-fetcher/SKILL.md      (reusable)
    ├── email-sender/SKILL.md             (reusable)
    ├── slack-notifier/SKILL.md           (reusable)
    └── jira-update-workflow/SKILL.md     (orchestrator — calls the others)
```

**When:** Multiple capabilities, reusable components, shared context.
**OpenClaw output:** Multiple SKILL.md files, AGENTS.md workflow section, openclaw.json entries.

**Orchestrator skill pattern:**
The orchestrator skill's steps reference other skills by name:
```
Step 1: Use the jira-ticket-fetcher skill to get updated tickets
Step 2: For each ticket, use email-sender skill to notify assignee
Step 3: Use slack-notifier skill to post summary to #updates channel
```

### Pattern 3: Multi-Agent

Separate agents with their own workspaces, skills, and identities. Connected via sessions_spawn or channel bindings.

```
main agent (orchestrator)
├── workspace/SOUL.md, AGENTS.md, ...
└── skills/workflow-coordinator/SKILL.md

jira-manager agent
├── workspace/SOUL.md, AGENTS.md, ...
└── skills/
    ├── jira-ticket-fetcher/SKILL.md
    └── jira-ticket-updater/SKILL.md

notification-agent
├── workspace/SOUL.md, AGENTS.md, ...
└── skills/
    ├── email-sender/SKILL.md
    └── slack-notifier/SKILL.md
```

**When:** Isolation, different models, independent lifecycle.
**OpenClaw output:** Multiple workspace folders, multiple agent entries in openclaw.json, bindings, subagent allowlists.

**Connection methods:**

1. **sessions_spawn** — Main agent spawns sub-agents with a task. Sub-agent runs independently, announces result back.
   ```json
   { "subagents": { "allowAgents": ["jira-manager", "notification-agent"] } }
   ```

2. **Channel bindings** — Route Telegram groups/DMs directly to specific agents.
   ```json
   { "bindings": [
     { "agentId": "jira-manager", "match": { "channel": "telegram", "peer": { "kind": "group", "id": "-100XXX" } } }
   ]}
   ```

## Default: Prefer Simpler Architecture

When in doubt, choose the simpler option:
- Single skill > Multi-skill > Multi-agent
- You can always upgrade later by splitting a multi-step skill into separate skills
- Multi-agent adds operational overhead (more workspaces, more config, more things to debug)

Only choose multi-agent when isolation is genuinely needed, not just because the requirement is complex.
