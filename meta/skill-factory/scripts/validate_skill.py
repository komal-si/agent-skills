#!/usr/bin/env python3
"""Validates a SKILL.md file against OpenClaw requirements."""

import sys
import re
import json
import os

def extract_frontmatter(content):
    """Extract YAML frontmatter from SKILL.md content."""
    match = re.match(r'^---\n(.*?)\n---\n', content, re.DOTALL)
    if not match:
        return None, content
    fm_text = match.group(1)
    body = content[match.end():]
    return fm_text, body

def parse_frontmatter(fm_text):
    """Parse frontmatter fields manually (no yaml dependency needed)."""
    fields = {}
    current_key = None
    current_value = []

    for line in fm_text.split('\n'):
        # Check for new key: value pair
        key_match = re.match(r'^(\w[\w-]*)\s*:\s*(.*)', line)
        if key_match:
            # Save previous key
            if current_key:
                fields[current_key] = '\n'.join(current_value).strip()
            current_key = key_match.group(1)
            current_value = [key_match.group(2)]
        elif current_key and (line.startswith('  ') or line.startswith('\t')):
            current_value.append(line.strip())
        elif current_key and line.strip() == '':
            current_value.append('')

    # Save last key
    if current_key:
        fields[current_key] = '\n'.join(current_value).strip()

    return fields

def validate(path):
    """Validate a SKILL.md file. Returns list of error strings."""
    errors = []

    if not os.path.exists(path):
        errors.append(f"FILE NOT FOUND: {path}")
        return errors

    with open(path, 'r') as f:
        content = f.read()

    # Check frontmatter exists
    fm_text, body = extract_frontmatter(content)
    if fm_text is None:
        errors.append("MISSING: YAML frontmatter block (--- ... ---)")
        return errors

    # Parse frontmatter
    fields = parse_frontmatter(fm_text)

    # Required: name
    name = fields.get('name', '').strip().strip('"').strip("'")
    if not name:
        errors.append("MISSING: 'name' field in frontmatter")
    elif not re.match(r'^[a-z][a-z0-9-]*$', name):
        errors.append(f"INVALID: name '{name}' must be lowercase kebab-case (a-z, 0-9, hyphens)")
    elif len(name) > 64:
        errors.append(f"INVALID: name '{name}' exceeds 64 character limit")

    # Required: description
    desc = fields.get('description', '').strip().strip('"').strip("'").strip('>')
    desc_clean = ' '.join(desc.split())  # normalize whitespace
    if not desc_clean:
        errors.append("MISSING: 'description' field in frontmatter")
    elif len(desc_clean.split()) < 20:
        errors.append(f"WEAK: description has {len(desc_clean.split())} words — need at least 20 for reliable triggering")
    elif len(desc_clean) > 1024:
        errors.append(f"TOO LONG: description is {len(desc_clean)} chars — max 1024")

    # Optional: metadata (if present, should be valid JSON)
    metadata_raw = fields.get('metadata', '').strip()
    if metadata_raw:
        try:
            meta = json.loads(metadata_raw)
        except json.JSONDecodeError as e:
            errors.append(f"INVALID: metadata is not valid JSON — {e}")

    # Body checks
    body_lines = body.strip().split('\n')

    # Body length
    if len(body_lines) > 500:
        errors.append(f"TOO LONG: body is {len(body_lines)} lines — max 500")

    # Body should have content
    if len(body_lines) < 5:
        errors.append(f"TOO SHORT: body has only {len(body_lines)} lines — add meaningful instructions")

    # No hardcoded secrets
    secret_patterns = [
        (r'sk-[a-zA-Z0-9]{20,}', 'OpenAI API key'),
        (r'ghp_[a-zA-Z0-9]{30,}', 'GitHub PAT'),
        (r'ghs_[a-zA-Z0-9]{30,}', 'GitHub App token'),
        (r'xoxb-[a-zA-Z0-9-]+', 'Slack bot token'),
        (r'xoxp-[a-zA-Z0-9-]+', 'Slack user token'),
        (r'AKIA[A-Z0-9]{16}', 'AWS access key'),
        (r'AIza[a-zA-Z0-9_-]{35}', 'Google API key'),
        (r'-----BEGIN (RSA |EC )?PRIVATE KEY-----', 'Private key'),
    ]
    for pattern, name_hint in secret_patterns:
        if re.search(pattern, body):
            errors.append(f"SECURITY: Possible hardcoded {name_hint} detected in body")

    # Check for angle brackets in description (OpenClaw restriction)
    if '<' in desc_clean or '>' in desc_clean:
        errors.append("INVALID: description must not contain angle brackets (< >)")

    return errors

def main():
    if len(sys.argv) < 2:
        print("Usage: validate_skill.py <path/to/SKILL.md>")
        print("       validate_skill.py <path/to/skill-directory>")
        sys.exit(1)

    path = sys.argv[1]

    # If path is a directory, look for SKILL.md inside
    if os.path.isdir(path):
        path = os.path.join(path, 'SKILL.md')

    errors = validate(path)

    if errors:
        print(f"❌ Validation failed for: {path}")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)
    else:
        print(f"✅ SKILL.md is valid: {path}")
        sys.exit(0)

if __name__ == '__main__':
    main()
