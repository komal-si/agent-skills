#!/usr/bin/env bash
# Security Checker — Run before pushing to GitHub
# Scans the repo for sensitive data that should NOT be committed.
#
# Usage:
#   ./scripts/security-check.sh           # scan entire repo
#   ./scripts/security-check.sh --staged  # scan only staged files
#
# Exit codes:
#   0 = clean
#   1 = sensitive data found

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FOUND=0

echo "🔒 Security Check — Scanning for sensitive data..."
echo "================================================="
echo ""

# Determine which files to scan
if [[ "${1:-}" == "--staged" ]]; then
    FILES=$(git -C "$REPO_ROOT" diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
    echo "Mode: staged files only"
else
    FILES=$(find "$REPO_ROOT" -type f \
        -not -path '*/.git/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/__pycache__/*' \
        -not -name '*.pyc' \
        -not -name 'security-check.sh' \
        | sed "s|^$REPO_ROOT/||")
    echo "Mode: full repo scan"
fi

echo ""

# ---- Check 1: Real API tokens/keys (not placeholders) ----
echo "Check 1: API tokens and keys..."
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    filepath="$REPO_ROOT/$file"
    [[ -f "$filepath" ]] || continue
    # Skip binary files
    file -b --mime "$filepath" 2>/dev/null | grep -q 'text/' || continue

    # Look for patterns that indicate real tokens (not empty placeholders)
    if grep -Pn '(?i)(api[_-]?key|api[_-]?token|secret[_-]?key|access[_-]?token|bot[_-]?token)\s*[:=]\s*["\x27]?[A-Za-z0-9_\-]{20,}' "$filepath" 2>/dev/null | grep -v '\.example' | grep -v 'placeholder' | grep -v '{' | head -5; then
        echo -e "${RED}  ⚠ FOUND in: $file${NC}"
        FOUND=1
    fi
done <<< "$FILES"
[[ $FOUND -eq 0 ]] && echo -e "${GREEN}  ✓ Clean${NC}"

# ---- Check 2: Real email addresses (not example.com) ----
echo ""
echo "Check 2: Real email addresses..."
FOUND_EMAIL=0
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    filepath="$REPO_ROOT/$file"
    [[ -f "$filepath" ]] || continue
    file -b --mime "$filepath" 2>/dev/null | grep -q 'text/' || continue

    # Find emails that are NOT @example.com, @test.com, @gmail.com placeholder
    if grep -Pn '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$filepath" 2>/dev/null | \
        grep -v '@example\.com' | \
        grep -v '@test\.com' | \
        grep -v '@gmail\.com' | \
        grep -v '@placeholder' | \
        grep -v 'user@' | \
        grep -v 'admin@' | \
        grep -v 'noreply@' | \
        grep -v '@anthropic\.com' | \
        grep -v '# e\.g\.' | \
        head -5; then
        echo -e "${RED}  ⚠ Real email in: $file${NC}"
        FOUND=1
        FOUND_EMAIL=1
    fi
done <<< "$FILES"
[[ $FOUND_EMAIL -eq 0 ]] && echo -e "${GREEN}  ✓ Clean${NC}"

# ---- Check 3: Hardcoded usernames/paths ----
echo ""
echo "Check 3: Hardcoded user paths..."
FOUND_PATH=0
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    filepath="$REPO_ROOT/$file"
    [[ -f "$filepath" ]] || continue
    file -b --mime "$filepath" 2>/dev/null | grep -q 'text/' || continue

    # Look for /Users/{name}/ or /home/{name}/ patterns (but not /home/daytona which is the sandbox default)
    if grep -Pn '/Users/[a-zA-Z][a-zA-Z0-9_-]+/' "$filepath" 2>/dev/null | head -3; then
        echo -e "${RED}  ⚠ Hardcoded user path in: $file${NC}"
        FOUND=1
        FOUND_PATH=1
    fi
done <<< "$FILES"
[[ $FOUND_PATH -eq 0 ]] && echo -e "${GREEN}  ✓ Clean${NC}"

# ---- Check 4: .env files with actual values ----
echo ""
echo "Check 4: .env files with real values..."
FOUND_ENV=0
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Only check .env files (not .env.example)
    if [[ "$file" == ".env" || "$file" == *"/.env" ]] && [[ "$file" != *".example"* ]]; then
        echo -e "${RED}  ⚠ REAL .env file found: $file — should NOT be in git!${NC}"
        FOUND=1
        FOUND_ENV=1
    fi
done <<< "$FILES"
[[ $FOUND_ENV -eq 0 ]] && echo -e "${GREEN}  ✓ Clean${NC}"

# ---- Check 5: Telegram bot tokens ----
echo ""
echo "Check 5: Bot tokens..."
FOUND_BOT=0
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    filepath="$REPO_ROOT/$file"
    [[ -f "$filepath" ]] || continue
    file -b --mime "$filepath" 2>/dev/null | grep -q 'text/' || continue

    # Telegram bot token pattern: digits:alphanumeric
    if grep -Pn '[0-9]{8,}:[A-Za-z0-9_-]{30,}' "$filepath" 2>/dev/null | head -3; then
        echo -e "${RED}  ⚠ Bot token pattern in: $file${NC}"
        FOUND=1
        FOUND_BOT=1
    fi
done <<< "$FILES"
[[ $FOUND_BOT -eq 0 ]] && echo -e "${GREEN}  ✓ Clean${NC}"

# ---- Check 6: Private keys ----
echo ""
echo "Check 6: Private keys..."
FOUND_KEY=0
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    filepath="$REPO_ROOT/$file"
    [[ -f "$filepath" ]] || continue

    # Skip validation scripts that contain patterns as strings (not real keys)
    if [[ "$file" == *"validate_skill"* ]] || [[ "$file" == *"security-check"* ]]; then
        continue
    fi

    if grep -l 'BEGIN.*PRIVATE KEY' "$filepath" 2>/dev/null; then
        echo -e "${RED}  ⚠ Private key in: $file${NC}"
        FOUND=1
        FOUND_KEY=1
    fi
done <<< "$FILES"
[[ $FOUND_KEY -eq 0 ]] && echo -e "${GREEN}  ✓ Clean${NC}"

# ---- Check 7: Database connection strings with credentials ----
echo ""
echo "Check 7: Database URLs with passwords..."
FOUND_DB=0
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    filepath="$REPO_ROOT/$file"
    [[ -f "$filepath" ]] || continue
    file -b --mime "$filepath" 2>/dev/null | grep -q 'text/' || continue

    # postgres://user:password@host patterns with actual passwords
    if grep -Pn '(postgres|mysql|mongodb|redis)://[^:]+:[^@\s{]+@' "$filepath" 2>/dev/null | \
        grep -v 'password' | grep -v 'placeholder' | grep -v '{' | head -3; then
        echo -e "${RED}  ⚠ DB URL with credentials in: $file${NC}"
        FOUND=1
        FOUND_DB=1
    fi
done <<< "$FILES"
[[ $FOUND_DB -eq 0 ]] && echo -e "${GREEN}  ✓ Clean${NC}"

# ---- Summary ----
echo ""
echo "================================================="
if [[ $FOUND -eq 0 ]]; then
    echo -e "${GREEN}✅ All checks passed — safe to push${NC}"
    exit 0
else
    echo -e "${RED}❌ Sensitive data found — fix before pushing!${NC}"
    echo ""
    echo "Tips:"
    echo "  - Replace real emails with user@example.com"
    echo "  - Replace real URLs with https://your-service.example.com"
    echo "  - Replace /Users/{name}/ with ~/ or /path/to/"
    echo "  - Keep .env.example values blank (VAR= or VAR=placeholder)"
    echo "  - Never commit .env files (only .env.example)"
    exit 1
fi
