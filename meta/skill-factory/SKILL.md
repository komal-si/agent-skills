---
name: skill-factory
description: >
  Build OpenClaw skills, agents, and workspaces from a structured blueprint.
  Trigger after requirement-gatherer produces a JSON blueprint. Also trigger
  when user says "create a skill for X", "build a skill", "add this as a
  skill", "turn this into a skill", "find a skill that does X",
  "install a skill for X", "build an agent for X".
metadata: {"openclaw": {"requires": {"env": []}, "emoji": "⚙️"}}
---

# Skill Factory

## Purpose

Receive a structured blueprint from requirement-gatherer (or direct text) and execute it: search for existing skills, create new SKILL.md files, generate agent workspaces, update openclaw.json, validate, get user approval, push to GitHub.

Handles three architecture types: single-skill, multi-skill, multi-agent.

## Input Handling

Two input modes:

1. **From requirement-gatherer**: Read the structured JSON blueprint with requirement, capabilities, architecture, agents[], workflow, openclaw_config, deployment
2. **Direct text**: User provides a freeform description. Run a quick extraction (goal, tools, steps) and assume single-skill architecture. Use best-effort parsing.

## Flow by Architecture Type

### Single-Skill Flow

```
Blueprint received (architecture.type = "single-skill")
  ↓
Step 1: Search for existing skill
  Found? → Install → Skip to Step 5
  ↓ Not found
Step 2: Generate one SKILL.md from template
  ↓
Step 3: Validate
  ↓
Step 4: Show to user for approval
  ↓ Approved
Step 5: Save locally + push to GitHub
  ↓
Step 6: Update openclaw.json skill entry
  ↓
Step 7: Confirm to user
```

### Multi-Skill Flow

```
Blueprint received (architecture.type = "multi-skill")
  ↓
For EACH skill in agents[0].skills:
  Step 1: Search for existing skill
    Found? → Install → Mark as done
    Not found? → Step 2: Generate SKILL.md
  Step 3: Validate each generated SKILL.md
  ↓
Step 4: Show ALL skills to user for approval
  ↓ Approved
Step 5: Save all locally + push all to GitHub (one commit)
  ↓
Step 6: Update openclaw.json (all skill entries + cron if any)
  ↓
Step 7: Update AGENTS.md with workflow instructions
  ↓
Step 8: Confirm to user
```

### Multi-Agent Flow

```
Blueprint received (architecture.type = "multi-agent")
  ↓
For EACH agent in agents[]:
  Step A: Create workspace folder
    Generate: SOUL.md, IDENTITY.md, AGENTS.md, USER.md, TOOLS.md
  Step B: For each skill in agent.skills:
    Search → Generate → Validate
  ↓
Step 4: Show complete blueprint to user:
  - All agent workspaces
  - All SKILL.md files
  - openclaw.json changes
  - Bindings and subagent config
  ↓ Approved
Step 5: Save all files + push to GitHub
  ↓
Step 6: Update openclaw.json:
  - Add agent entries to agents.list[]
  - Add skill entries to skills.entries{}
  - Add bindings
  - Add subagent allowlists
  - Add cron entries
  ↓
Step 7: Register agents: openclaw agents add {id} --workspace {path}
  ↓
Step 8: Confirm to user
```

## Step Details

### Step 1: Search for Existing Skills

For each skill in the blueprint, search before creating:

**Search ClawHub:**
```bash
npx clawhub search "{search_query}"
```

If a result clearly matches (name/description aligns with skill goal):
```bash
cd ~/.openclaw/workspace && npx clawhub install {slug}
```
Report: "Found existing skill '{name}' on ClawHub. Installing..."
Mark skill as `source: "clawhub"` and skip generation.

**Search skills.sh:**
If ClawHub has no match, search skills.sh marketplace via web:
- Search for: `{skill goal keywords}`
- If found: adapt its SKILL.md to OpenClaw format (add `metadata.openclaw` block)

### Step 2: Generate SKILL.md

Read the template from: `{baseDir}/references/skill-template.md`

Fill in placeholders from the blueprint's skill definition:

- **name** ← `skill.name`
- **description** ← goal + trigger phrases (be aggressive with triggers — agent undertriggers by default)
- **metadata.openclaw.requires.env** ← `skill.env_vars[].name`
- **Steps section** ← one `### Step N` per `skill.steps[]`, using tool-type-specific patterns from the template
- **Rules** ← inferred from step types
- **Error Handling** ← based on tool types

