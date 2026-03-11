# Daytona Deployment Reference

How to deploy an OpenClaw agent system into a Daytona cloud sandbox.

## Prerequisites

- Daytona CLI installed and authenticated (`daytona login`)
- GitHub repo with agent-skills (skills, org folders, agent templates)
- OpenClaw onboarded locally (to copy config patterns)

## Sandbox Creation

```bash
# Create a medium sandbox (4 CPU, 8GB RAM) with no auto-stop
daytona sandbox create --name openclaw --snapshot daytona-medium --auto-stop 0
```

**Snapshot options:**
- `daytona-small` — 2 CPU, 4GB RAM (fine for 1-2 agents)
- `daytona-medium` — 4 CPU, 8GB RAM (recommended for multi-agent)
- `daytona-large` — 8 CPU, 16GB RAM (for heavy workloads)

Use `--auto-stop 0` to keep the sandbox running 24/7. Without it, sandbox stops after 30min of inactivity.

## Initial Setup Inside Sandbox

### 1. Install OpenClaw (if not pre-installed)

```bash
daytona exec {sandbox-id} "npm install -g @anthropic/openclaw"
```

### 2. Clone Agent Skills Repo

```bash
daytona exec {sandbox-id} "git clone https://github.com/{owner}/agent-skills.git /home/daytona/agent-skills"
```

### 3. Run OpenClaw Onboard

```bash
daytona exec {sandbox-id} "openclaw onboard"
```

This is interactive — may need to SSH in:
```bash
daytona ssh {sandbox-id}
openclaw onboard
```

Configure:
- Model: `openai-codex/gpt-5.4` (or preferred model)
- Auth: OAuth with ChatGPT account
- Workspace: `/home/daytona/.openclaw/workspace`

### 4. Configure Telegram Bot

Edit openclaw.json inside sandbox:
```json
"channels": {
  "telegram": {
    "enabled": true,
    "botToken": "{BOT_TOKEN}",
    "allowFrom": ["{USER_TELEGRAM_ID}"],
    "dmPolicy": "allowlist",
    "groupPolicy": "allowlist",
    "streamMode": "partial"
  }
}
```

### 5. Configure Skills Loading

Update `skills.load.extraDirs` to point to the cloned repo:
```json
"skills": {
  "load": {
    "extraDirs": [
      "/home/daytona/agent-skills/meta",
      "/home/daytona/agent-skills/orgs/{org}/skills",
      "/home/daytona/agent-skills/skills"
    ]
  }
}
```

### 6. Copy Workspace Files

Copy the upgraded SOUL.md, AGENTS.md, etc. into the sandbox workspace:
```bash
# These come from your local workspace or are generated fresh
daytona exec {sandbox-id} "cp /home/daytona/agent-skills/workspace-files/SOUL.md /home/daytona/.openclaw/workspace/"
daytona exec {sandbox-id} "cp /home/daytona/agent-skills/workspace-files/AGENTS.md /home/daytona/.openclaw/workspace/"
```

Or write them directly via `daytona exec`.

### 7. Add Skill Entries

For each skill that needs env vars, add to `skills.entries`:
```json
"skills": {
  "entries": {
    "{org}-{skill-name}": {
      "enabled": true,
      "env": {}
    }
  }
}
```

Credentials will be collected via the agent-setup skill after gateway starts.

## Starting the Gateway

### Option A: Foreground (for debugging)
```bash
daytona ssh {sandbox-id}
openclaw gateway run
```

### Option B: Background (for production)
```bash
daytona exec {sandbox-id} "nohup openclaw gateway run > /tmp/gateway.log 2>&1 &"
```

### Option C: Systemd Service (most robust)
```bash
# Create service file
cat > /etc/systemd/user/openclaw-gateway.service << 'EOF'
[Unit]
Description=OpenClaw Gateway
After=network.target

[Service]
ExecStart=/usr/local/share/nvm/current/bin/openclaw gateway run
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user enable openclaw-gateway
systemctl --user start openclaw-gateway
```

## Accessing the Gateway

### Preview URL (for dashboard)
```bash
daytona preview-url {sandbox-id} --port 18789
```

This gives a signed HTTPS URL that proxies to the gateway port.

### Telegram
Once gateway starts with Telegram configured, the bot auto-connects.
No port forwarding needed — Telegram uses polling (outbound connections).

## Workspace Paths Inside Daytona

```
/home/daytona/
├── agent-skills/                     ← cloned GitHub repo
│   ├── meta/                         ← meta-skills (requirement-gatherer, skill-factory, agent-setup)
│   ├── orgs/{org}/skills/            ← org-scoped skills
│   ├── orgs/{org}/agent-templates/   ← deployment configs
│   └── daytona/                      ← this deployment reference + setup.sh
├── workspaces/                       ← all agent workspaces (runtime data)
│   ├── main/                         ← main agent workspace (symlinked)
│   └── {org}-{agent}-workspace/      ← other agent workspaces
└── .openclaw/                        ← OpenClaw config + state
    ├── openclaw.json                 ← main config (with credentials)
    ├── workspace → /home/daytona/.openclaw/workspace  ← default workspace
    └── agents/                       ← agent session data
```

## Updating Skills

After pushing new skills to GitHub:
```bash
daytona exec {sandbox-id} "cd /home/daytona/agent-skills && git pull origin main"
```

OpenClaw's file watcher picks up new SKILL.md files in extraDirs automatically.
No gateway restart needed for skill-only changes.

For config changes (agents, bindings, cron):
```bash
daytona exec {sandbox-id} "openclaw gateway restart"
```

## Monitoring

### Check gateway logs
```bash
daytona exec {sandbox-id} "tail -50 /tmp/gateway.log"
```

### Check loaded skills
```bash
daytona exec {sandbox-id} "openclaw skills list"
```

### Check agent status
```bash
daytona exec {sandbox-id} "openclaw agents list"
```

## Troubleshooting

### Gateway won't start
- Check if port 18789 is already in use: `lsof -i :18789`
- Check auth config: `cat ~/.openclaw/openclaw.json | jq .auth`
- Try `openclaw gateway run --verbose` for detailed logs

### Telegram bot not responding
- Verify bot token: `curl https://api.telegram.org/bot{TOKEN}/getMe`
- Check allowFrom includes your Telegram user ID
- Check gateway is actually running: `ps aux | grep openclaw`

### Skills not loading
- Verify extraDirs paths exist: `ls /home/daytona/agent-skills/meta/`
- Check skill format: `openclaw skills list` shows errors for malformed skills
- Check SKILL.md frontmatter YAML is valid

### Sandbox stops unexpectedly
- If auto-stop is not 0: `daytona sandbox create --auto-stop 0`
- Check sandbox status: `daytona sandbox info {id}`
- Restart: `daytona start {id}`
