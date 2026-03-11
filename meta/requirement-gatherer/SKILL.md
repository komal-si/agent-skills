---
name: requirement-gatherer
description: >
  Analyze any user requirement and produce a complete OpenClaw-compatible
  agent blueprint. Always trigger FIRST when a user gives any new task,
  requirement, workflow request, or says "I want to automate X", "/skill",
  "create a skill for", "make a skill that", "new requirement",
  "automate this", "I need a skill", "build an agent for".
  This is the entry point for all new skill and agent work.
  NOT for project-level requirements (use /pm).
metadata: {"openclaw": {"requires": {"env": []}, "emoji": "📋"}}
---

# Agent Builder — Requirement Analyzer

## Purpose

Entry point for all new automation work. Analyze a natural language requirement and produce a structured blueprint that the `skill-factory` can execute. The output covers architecture decisions, skill designs, workflows, folder structure, and deployment config — all mapped to what OpenClaw actually supports.

## Steps

Execute these 9 steps in sequence. Complete each before moving to the next.

### Step 1: Requirement Understanding

Extract the full context from the user's requirement:

| Field | Extract |
|-------|---------|
| **Primary objective** | What is the end outcome? One verb-first sentence. |
| **Triggers** | What starts this? (command, event, cron schedule, webhook) |
| **External systems** | Which services are involved? (Jira, GitHub, Slack, DB, APIs) |
| **Expected output** | What is produced? (notification, file, DB record, API call) |
| **Frequency** | One-time, on-demand, event-driven, or scheduled? |
| **Dependencies** | Does step X require step Y to complete first? |

If the requirement is clear and complete, extract directly — do not ask unnecessary questions.
If genuinely ambiguous, ask ONE clarifying question:
"I want to make sure I understand. [Restate what you heard]. Is this right?"

### Step 2: Capability Extraction

Break the requirement into abstract capabilities BEFORE choosing tools.

A capability is a discrete function the system must perform. Do not map to tool types yet — just identify what needs to happen.

Example for "Automate Jira ticket updates and send email when status changes":
- Jira event monitoring
- Ticket data retrieval
- Email composition
- Email delivery
- Workflow orchestration

List each capability with its domain (e.g., "project-management", "communication", "data").

### Step 3: Architecture Decision

Based on the capabilities, decide the architecture type:

**Single Skill** — when:
- 3 or fewer capabilities
- One domain
- Linear flow (A → B → C)
- No isolation needed

**Multi-Skill Single Agent** — when:
- More than 3 capabilities
- Multiple domains but shared context
- Parallel paths or reusable components
- All capabilities share the same auth/model

**Multi-Agent** — when:
- Capabilities need isolation (different auth contexts)
- Different models needed (LLM agent vs API agent)
- Independent lifecycle (one agent can restart without affecting others)
- Scale independently (high-volume notification agent vs low-volume analyzer)

Use the architecture guide: read `{baseDir}/references/architecture-guide.md` for the full decision matrix.

State your decision and reasoning:
"Architecture: {type}. Reason: {why}."

### Step 4: Skill Discovery

For EACH capability identified in Step 2, search for existing skills:

```bash
npx clawhub search "{capability keywords}"
```

Also search skills.sh marketplace via web for: `{capability keywords}`

Track results:
- Capability X → found: {skill name} on ClawHub → REUSE
- Capability Y → found: {skill name} on skills.sh → ADAPT
- Capability Z → not found → CREATE NEW

### Step 5: Skill Design

For each skill (reused, adapted, or new), define:

| Field | Value |
|-------|-------|
| **name** | kebab-case, max 64 chars |
| **goal** | What this skill does (verb-first sentence) |
| **inputs** | What data this skill receives |
| **outputs** | What data this skill produces |
| **steps** | Atomic steps with tool types (see taxonomy below) |
| **env_vars** | Credentials/config needed (SCREAMING_SNAKE_CASE) |
| **dependencies** | Other skills that must run before this one |

Tool type taxonomy for steps:

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

### Step 6: Agent & Sub-Agent Planning

**If architecture = single-skill or multi-skill:**
- One agent: use the existing `main` agent
- List skills to add to its workspace

**If architecture = multi-agent:**
For each agent, define:

| Field | Value |
|-------|-------|
| **id** | kebab-case agent identifier |
| **role** | One-sentence description of this agent's responsibility |
| **model** | Which model to use (default: openai-codex/gpt-5.4) |
| **skills** | Which skills are assigned to this agent |
| **SOUL.md summary** | Personality and boundaries for this agent |
| **IDENTITY.md** | Name and emoji |
| **AGENTS.md notes** | Key operating rules specific to this agent |

Define communication:
- Which agent spawns which? (via `sessions_spawn`)
- What data passes between them?
- What triggers the handoff?

### Step 7: Workflow Design

