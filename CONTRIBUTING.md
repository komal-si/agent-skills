# Contributing Skills

## SKILL.md Format

Every skill must have a `SKILL.md` file with valid YAML frontmatter.

### Required Fields

```yaml
---
name: skill-name          # kebab-case, lowercase, max 64 chars
description: >            # At least 20 words, include trigger phrases
  What the skill does and when to trigger it.
---
```

### Optional Fields

```yaml
metadata: {"openclaw": {"requires": {"env": ["API_KEY"]}, "primaryEnv": "API_KEY", "emoji": "🔧"}}
```

### Rules

- **name**: lowercase letters, digits, hyphens only. Must match `^[a-z][a-z0-9-]*$`
- **description**: at least 20 words. Be specific about trigger phrases. No angle brackets.
- **metadata**: single-line JSON. Use for env var requirements and OpenClaw-specific config.
- **Body**: under 500 lines. Use imperative form ("Call the API", not "You should call the API").
- **No secrets**: never hardcode API keys, tokens, or passwords in SKILL.md.

## Directory Structure

```
skill-name/
├── SKILL.md              # Required
├── scripts/              # Optional — deterministic code
├── references/           # Optional — documentation loaded on demand
└── assets/               # Optional — templates, images, static files
```

## Validation

Before submitting a PR, validate your skill:

```bash
python3 meta/skill-creator/scripts/validate_skill.py skills/your-skill/
```

## Where to Put Skills

- **Meta-skills** (skills that build/manage other skills): `meta/`
- **Domain skills** (all others): `skills/`