### Step 3: Validate

Run validation on each generated SKILL.md:

```bash
python3 {baseDir}/scripts/validate_skill.py {skill_path}/SKILL.md
```

Checks: name present + kebab-case, description > 20 words, body < 500 lines, no hardcoded secrets.

If validation fails → fix issue → re-validate. Max 2 retries.

### Step 4: Show to User

**NEVER skip this step.**

For single-skill: show the SKILL.md content.
For multi-skill: show a summary table of all skills, then each SKILL.md.
For multi-agent: show the full blueprint:
- Agent list with roles
- Skills per agent
- Workspace file summaries
- openclaw.json changes
- Bindings

"Here is what I will create. Review and reply YES to proceed, or tell me what to change."

### Step 5: Save and Push to GitHub

On user approval:

**Save skills locally:**
```bash
mkdir -p ~/Desktop/openclaw-automation/agent-skills/skills/{name}
# Write SKILL.md
```

**Save agent workspaces (multi-agent only):**
```bash
mkdir -p ~/Desktop/openclaw-automation/{agent-id}-workspace/skills/{skill-name}
# Write SOUL.md, IDENTITY.md, AGENTS.md, USER.md, TOOLS.md
# Write each skill's SKILL.md
```

**Push to GitHub:**
```bash
cd ~/Desktop/openclaw-automation/agent-skills
git add skills/
git commit -m "feat: add {skill-names} skill(s)"
git push origin main
```

### Step 6: Update openclaw.json

Read current `~/.openclaw/openclaw.json` and update:

**For single-skill:**
- Add skill entry to `skills.entries`

**For multi-skill:**
- Add all skill entries to `skills.entries`
- Add cron entries if any

**For multi-agent:**
- Add agent entries to `agents.list[]`
- Add all skill entries
- Add `bindings[]` for channel routing
- Add `subagents.allowAgents` to relevant agents
- Add extraDirs if agent workspaces have skills outside default paths

Read `{baseDir}/references/openclaw-config-guide.md` for exact JSON format.

### Step 7: Agent Registration (multi-agent only)

For each new agent:
```bash
openclaw agents add {agent-id} --workspace {workspace-path} --model openai-codex/gpt-5.4
```

### Step 8: Confirm

Report to user:

**Single-skill:**
```
Skill '{name}' is ready.
- Source: {ClawHub / skills.sh / generated}
- Saved to: GitHub + local workspace
- ENV vars needed: {list}
- Trigger with: '{example phrase}'
Want me to run it now?
```

**Multi-skill:**
```
{N} skills created for {workflow name}:
- {skill-1}: {goal}
- {skill-2}: {goal}
- Orchestrator: {orchestrator-skill}
All pushed to GitHub. ENV vars needed: {consolidated list}
Workflow instructions added to AGENTS.md.
```

**Multi-agent:**
```
{N} agents created:
- {agent-1} ({role}): {N} skills
- {agent-2} ({role}): {N} skills
Workspaces: {paths}
Bindings: {routing summary}
All registered with OpenClaw. Gateway restart needed.
Run: openclaw gateway restart
```

## Workspace Generation (Multi-Agent)

When creating a new agent workspace, read templates from `{baseDir}/references/workspace-template.md` and fill in:

- **SOUL.md** ← from blueprint `workspace_files.SOUL.md`
- **IDENTITY.md** ← from blueprint `workspace_files.IDENTITY.md`
- **AGENTS.md** ← from blueprint `workspace_files.AGENTS.md` + standard sections (Session Startup, Memory, Red Lines)
- **USER.md** ← copy from main workspace (same human operator)
- **TOOLS.md** ← minimal, agent-specific tool notes

## Rules

- NEVER skip user approval (Step 4)
- NEVER push to GitHub without explicit YES
- NEVER generate a skill longer than 500 lines
- Always search before generating — reuse > build
- Secrets must NEVER appear in SKILL.md — only ENV var references
- If a skill with the same name exists, ask: overwrite or rename?
- If an agent with the same id exists, ask: update or create new?
- For multi-agent: always set up bindings or sessions_spawn — agents need a way to communicate

## Error Handling

- ClawHub search fails → continue to skills.sh → continue to generate
- skills.sh unreachable → skip to generate
- Validation fails after 2 retries → show errors, ask user
- GitHub push fails → save locally, warn about push failure
- Agent registration fails → show error, provide manual command
- openclaw.json update fails → show the JSON diff for manual application
