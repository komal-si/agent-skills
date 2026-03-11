#!/usr/bin/env bash
# Daytona Bootstrap Script for OpenClaw Agent Builder
# Creates a sandbox, clones the agent-skills repo, and sets up OpenClaw.
#
# Usage:
#   ./setup.sh [sandbox-name] [github-repo-url]
#
# Defaults:
#   sandbox-name: openclaw
#   github-repo-url: https://github.com/komal-si/agent-skills.git

set -euo pipefail

SANDBOX_NAME="${1:-openclaw}"
REPO_URL="${2:-https://github.com/komal-si/agent-skills.git}"
SNAPSHOT="daytona-medium"

echo "🚀 OpenClaw Daytona Setup"
echo "========================="
echo "Sandbox: $SANDBOX_NAME"
echo "Repo: $REPO_URL"
echo "Snapshot: $SNAPSHOT"
echo ""

# Step 1: Check Daytona CLI
if ! command -v daytona &> /dev/null; then
    echo "❌ Daytona CLI not found. Install: brew install daytonaio/cli/daytona"
    exit 1
fi

echo "✓ Daytona CLI found: $(daytona version 2>/dev/null | head -1)"

# Step 2: Check if sandbox already exists
EXISTING=$(daytona list 2>/dev/null | grep "$SANDBOX_NAME" || true)
if [ -n "$EXISTING" ]; then
    echo "⚠️  Sandbox '$SANDBOX_NAME' already exists:"
    echo "$EXISTING"
    echo ""
    read -p "Delete and recreate? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing sandbox..."
        daytona delete "$SANDBOX_NAME" --force 2>/dev/null || true
    else
        echo "Using existing sandbox."
        SANDBOX_ID=$(daytona list 2>/dev/null | grep "$SANDBOX_NAME" | awk '{print $1}' | head -1)
    fi
fi

# Step 3: Create sandbox (if not reusing)
if [ -z "${SANDBOX_ID:-}" ]; then
    echo ""
    echo "📦 Creating Daytona sandbox..."
    daytona sandbox create --name "$SANDBOX_NAME" --snapshot "$SNAPSHOT" --auto-stop 0
    SANDBOX_ID=$(daytona list 2>/dev/null | grep "$SANDBOX_NAME" | awk '{print $1}' | head -1)
fi

echo "✓ Sandbox ID: $SANDBOX_ID"

# Step 4: Check if OpenClaw is installed
echo ""
echo "🔍 Checking OpenClaw in sandbox..."
OC_CHECK=$(daytona exec "$SANDBOX_ID" "which openclaw" 2>/dev/null || echo "not found")
if [[ "$OC_CHECK" == *"not found"* ]]; then
    echo "Installing OpenClaw..."
    daytona exec "$SANDBOX_ID" "npm install -g @anthropic/openclaw" 2>/dev/null
else
    echo "✓ OpenClaw already installed"
fi

# Step 5: Clone repo
echo ""
echo "📂 Cloning agent-skills repo..."
daytona exec "$SANDBOX_ID" "rm -rf /home/daytona/agent-skills && git clone $REPO_URL /home/daytona/agent-skills" 2>/dev/null
echo "✓ Repo cloned to /home/daytona/agent-skills"

# Step 6: Create workspaces directory
echo ""
echo "📁 Creating workspace directories..."
daytona exec "$SANDBOX_ID" "mkdir -p /home/daytona/workspaces/main" 2>/dev/null
echo "✓ Workspace directories created"

# Step 7: Prompt for manual steps
echo ""
echo "========================================="
echo "✅ Sandbox is ready!"
echo "========================================="
echo ""
echo "Next steps (SSH in to complete):"
echo ""
echo "  daytona ssh $SANDBOX_ID"
echo ""
echo "Then inside the sandbox:"
echo ""
echo "  1. Run OpenClaw onboard:"
echo "     openclaw onboard"
echo ""
echo "  2. Configure Telegram bot token in openclaw.json"
echo ""
echo "  3. Update skills.load.extraDirs to point to repo:"
echo '     "extraDirs": ['
echo '       "/home/daytona/agent-skills/meta",'
echo '       "/home/daytona/agent-skills/orgs/{org}/skills"'
echo '     ]'
echo ""
echo "  4. Start gateway:"
echo "     openclaw gateway run"
echo ""
echo "  5. Get preview URL (from your local machine):"
echo "     daytona preview-url $SANDBOX_ID --port 18789"
echo ""
echo "For automated setup, the agent-setup skill can handle"
echo "credential collection via Telegram after gateway starts."
