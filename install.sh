#!/usr/bin/env bash
#
# Install the built Hush.app into /Applications and launch it.
# Run ./build-app.sh first.
#
set -euo pipefail

APP_NAME="Hush"
APP_DIR="build/${APP_NAME}.app"
DEST="/Applications/${APP_NAME}.app"

if [ ! -d "$APP_DIR" ]; then
  echo "error: $APP_DIR not found. Run ./build-app.sh first." >&2
  exit 1
fi

echo "==> Quitting any running instance..."
osascript -e 'tell application "Hush" to quit' >/dev/null 2>&1 || true
pkill -x Hush >/dev/null 2>&1 || true

echo "==> Installing to ${DEST}..."
rm -rf "$DEST"
cp -R "$APP_DIR" "$DEST"

echo "==> Launching..."
open "$DEST"

echo "Done. If prompted, grant Accessibility in System Settings > Privacy & Security."
