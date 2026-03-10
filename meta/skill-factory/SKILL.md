---
name: skill-factory
description: >
  Create a new OpenClaw skill from a structured requirement spec.
  Trigger after requirement-gatherer produces JSON output. Also
  trigger when user says "create a skill for X", "build a skill",
  "add this as a skill", "turn this into a skill", "find a skill
  that does X", "install a skill for X".
metadata: {"openclaw": {"requires": {"env": []}, "emoji": "⚙️"}}
---

# Skill Creator

## Purpose

Receive a structured requirement spec (from requirement-gatherer or direct text), search for an existing skill, or create a new SKILL.md. Validate, get user approval, push to GitHub, and confirm.

## Flow

```
Receive structured JSON spec
  ↓
Step 1: Search ClawHub
  Found? → Install → Done
  ↓ Not found
Step 2: Search skills.sh (web)
  Found? → Adapt → Save → Done
  ↓ Not found
Step 3: Generate new SKILL.md from template
  ↓
Step 4: Validate generated SKILL.md
  Invalid? → Fix → Re-validate (max 2 retries)
  ↓ Valid
Step 5: Show to user for approval
  Not approved? → Edit per feedback → Re-show
  ↓ Approved
Step 6: Push to GitHub + save locally
  ↓
Step 7: Confirm to user
```

## Input Handling

Two input modes:

1. **From requirement-gatherer**: Read the structured JSON spec (goal, steps, env_vars, tools, search_query, skill_name_suggestion, category)
2. **Direct text**: User provides a freeform description. Extract: goal, steps, tools, env vars. Use best-effort parsing.

Either way, produce a normalized spec with at minimum: `goal`, `steps`, `skill_name_suggestion`.

## Step 1: Search ClawHub

```bash
npx clawhub search "{spec.search_query}"
```

Parse the output. If a result clearly matches the goal (name/description aligns):

```bash
cd ~/.openclaw/workspace && npx clawhub install {slug}
```

Report to user: "Found existing skill '{name}' on ClawHub. Installing..."
Done — skip to Step 7.

## Step 2: Search skills.sh

If ClawHub has no match, search the skills.sh marketplace via web:
- Visit `https://skills.sh`
- Search for: `{spec.search_query}`

If a matching skill is found:
- Download or adapt its SKILL.md to OpenClaw format (add `metadata.openclaw` block)
- Save to `~/.openclaw/workspace/skills/{name}/SKILL.md`
- Skip to Step 5 for user approval

## Step 3: Generate SKILL.md

Read the template from: `{baseDir}/references/skill-template.md`

Fill in every placeholder using the structured spec:

- **name** ← `spec.skill_name_suggestion`
- **description** ← goal + trigger phrases (make it pushy — agent undertriggers by default)
- **metadata.openclaw.requires.env** ← `spec.env_vars_needed[].name`
- **Steps section** ← one `### Step N` per `spec.steps[]`, with tool-type-specific instructions:

| tool_type | Step Pattern |
|-----------|-------------|
| `api` | Call {endpoint} using {ENV_VAR}. Method: GET/POST. Parse response for {fields}. |
| `mcp` | Use MCP server {name}, tool {tool_name}. Input: {params}. Handle response. |
| `cli` | Run: `{command}`. Check exit code. Parse stdout for {data}. |
| `db` | Query: `{SQL}`. Connection: {ENV_VAR}. Handle empty results. |
| `file` | Read/write {path}. Format: {JSON/CSV/MD}. Validate before writing. |
| `browser` | Navigate to {URL}. Extract {selector/data}. Handle page load failures. |
| `llm` | Prompt: "{instruction}". Model: {model}. Expected output: {format}. |
| `data-pipeline` | Input: {source}. Transform: {operations}. Output: {destination}. |
| `notification` | Send to {channel} via {method}. Content: {template}. |
| `cron` | Schedule: {expression}. On trigger: {action}. |
| `auth` | Auth flow: {type}. Token storage: {where}. Refresh: {when}. |
| `infra` | Target: {service}. Action: {operation}. Rollback: {strategy}. |
| `custom` | {Detailed custom instructions from spec.steps[].details}. |

- **Rules section** ← inferred from step types (e.g., confirmation for payments, retry for APIs)
- **Error Handling** ← based on tool types (timeout, auth failure, invalid data)
- **Configuration** ← list all env vars with descriptions

## Step 4: Validate

Run the validation script:

```bash
python3 {baseDir}/scripts/validate_skill.py {skill_path}/SKILL.md
```

Checks:
- name is present and kebab-case
- description is present and > 20 words
- metadata is valid JSON (if present)
- body is under 500 lines
- no hardcoded secrets (sk-, ghp_, xoxb-, etc.)

If validation fails → read error, fix issue, re-validate. Max 2 retries.
If still failing → show user the errors and ask for help.

## Step 5: Show to User

Present the generated SKILL.md content to the user:

"Here is the skill I generated. Please review:"
[Show full SKILL.md content]
"Should I save this? Reply YES to proceed, or tell me what to change."

**NEVER skip this step.** Wait for explicit user confirmation.

## Step 6: Push to GitHub + Save Locally

On user approval:

### Save locally
```bash
mkdir -p ~/.openclaw/workspace/skills/{name}
# Write SKILL.md to ~/.openclaw/workspace/skills/{name}/SKILL.md
# Write any scripts/ or references/ files
```

### Push to GitHub
Use GitHub API via `gh` CLI:

```bash
cd ~/Desktop/openclaw-automation/agent-skills
mkdir -p skills/{name}
# Copy SKILL.md and supporting files to skills/{name}/
git add skills/{name}/
git commit -m "feat: add {name} skill"
git push origin main
```

OpenClaw auto-reloads via file watcher (skills.load.watch: true) — no restart needed.

## Step 7: Confirm

Report to user:

"Skill '{name}' is ready.
- Source: {ClawHub / skills.sh / generated}
- Saved to: GitHub + local workspace
- ENV vars needed: {list, or 'none'}
- Category: {category}
- Trigger with: '{example trigger phrase}'
Want me to run it now?"

## Rules

- NEVER skip the user approval step (Step 5)
- NEVER push to GitHub without explicit user YES
- NEVER generate a skill longer than 500 lines in the body
- Always search before generating — reuse before build
- Secrets must NEVER appear in SKILL.md body — only in ENV declarations
- If a skill with the same name exists locally, ask user: overwrite or rename?

## Error Handling

- ClawHub search fails (network) → continue to Step 2, then Step 3
- skills.sh unreachable → skip to Step 3
- Validation fails after 2 retries → show errors, ask user for help
- GitHub push fails → save locally anyway, warn user about push failure
- Skill name conflicts → suggest alternative name with number suffix
