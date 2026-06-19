#!/usr/bin/env bash
#
# Build Hush into a signed menu-bar .app bundle using SwiftPM + Command Line
# Tools only (no full Xcode required).
#
# SwiftPM produces a bare executable; a menu-bar (accessory) app needs a real
# bundle with an Info.plist (LSUIElement, icon) and a stable code signature so
# the Accessibility grant survives rebuilds. Run ./setup-signing.sh once first.
#
set -euo pipefail

APP_NAME="Hush"
BUNDLE_ID="com.hush.app"
EXEC="Hush"
BUILD_DIR=".build/release"
OUT_DIR="build"
APP_DIR="${OUT_DIR}/${APP_NAME}.app"
SIGN_ID="Hush Self-Signed"
ENTITLEMENTS="Hush/Hush.entitlements"

# Version source of truth is the VERSION file; env vars override (used by build-dmg.sh).
if [ -f "VERSION" ]; then
  # shellcheck disable=SC1091
  source "./VERSION"
fi
SHORT_VERSION="${HUSH_MARKETING_VERSION:-${MARKETING_VERSION:-1.5.0}}"
BUILD_VERSION="${HUSH_BUILD_VERSION:-${BUILD_VERSION:-22}}"

echo "==> Building menu-bar app..."
swift build -c release --product "$EXEC"

echo "==> Assembling ${APP_DIR}..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/$EXEC" "$APP_DIR/Contents/MacOS/$EXEC"

# Ensure the .icns exists, then bundle it.
if [ ! -f "Resources/AppIcon.icns" ]; then
  echo "==> AppIcon.icns missing; generating it..."
  ./make-icon.sh
fi
cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>${EXEC}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${SHORT_VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD_VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAccessibilityUsageDescription</key><string>Hush needs Accessibility access to detect open app windows.</string>
</dict>
</plist>
EOF

SIGN_ARGS=(--force --options runtime --identifier "$BUNDLE_ID")
if [ -f "$ENTITLEMENTS" ]; then
  SIGN_ARGS+=(--entitlements "$ENTITLEMENTS")
fi

if security find-identity -v -p codesigning | grep -q "$SIGN_ID"; then
  echo "==> Signing with stable identity: $SIGN_ID"
  codesign "${SIGN_ARGS[@]}" --sign "$SIGN_ID" "$APP_DIR"
else
  echo "==> No stable identity found; ad-hoc signing."
  echo "    (Run ./setup-signing.sh once so the Accessibility grant survives rebuilds.)"
  codesign "${SIGN_ARGS[@]}" --sign - "$APP_DIR"
fi

echo
echo "Built: $APP_DIR"
echo "Install & run:  ./install.sh"
