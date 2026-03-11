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

Receive a structured blueprint from requirement-gatherer (or direct text) and execute it: search for existing skills, create new SKILL.md files, generate agent workspaces, update openclaw.json, validate, get user approval, push to GitHub. All skills and agents are org-scoped with `{org}-` prefix.

Handles three architecture types: single-skill, multi-skill, multi-agent.

After completion, triggers `agent-setup` skill for credential collection.

## Input Handling

Two input modes:

1. **From requirement-gatherer**: Read the structured JSON blueprint with requirement (including `org`), capabilities, architecture, agents[], workflow, openclaw_config, deployment
2. **Direct text**: User provides a freeform description. Ask for org first, then run a quick extraction (goal, tools, steps) and assume single-skill architecture. Use best-effort parsing.

**The `org` field is MANDATORY.** If missing from blueprint, ask: "Which organization is this for?"

## Org Setup (First Time)

If `agent-skills/orgs/{org}/` doesn't exist, create it:
```bash
mkdir -p ~/Desktop/openclaw-automation/agent-skills/orgs/{org}/skills
mkdir -p ~/Desktop/openclaw-automation/agent-skills/orgs/{org}/agent-templates
```

Create `org.json`:
```json
{
  "id": "{org}",
  "name": "{Org Display Name}",
  "owner": "{github-username}",
  "created": "{YYYY-MM-DD}",
  "prefix": "{org}"
}
```

Update `skills.load.extraDirs` in openclaw.json to include:
```
"~/Desktop/openclaw-automation/agent-skills/orgs/{org}/skills"
```

## Flow by Architecture Type

### Single-Skill Flow

```
Blueprint received (architecture.type = "single-skill", org = "{org}")
  ↓
Step 1: Search for existing skill
  Found? → Install + COPY to org folder → Skip to Step 5
  ↓ Not found
Step 2: Generate one SKILL.md (name: {org}-{skill-name})
  ↓
Step 3: Validate
  ↓
Step 4: Show to user for approval
  ↓ Approved
Step 5: Save to orgs/{org}/skills/ + push to GitHub
  ↓
Step 6: Update openclaw.json skill entry
  ↓
Step 7: Generate agent template (.env.example, openclaw-entries.json)
  ↓
Step 8: Trigger agent-setup for credential collection
  ↓
Step 9: Confirm to user
```

### Multi-Skill Flow

```
Blueprint received (architecture.type = "multi-skill", org = "{org}")
  ↓
For EACH skill in agents[0].skills:
  Step 1: Search for existing skill
    Found? → Install + COPY to org folder → Mark as done
    Not found? → Step 2: Generate SKILL.md (name: {org}-{skill-name})
  Step 3: Validate each generated SKILL.md
  ↓
Step 4: Show ALL skills to user for approval
  ↓ Approved
Step 5: Save all to orgs/{org}/skills/ + push to GitHub (one commit)
  ↓
Step 6: Update openclaw.json (all skill entries + cron if any)
  ↓
Step 7: Update AGENTS.md with workflow instructions
  ↓
Step 8: Generate agent template (.env.example, openclaw-entries.json)
  ↓
Step 9: Trigger agent-setup for credential collection
  ↓
Step 10: Confirm to user
```

### Multi-Agent Flow

