#!/bin/bash
# Sets up a launchd agent that runs scripts/auto-update.sh from this checkout
# (which must be on main) every 5 minutes and whenever a local branch ref changes.
#   scripts/install-auto-update.sh              install or refresh the agent
#   scripts/install-auto-update.sh --uninstall  remove it
# Log: ~/Library/Logs/todo-auto-update.log
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL=com.local.todo.autoupdate
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true

if [ "${1:-}" = "--uninstall" ]; then
    rm -f "$PLIST"
    echo "Removed $LABEL."
    exit 0
fi

if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
    echo "Run this from the checkout that stays on main (e.g. ~/Projects/todo-window-main)." >&2
    exit 1
fi

REPO="$(pwd)"
# Refs are shared by every worktree, so this sees merges made in any of them.
REFS="$(cd "$(git rev-parse --git-common-dir)" && pwd)/refs/heads"

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$REPO/scripts/auto-update.sh</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>WatchPaths</key>
    <array>
        <string>$REFS</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/todo-auto-update.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/todo-auto-update.log</string>
</dict>
</plist>
EOF

launchctl bootstrap "$DOMAIN" "$PLIST"
echo "Installed $LABEL. It rebuilds Todo.app when main changes. Log: ~/Library/Logs/todo-auto-update.log"
