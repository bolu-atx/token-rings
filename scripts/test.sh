#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# XCTest and Swift Testing ship with Xcode, not the Command Line Tools.
if [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

swift test "$@"
