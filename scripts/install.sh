#!/usr/bin/env bash
# Build lalu pasang ClipBar ke /Applications dan jalankan.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build.sh

DEST="/Applications/ClipBar.app"

if pgrep -x ClipBar >/dev/null; then
  echo "→ Menutup ClipBar yang sedang berjalan…"
  osascript -e 'quit app id "id.girex.clipbar"' >/dev/null 2>&1 || true
  sleep 1
  pkill -x ClipBar 2>/dev/null || true
fi

if [ -d "$DEST" ] && [ ! -d build/backup/ClipBar-previous.app ]; then
  echo "→ Mencadangkan versi lama ke build/backup/…"
  mkdir -p build/backup
  cp -R "$DEST" build/backup/ClipBar-previous.app
fi

echo "→ Memasang ke $DEST…"
rm -rf "$DEST"
cp -R build/ClipBar.app "$DEST"

# Segarkan cache ikon Launch Services
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST" || true
touch "$DEST"

open "$DEST"
echo "✓ ClipBar terpasang dan berjalan. Tekan ⇧⌘V untuk membuka."
