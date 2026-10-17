#!/bin/bash
# Rebuilds and reinstalls Todo.app whenever main moves, whether from a merge
# here or one pushed to GitHub. The launchd agent from
# scripts/install-auto-update.sh runs this; it's also safe to run by hand.
set -euo pipefail
cd "$(dirname "$0")/.."

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$BRANCH" != "main" ]; then
    log "On '$BRANCH', not main; nothing to do."
    exit 0
fi

# Pick up merges made on GitHub. If offline, just check local main.
if git fetch --quiet origin main 2>/dev/null; then
    git merge --ff-only --quiet origin/main 2>/dev/null ||
        log "Local main can't fast-forward to origin/main; building local main as is."
fi

HEAD_REV="$(git rev-parse HEAD)"
mkdir -p build
[ "$(cat build/installed-rev 2>/dev/null)" = "$HEAD_REV" ] && exit 0
# Don't retry a commit that already failed to build every few minutes.
[ "$(cat build/failed-rev 2>/dev/null)" = "$HEAD_REV" ] && exit 0

log "Building ${HEAD_REV:0:7}"
WAS_RUNNING="$(osascript -e 'application id "com.local.todo" is running' 2>/dev/null || echo false)"

if scripts/make-app.sh; then
    echo "$HEAD_REV" > build/installed-rev
    rm -f build/failed-rev
    [ "$WAS_RUNNING" = "true" ] && open "$HOME/Applications/Todo.app"
    osascript -e "display notification \"Updated to ${HEAD_REV:0:7}\" with title \"Todo\"" >/dev/null 2>&1 || true
    log "Installed ${HEAD_REV:0:7}"
else
    echo "$HEAD_REV" > build/failed-rev
    osascript -e "display notification \"Build of ${HEAD_REV:0:7} failed; kept the old version\" with title \"Todo\"" >/dev/null 2>&1 || true
    log "Build of ${HEAD_REV:0:7} failed; the installed app is unchanged."
    exit 1
fi