```
Blueprint received (architecture.type = "multi-agent", org = "{org}")
  ↓
For EACH agent in agents[]:
  Step A: Create workspace folder ({org}-{agent-id}-workspace/)
    Generate: SOUL.md, IDENTITY.md, AGENTS.md, USER.md, TOOLS.md
  Step B: For each skill in agent.skills:
    Search → Copy/Generate → Validate
    Save to orgs/{org}/skills/{org}-{skill-name}/
  ↓
Step 4: Show complete blueprint to user:
  - All agent workspaces
  - All SKILL.md files
  - openclaw.json changes
  - Bindings and subagent config
  ↓ Approved
Step 5: Save all skills to orgs/{org}/skills/ + push to GitHub
  ↓
Step 6: Update openclaw.json:
  - Add agent entries to agents.list[]
  - Add skill entries to skills.entries{}
  - Add bindings
  - Add subagent allowlists
  - Add cron entries
  - Add extraDirs for org skills
  ↓
Step 7: Register agents: openclaw agents add {org}-{id} --workspace {path}
  ↓
Step 8: Generate agent templates (.env.example, openclaw-entries.json, README.md)
  ↓
Step 9: Trigger agent-setup for credential collection
  ↓
Step 10: Confirm to user
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
Mark skill as `source: "clawhub"`.

**ALWAYS COPY found skills into org folder** (see Copy-on-Install below).

**Search skills.sh:**
If ClawHub has no match, search skills.sh marketplace via web:
- Search for: `{skill goal keywords}`
- If found: adapt its SKILL.md to OpenClaw format (add `metadata.openclaw` block)

### Copy-on-Install (ALWAYS)

Every found skill gets copied into the org folder — this makes the agent self-contained.

**From ClawHub:**
```
Found "jira-monitor" on ClawHub → install to ~/.openclaw/skills/
  ↓
Copy ENTIRE folder to orgs/{org}/skills/{org}-jira-monitor/
  ↓
Rename in SKILL.md frontmatter: name: "{org}-jira-monitor"
  ↓
Add comment at top of SKILL.md body: "Source: clawhub:{original-name} v{version}"
  ↓
Include in the same git commit
```

**From skills.sh:**
```
Found skill on skills.sh → download/adapt
  ↓
Save directly to orgs/{org}/skills/{org}-{name}/ (no global install needed)
  ↓
Rename + add source note: "Source: skills.sh:{original-name}"
```

**From bundled OpenClaw skills:**
```
Blueprint needs "github" skill (bundled) → locate in OpenClaw install dir
  ↓
Copy to orgs/{org}/skills/{org}-github/
  ↓
