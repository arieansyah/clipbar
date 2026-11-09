#!/usr/bin/env bash
# Build ClipBar.app ke folder build/
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/ClipBar.app"

[ -f Resources/AppIcon.icns ] || ./scripts/make_icon.sh

echo "→ Compile (release)…"
swift build -c release

echo "→ Menyusun bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/ClipBar" "$APP/Contents/MacOS/ClipBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "→ Code sign (ad-hoc)…"
codesign --force --sign - --identifier id.girex.clipbar "$APP"

echo "✓ $APP"
