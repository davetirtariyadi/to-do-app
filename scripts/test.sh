#!/bin/bash
# Runs the unit tests. Extra arguments go to `swift test` (e.g. --filter StoreTests).
#
# With only the Command Line Tools installed, SwiftPM's default build engine
# doesn't pass the Swift Testing macro plugin to the compiler, so @Test and
# @Suite fail with "plugin for module 'TestingMacros' not found". Point the
# compiler at the plugin when it's there; Xcode toolchains find it on their own.
set -euo pipefail
cd "$(dirname "$0")/.."

TOOLCHAIN="$(dirname "$(dirname "$(xcrun --find swift)")")"
PLUGINS="$TOOLCHAIN/lib/swift/host/plugins/testing"

if [ -f "$PLUGINS/libTestingMacros.dylib" ]; then
    exec swift test -Xswiftc -plugin-path -Xswiftc "$PLUGINS" "$@"
else
    exec swift test "$@"
fi
