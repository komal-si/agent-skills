# SKILL.md Template

The agent fills in every `{placeholder}` from the structured requirement spec.
Sections marked `{if ...}` are conditional — include only when relevant.

---

```markdown
---
name: {skill_name}
description: >
  {goal_sentence}. Use when user mentions {trigger_keywords}.
  Also trigger when {alternative_context}.
metadata: {"openclaw": {"requires": {"env": [{env_vars_as_quoted_strings}]}, "primaryEnv": "{primary_env_var}", "emoji": "{emoji}"}}
---

# {Skill Title}

## Configuration

{For each env var:}
- `{ENV_VAR_NAME}` — {description}. {How to obtain it.}

## Steps

### Step 1: {Step Title}
{Instructions appropriate for tool_type:}

{if tool_type == api:}
Call {service} API using `{ENV_VAR}`.
Endpoint: {METHOD} {url}
Headers: Authorization: Bearer ${ENV_VAR}
Request body: {if POST, the payload structure}
Parse response for: {fields needed}
Handle: 401 (auth expired), 429 (rate limit), 5xx (retry)

{if tool_type == mcp:}
Use MCP server `{server_name}`, tool `{tool_name}`.
Input parameters: {params}
Expected output: {format}
Handle: connection timeout, tool not found

{if tool_type == cli:}
Run command:
```bash
{command}
```
Check exit code. Parse stdout for: {data}
Handle: non-zero exit, command not found

{if tool_type == db:}
Connect to database using `{ENV_VAR}`.
Query:
```sql
{SQL query}
```
Handle: connection error, empty result set, constraint violation

{if tool_type == llm:}
Call LLM with prompt:
"{instruction for the model}"
Model: {model name or default}
Expected output format: {json/text/classification}
Parse and validate the response before using.
Handle: rate limit, malformed response, timeout

{if tool_type == file:}
Read/write file at: {path}
Format: {JSON/CSV/markdown/YAML}
{if write:} Validate data before writing. Create backup if overwriting.
{if read:} Handle: file not found, invalid format, empty file

{if tool_type == browser:}
Navigate to: {URL}
Wait for: {selector or page load}
Extract: {data from page}
Handle: page timeout, element not found, CAPTCHA

{if tool_type == data-pipeline:}
Input: {source — file, API response, DB query result}
Transform:
1. {operation 1 — parse, filter, map, aggregate}
2. {operation 2}
Output: {destination — file, DB, API}
Handle: malformed input rows, type mismatches

{if tool_type == notification:}
Send to: {channel — Telegram/Slack/email/SMS}
Method: {API endpoint or webhook URL}
Content template:
"{message template with {variables}}"
Handle: delivery failure, rate limit

{if tool_type == cron:}
Schedule: {cron expression or interval}
On trigger: {what action to perform}
Handle: missed execution, overlap with previous run

{if tool_type == auth:}
Auth type: {OAuth/API key/JWT/basic}
Flow: {describe auth steps}
Token storage: {where — env var, file, memory}
Refresh strategy: {when and how to refresh}
Handle: token expiry, invalid credentials

{if tool_type == infra:}
Target: {service/server/container}
Action: {deploy/scale/restart/health-check}
Pre-check: {verify current state before action}
Rollback: {strategy if action fails}
Handle: timeout, partial failure, rollback failure

{if tool_type == custom:}
{Detailed instructions from spec.steps[].details}
Handle: {appropriate error handling}

### Step N: Report Results
Summarize what was done:
- {count} items processed
- {count} succeeded / {count} failed
- Any errors or warnings
Notify user via {preferred channel}.

## Rules
- {Safety rule — e.g., never pay unverified invoices}
- {Business rule — e.g., confirm amounts over threshold}
- Never hardcode credentials — always reference ENV vars by name
- Always report failures, not just successes
- {Domain-specific rules}

## Error Handling
- API timeout: retry up to 3 times with exponential backoff
- Auth failure: attempt token refresh, then notify user
- Invalid data: log the error, skip the item, continue processing
- Critical failure: halt execution, notify user immediately

{if references needed:}
## References
See `{baseDir}/references/{filename}.md` for {what it contains}.
```

---

## Notes for the Agent

- Keep the generated SKILL.md under 500 lines
- The description must be at least 20 words with specific trigger phrases
- The `metadata` field must be a single-line JSON string
- Every ENV var mentioned in the body must also be in `metadata.openclaw.requires.env`
- Adapt the template — not every section is needed for every skill
- Simple skills may have just 2-3 steps and minimal rules
- Complex multi-tool skills should have detailed error handling per step
