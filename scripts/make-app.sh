#!/bin/bash
# Builds Todo.app from the Swift package and installs it into ~/Applications.
#   scripts/make-app.sh               build + install
#   scripts/make-app.sh --no-install  build only (build/Todo.app)
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Todo"

APP=build/Todo.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Todo"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ ! -f build/AppIcon.icns ]; then
    swift scripts/make-icon.swift build/AppIcon.iconset >/dev/null
    iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature: fine for running on this Mac, no developer account needed.
codesign --force --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" != "--no-install" ]; then
    # Quit a running copy so the new build replaces it cleanly.
    osascript -e 'tell application id "com.local.todo" to quit' >/dev/null 2>&1 || true
    mkdir -p "$HOME/Applications"
    rm -rf "$HOME/Applications/Todo.app"
    cp -R "$APP" "$HOME/Applications/Todo.app"
    echo "Installed to ~/Applications/Todo.app — open it with: open ~/Applications/Todo.app"
fi
