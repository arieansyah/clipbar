#!/usr/bin/env bash
# Membuat Resources/AppIcon.icns dari Tools/make_icon.swift
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build Resources
swift Tools/make_icon.swift build/icon_1024.png

ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z "$s" "$s" build/icon_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z "$d" "$d" build/icon_1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
cp build/icon_1024.png docs/icon.png 2>/dev/null || { mkdir -p docs && cp build/icon_1024.png docs/icon.png; }
echo "✓ Resources/AppIcon.icns"
