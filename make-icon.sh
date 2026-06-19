#!/usr/bin/env bash
#
# Generate Resources/AppIcon.icns from the existing 1024px master icon.
# Uses sips + iconutil (both ship with Command Line Tools — no full Xcode needed).
#
set -euo pipefail

MASTER="Hush/Assets.xcassets/AppIcon.appiconset/icon_1024.png"
OUT_DIR="Resources"
ICONSET="$(mktemp -d)/AppIcon.iconset"

if [ ! -f "$MASTER" ]; then
  echo "error: master icon not found at $MASTER" >&2
  exit 1
fi

mkdir -p "$ICONSET" "$OUT_DIR"

# size:filename pairs iconutil expects.
sizes=(
  "16:icon_16x16.png"
  "32:icon_16x16@2x.png"
  "32:icon_32x32.png"
  "64:icon_32x32@2x.png"
  "128:icon_128x128.png"
  "256:icon_128x128@2x.png"
  "256:icon_256x256.png"
  "512:icon_256x256@2x.png"
  "512:icon_512x512.png"
  "1024:icon_512x512@2x.png"
)

for pair in "${sizes[@]}"; do
  px="${pair%%:*}"
  name="${pair##*:}"
  sips -z "$px" "$px" "$MASTER" --out "$ICONSET/$name" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$OUT_DIR/AppIcon.icns"
echo "Wrote $OUT_DIR/AppIcon.icns"