Define the execution sequence.

**For single-skill:** Steps are already defined inside the skill — skip this.

**For multi-skill single agent:**
```
1. Trigger: {what starts the workflow}
2. Skill: {skill-name} — {what it does}
3. Skill: {skill-name} — {receives output from step 2}
4. ...
```

**For multi-agent:**
```
1. Trigger: {event/command}
2. Agent: {agent-id} → Skill: {skill-name} — {action}
3. Agent: {agent-id} spawns Agent: {agent-id} with task: "{description}"
4. Agent: {agent-id} → Skill: {skill-name} — {action}
5. Result announced back to {originating agent}
```

### Step 8: OpenClaw Structure Generator

Generate the actual folder structure that OpenClaw will use.

**For single-skill:**
```
agent-skills/skills/{skill-name}/
└── SKILL.md
```

**For multi-skill single agent:**
```
agent-skills/skills/{skill-1}/
└── SKILL.md
agent-skills/skills/{skill-2}/
└── SKILL.md
agent-skills/skills/{orchestrator}/
└── SKILL.md
```
Plus AGENTS.md workflow instructions.

**For multi-agent:**
```
openclaw-automation/{agent-id}-workspace/
├── SOUL.md
├── IDENTITY.md
├── AGENTS.md
├── USER.md
├── TOOLS.md
├── memory/
└── skills/
    ├── {skill-1}/SKILL.md
    └── {skill-2}/SKILL.md
```
One workspace per agent. Plus openclaw.json entries.

OpenClaw does NOT support: agent_config.yaml, workflows/ folder, sub_agents/ folder, tools/ folder with Python files, sessions/ or logs/ in workspace. Workflows go in AGENTS.md. Agent config goes in openclaw.json.

### Step 9: Deployment Config

Define everything needed to make this work:

**Environment variables:**
List all ENV vars across all skills with name, description, required/optional.

**openclaw.json entries:**
- Agent entries for agents.list[]
- Skill entries for skills.entries{}
- Bindings for channel routing (if multi-agent)
- Subagent config: allowAgents, maxSpawnDepth (if multi-agent)
- Cron entries (if scheduled)

**External APIs:**
List all external services that need accounts/keys.

**Runtime:**
- local (default — OpenClaw gateway on machine)
- container (Daytona/Docker)
- cloud (Fly.io/GCP)

## Output

After completing all 9 steps, output the structured JSON spec:

```json
{
  "requirement": {
    "goal": "string",
    "triggers": ["string"],
    "frequency": "on-demand | cron-expression | event-driven",
    "external_systems": ["string"],
    "dependencies": ["string"]
  },
  "capabilities": [
    { "name": "string", "domain": "string" }
  ],
  "architecture": {
    "type": "single-skill | multi-skill | multi-agent",
    "reasoning": "string"
  },
  "agents": [
    {
      "id": "kebab-case",
      "role": "string",
      "model": "string",
      "workspace_files": {
        "SOUL.md": "personality summary",
        "IDENTITY.md": "name + emoji",
        "AGENTS.md": "key operating rules"
      },
      "skills": [
        {
          "name": "kebab-case",
          "goal": "string",
          "steps": [
            { "order": 1, "action": "string", "tool_type": "string", "details": "string" }
          ],
          "env_vars": [{ "name": "VAR", "description": "string" }],
          "inputs": "string",
          "outputs": "string",
          "source": "new | clawhub | skills.sh"
        }
      ]
    }
  ],
  "workflow": {
    "steps": [
      { "order": 1, "agent": "agent-id", "skill": "skill-name", "trigger": "string" }
    ]
  },
  "openclaw_config": {
    "agent_entries": [{ "id": "string", "workspace": "path", "model": "string" }],
    "skill_entries": { "skill-name": { "enabled": true, "env": {} } },
    "bindings": [],
    "subagent_config": { "allowAgents": [] },
    "cron": []
  },
  "deployment": {
    "env_vars": [{ "name": "string", "description": "string", "required": true }],
    "external_apis": ["string"],
    "runtime": "local | container | cloud"
  }
}
```

For single-skill architecture, the `agents` array has one entry (the existing main agent) with one skill. The `workflow` and `openclaw_config` sections can be minimal.

## Rules

- Ask ONE clarifying question max if requirement is ambiguous
- Never assume architecture — derive it from capabilities
- Always search before creating (Step 4 before Step 5)
- Never start execution — only gather and structure
- Keep skill steps atomic — one action per step
- Handle ANY domain: finance, devops, AI/ML, data, communication, infrastructure
- For single-skill requirements, Steps 6-8 are lightweight (just list the one skill under main agent)
- Never include secrets in the output — only ENV var names

## Handoff

After outputting the structured JSON, trigger the `skill-factory` skill.
Tell user: "Blueprint ready. Building skills..."
