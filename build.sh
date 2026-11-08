#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

scratch="${FLICKAWAY_BUILD_DIR:-$PWD/.build}"
signer="${FLICKAWAY_SIGN_IDENTITY:--}"
swift build --scratch-path "$scratch" -c release
bin="$(swift build --scratch-path "$scratch" -c release --show-bin-path)"

app="$scratch/Flick Away.app"
mkdir -p "$app/Contents/MacOS"
cp Info.plist "$app/Contents/Info.plist"
cp "$bin/FlickAway" "$app/Contents/MacOS/FlickAway"
codesign --force --sign "$signer" "$app"
printf '\nBuilt %s\n' "$app"