Rename + add source note: "Source: openclaw-bundled:{original-name}"
```

### Step 2: Generate SKILL.md

Read the template from: `{baseDir}/references/skill-template.md`

Fill in placeholders from the blueprint's skill definition:

- **name** ← `{org}-{skill.name}` (ALWAYS org-prefixed)
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
- Skills per agent (showing org-prefixed names)
- Workspace file summaries
- openclaw.json changes
- Bindings

"Here is what I will create for org '{org}'. Review and reply YES to proceed, or tell me what to change."

### Step 5: Save and Push to GitHub

On user approval:

**Save skills to org folder (ALL architectures):**
```bash
mkdir -p ~/Desktop/openclaw-automation/agent-skills/orgs/{org}/skills/{org}-{skill-name}
# Write SKILL.md to orgs/{org}/skills/{org}-{skill-name}/SKILL.md
```

**Save agent workspaces (multi-agent only) — LOCAL, not in git:**
```bash
mkdir -p ~/Desktop/openclaw-automation/{org}-{agent-id}-workspace/skills/{org}-{skill-name}
# Write SOUL.md, IDENTITY.md, AGENTS.md, USER.md, TOOLS.md
# Copy skill SKILL.md files into workspace/skills/
```

**Push skills to GitHub:**
```bash
cd ~/Desktop/openclaw-automation/agent-skills
git add orgs/{org}/
git commit -m "feat({org}): add {skill-names} skill(s)"
git push origin main
```

### Step 6: Update openclaw.json

Read current `~/.openclaw/openclaw.json` and update:

**For ALL architectures:**
- Ensure `skills.load.extraDirs` includes `"~/Desktop/openclaw-automation/agent-skills/orgs/{org}/skills"`
- Add skill entries to `skills.entries` with org-prefixed names

**For multi-skill:**
- Add cron entries if any

**For multi-agent:**
- Add agent entries to `agents.list[]` (with org-prefixed IDs)
- Add `bindings[]` for channel routing
- Add `subagents.allowAgents` to relevant agents

Read `{baseDir}/references/openclaw-config-guide.md` for exact JSON format.

### Step 7: Agent Registration (multi-agent only)

For each new agent:
```bash
openclaw agents add {org}-{agent-id} --workspace {workspace-path} --model openai-codex/gpt-5.4
```

### Step 8: Generate Agent Templates

Create portable deployment files in the repo:

```bash
mkdir -p ~/Desktop/openclaw-automation/agent-skills/orgs/{org}/agent-templates/{org}-{agent-id}
```

Read `{baseDir}/references/agent-folder-template.md` for templates.

Generate:
- **`.env.example`** — All ENV vars from all skills, with descriptions. NO actual values.
- **`openclaw-entries.json`** — JSON snippet to merge into openclaw.json. NO credentials.
- **`README.md`** — How to deploy this agent: register, configure, restart.

Push these to GitHub:
```bash
cd ~/Desktop/openclaw-automation/agent-skills
git add orgs/{org}/agent-templates/
git commit -m "feat({org}): add agent template for {org}-{agent-id}"
git push origin main
```

### Step 9: Trigger Agent Setup

After skills are saved and templates generated, trigger the `agent-setup` skill:

Pass the list of skills just created with their ENV vars:
```
Skills needing configuration:
- {org}-{skill-1}: JIRA_API_TOKEN, JIRA_BASE_URL
- {org}-{skill-2}: SLACK_WEBHOOK_URL
```

The agent-setup skill will:
1. Check which ENV vars are already configured
2. Ask the user for missing credentials one at a time
3. Write values to openclaw.json per-skill env blocks
4. Validate credentials where possible
5. Report completion

### Step 10: Confirm

Report to user:

**Single-skill:**
```
✅ Skill '{org}-{name}' is ready.
- Org: {org}
- Source: {ClawHub / skills.sh / generated}
- Saved to: agent-skills/orgs/{org}/skills/{org}-{name}/
- Pushed to GitHub ✓
- Credentials: {configured by agent-setup / pending}
- Trigger with: '{example phrase}'
```

**Multi-skill:**
```
✅ {N} skills created for org '{org}':
- {org}-{skill-1}: {goal}
- {org}-{skill-2}: {goal}
- Orchestrator: {org}-{orchestrator}
All pushed to GitHub under orgs/{org}/skills/.
Credentials: {status from agent-setup}
Workflow instructions added to AGENTS.md.
```

**Multi-agent:**
```
✅ {N} agents created for org '{org}':
- {org}-{agent-1} ({role}): {N} skills
- {org}-{agent-2} ({role}): {N} skills
Workspaces: {paths}
Bindings: {routing summary}
Agent templates: orgs/{org}/agent-templates/
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

Workspace path: `~/Desktop/openclaw-automation/{org}-{agent-id}-workspace/`
Skills go in: `{workspace}/skills/{org}-{skill-name}/SKILL.md`

## Rules

- NEVER skip user approval (Step 4)
- NEVER push to GitHub without explicit YES
- NEVER generate a skill longer than 500 lines
- ALL skill names MUST be org-prefixed: `{org}-{skill-name}`
- ALL agent IDs MUST be org-prefixed: `{org}-{agent-role}`
- ALL skills go under `orgs/{org}/skills/` — NEVER under `skills/` (legacy)
- Always search before generating — reuse > build
- ALWAYS copy found skills into org folder (copy-on-install)
- Secrets must NEVER appear in SKILL.md — only ENV var references
- If a skill with the same name exists, ask: overwrite or rename?
- If an agent with the same id exists, ask: update or create new?
- For multi-agent: always set up bindings or sessions_spawn — agents need a way to communicate
- Always trigger agent-setup after skill creation for credential collection

## Error Handling

- ClawHub search fails → continue to skills.sh → continue to generate
- skills.sh unreachable → skip to generate
- Validation fails after 2 retries → show errors, ask user
- GitHub push fails → save locally, warn about push failure
- Agent registration fails → show error, provide manual command
- openclaw.json update fails → show the JSON diff for manual application
- Org folder creation fails → check permissions, try with sudo or warn user
- Copy-on-install fails → generate from scratch instead
