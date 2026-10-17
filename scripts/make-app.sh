#!/bin/bash
# Builds Todo.app from the Swift package and installs it into ~/Applications.
#   scripts/make-app.sh               build + install
#   scripts/make-app.sh --no-install  build only (build/Todo.app)
#
# Only main installs. On any other branch this builds "Todo Dev"
# (com.local.todo.dev), which keeps its data in Todo-dev/ and is never installed.
set -euo pipefail
cd "$(dirname "$0")/.."

BRANCH="$(git rev-parse --abbrev-ref HEAD)"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Todo"

APP=build/Todo.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Todo"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ "$BRANCH" != "main" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.local.todo.dev" \
        -c "Set :CFBundleName Todo Dev" -c "Set :CFBundleDisplayName Todo Dev" "$APP/Contents/Info.plist"
fi

if [ ! -f build/AppIcon.icns ]; then
    swift scripts/make-icon.swift build/AppIcon.iconset >/dev/null
    iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature: fine for running on this Mac, no developer account needed.
codesign --force --sign - "$APP"
echo "Built $APP"

if [ "$BRANCH" != "main" ]; then
    echo "On '$BRANCH', so this is a dev build and was not installed. Run it with: open $APP"
elif [ "${1:-}" != "--no-install" ]; then
    # Quit a running copy so the new build replaces it cleanly.
    osascript -e 'tell application id "com.local.todo" to quit' >/dev/null 2>&1 || true
    mkdir -p "$HOME/Applications"
    rm -rf "$HOME/Applications/Todo.app"
    cp -R "$APP" "$HOME/Applications/Todo.app"
    echo "Installed to ~/Applications/Todo.app — open it with: open ~/Applications/Todo.app"
fi
