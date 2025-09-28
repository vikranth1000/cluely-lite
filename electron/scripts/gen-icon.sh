#!/usr/bin/env bash
set -euo pipefail

# Generate macOS .icns from build/icon.png
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$ROOT_DIR"

SRC="build/icon.png"
ICONSET="build/app.iconset"
OUT="build/icon.icns"

if [[ ! -f "$SRC" ]]; then
  echo "error: $SRC missing. Place a square PNG here (1024x1024 recommended)." >&2
  exit 1
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sizes=(16 32 128 256 512 1024)
for s in "${sizes[@]}"; do
  sips -s format png "$SRC" --resampleWidth "$s" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
done

cp "$ICONSET/icon_32x32.png" "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png" "$ICONSET/icon_32x32@2x.png" || sips -s format png "$SRC" --resampleWidth 64 --out "$ICONSET/icon_32x32@2x.png" >/dev/null
cp "$ICONSET/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$OUT"
echo "Generated $OUT"

