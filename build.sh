#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

scratch="${PIPFLICK_BUILD_DIR:-$PWD/.build}"
signer="${PIPFLICK_SIGN_IDENTITY:--}"
swift build --scratch-path "$scratch" -c release
bin="$(swift build --scratch-path "$scratch" -c release --show-bin-path)"

app="$scratch/PiP Flick.app"
mkdir -p "$app/Contents/MacOS"
cp Info.plist "$app/Contents/Info.plist"
cp "$bin/PiPFlick" "$app/Contents/MacOS/PiPFlick"
codesign --force --sign "$signer" "$app"
printf '\nBuilt %s\n' "$app"
