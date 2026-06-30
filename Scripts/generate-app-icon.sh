#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT/docs/assets/logo.svg"
ICONSET="$ROOT/build/AppIcon.iconset"
OUT="$ROOT/ClipboardArchivio/Resources/AppIcon.icns"

if [[ ! -f "$SVG" ]]; then
  echo "error: logo not found at $SVG" >&2
  exit 1
fi

mkdir -p "$ICONSET" "$(dirname "$OUT")"
rm -f "$ICONSET"/*.png

for size in 16 32 128 256 512; do
  rsvg-convert -w "$size" -h "$size" "$SVG" -o "$ICONSET/icon_${size}x${size}.png"
  rsvg-convert -w "$((size * 2))" -h "$((size * 2))" "$SVG" -o "$ICONSET/icon_${size}x${size}@2x.png"
done

iconutil -c icns "$ICONSET" -o "$OUT"
echo "$OUT"