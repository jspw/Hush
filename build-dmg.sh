#!/usr/bin/env bash
#
# Package build/Hush.app into a distributable .dmg.
# Usage: ./build-dmg.sh [version]   (version defaults to the VERSION file)
#
set -euo pipefail

APP_NAME="Hush"
APP="build/${APP_NAME}.app"

# Default the version to the VERSION file's marketing version.
if [ -f "VERSION" ]; then
  # shellcheck disable=SC1091
  source "./VERSION"
fi
VERSION="${1:-${MARKETING_VERSION:-1.5.0}}"

# Always rebuild so the app's embedded version matches the DMG name.
echo "==> Building app at version ${VERSION}..."
HUSH_MARKETING_VERSION="$VERSION" ./build-app.sh

DMG="build/${APP_NAME}-${VERSION}.dmg"
STAGE="build/dmg-stage"

echo "==> Staging DMG contents..."
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating $DMG..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG" >/dev/null

rm -rf "$STAGE"
echo
echo "Built: $DMG"
echo "Open it to verify: open \"$DMG\""
