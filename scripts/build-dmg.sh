#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

PROJECT_PATH="${PROJECT_PATH:-$PROJECT_DIR/Hush.xcodeproj}"
PROJECT_FILE="$PROJECT_PATH/project.pbxproj"
SCHEME="${SCHEME:-Hush}"
CONFIGURATION="${CONFIGURATION:-Release}"
ARCHIVE_ROOT="${ARCHIVE_ROOT:-$PROJECT_DIR/archived}"
ARCHIVE_NAME="${ARCHIVE_NAME:-Hush.xcarchive}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ARCHIVE_ROOT/$ARCHIVE_NAME}"
EXPORT_DIR="${EXPORT_DIR:-$ARCHIVE_ROOT/Hush}"
APP_NAME="${APP_NAME:-Hush.app}"
APP_BASENAME="${APP_NAME%.app}"
APP_PATH="$EXPORT_DIR/$APP_NAME"
DMG_NAME_OVERRIDE="${DMG_NAME:-}"
DMG_PATH_OVERRIDE="${DMG_PATH:-}"
VOLUME_NAME="${VOLUME_NAME:-$APP_BASENAME}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ARCHIVE_ROOT/DerivedData}"
EXPORT_METHOD="${EXPORT_METHOD:-mac-application}"
TEAM_ID="${TEAM_ID:-}"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-0}"
SIGNING_STYLE="${SIGNING_STYLE:-}"
SIGNING_CERTIFICATE="${SIGNING_CERTIFICATE:-}"
MARKETING_VERSION_OVERRIDE="${MARKETING_VERSION:-}"
CURRENT_PROJECT_VERSION_OVERRIDE="${CURRENT_PROJECT_VERSION:-}"
ORIGINAL_MARKETING_VERSION=""
ORIGINAL_PROJECT_VERSION=""
VERSION_SETTINGS_UPDATED=0
BUILD_SUCCEEDED=0
AUTO_INCREMENTED_BUILD=0

TMP_ARCHIVE_PATH="$ARCHIVE_ROOT/.${ARCHIVE_NAME%.xcarchive}.tmp.xcarchive"
TMP_EXPORT_DIR="$ARCHIVE_ROOT/.${APP_BASENAME}.export.tmp"
TMP_EXPORT_OPTIONS="$ARCHIVE_ROOT/.ExportOptions.plist.tmp"
TMP_DMG_PATH="$PROJECT_DIR/.${APP_BASENAME}.tmp.dmg"
LEGACY_TMP_DMG_PATH="$PROJECT_DIR/.${APP_BASENAME}.dmg.tmp.dmg"
TMP_APP_PATH="$TMP_EXPORT_DIR/$APP_NAME"

cleanup() {
  if [ "$VERSION_SETTINGS_UPDATED" = "1" ] && [ "$BUILD_SUCCEEDED" != "1" ] && [ -f "$PROJECT_FILE" ]; then
    update_project_setting "MARKETING_VERSION" "$ORIGINAL_MARKETING_VERSION"
    update_project_setting "CURRENT_PROJECT_VERSION" "$ORIGINAL_PROJECT_VERSION"
  fi
  rm -rf "$TMP_ARCHIVE_PATH" "$TMP_EXPORT_DIR"
  rm -f "$TMP_EXPORT_OPTIONS" "$TMP_DMG_PATH" "$LEGACY_TMP_DMG_PATH"
}

cleanup_old_dmgs() {
  local current_dmg="$1"
  local dmg

  shopt -s nullglob
  for dmg in "$PROJECT_DIR/$APP_BASENAME"*.dmg; do
    if [ "$dmg" != "$current_dmg" ]; then
      rm -f "$dmg"
    fi
  done
  shopt -u nullglob
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: $1 is required."
    exit 1
  fi
}

usage() {
  cat <<EOF
Usage: $0 [version] [build]
       $0 --version <version> [--build <build>]

Examples:
  $0 1.0.1 2
  $0 --version 1.0.1 --build 2

If no build number is provided, the script auto-increments CURRENT_PROJECT_VERSION.
EOF
}

project_setting_value() {
  local key="$1"
  sed -n "s/.*${key} = \\([^;]*\\);/\\1/p" "$PROJECT_FILE" | head -n 1
}

update_project_setting() {
  local key="$1"
  local value="$2"

  SETTING_KEY="$key" SETTING_VALUE="$value" perl -0pi -e '
    my $key = $ENV{SETTING_KEY};
    my $value = $ENV{SETTING_VALUE};
    s/(\Q$key\E = )[^;]+;/${1}${value};/g;
  ' "$PROJECT_FILE"
}

write_export_options() {
  {
    cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>$EXPORT_METHOD</string>
EOF

    if [ -n "$SIGNING_STYLE" ]; then
      cat <<EOF
  <key>signingStyle</key>
  <string>$SIGNING_STYLE</string>
EOF
    fi

    if [ -n "$SIGNING_CERTIFICATE" ]; then
      cat <<EOF
  <key>signingCertificate</key>
  <string>$SIGNING_CERTIFICATE</string>
EOF
    fi

    if [ -n "$TEAM_ID" ]; then
      cat <<EOF
  <key>teamID</key>
  <string>$TEAM_ID</string>
EOF
    fi

    cat <<'EOF'
</dict>
</plist>
EOF
  } >"$TMP_EXPORT_OPTIONS"
}

require_command xcodebuild
require_command hdiutil
require_command plutil
require_command perl

POSITIONAL_ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      if [ "$#" -lt 2 ]; then
        echo "Error: --version requires a value."
        usage
        exit 1
      fi
      MARKETING_VERSION_OVERRIDE="$2"
      shift 2
      ;;
    --build)
      if [ "$#" -lt 2 ]; then
        echo "Error: --build requires a value."
        usage
        exit 1
      fi
      CURRENT_PROJECT_VERSION_OVERRIDE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "Error: unknown option $1"
      usage
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

if [ "${#POSITIONAL_ARGS[@]}" -gt 2 ]; then
  echo "Error: expected at most 2 positional arguments: [version] [build]."
  usage
  exit 1
fi

if [ "${#POSITIONAL_ARGS[@]}" -ge 1 ] && [ -z "$MARKETING_VERSION_OVERRIDE" ]; then
  MARKETING_VERSION_OVERRIDE="${POSITIONAL_ARGS[0]}"
fi

if [ "${#POSITIONAL_ARGS[@]}" -eq 2 ] && [ -z "$CURRENT_PROJECT_VERSION_OVERRIDE" ]; then
  CURRENT_PROJECT_VERSION_OVERRIDE="${POSITIONAL_ARGS[1]}"
fi

if [ ! -d "$PROJECT_PATH" ]; then
  echo "Error: project not found at $PROJECT_PATH"
  exit 1
fi

if [ ! -f "$PROJECT_FILE" ]; then
  echo "Error: project file not found at $PROJECT_FILE"
  exit 1
fi

case "$EXPORT_METHOD" in
  mac-application|developer-id)
    ;;
  *)
    echo "Error: EXPORT_METHOD must be 'mac-application' or 'developer-id'."
    exit 1
    ;;
esac

if [ "$EXPORT_METHOD" = "developer-id" ]; then
  if [ -z "$SIGNING_STYLE" ]; then
    SIGNING_STYLE="automatic"
  fi

  if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "Error: no Developer ID Application signing identity found."
    echo "Install a Developer ID certificate in Xcode Keychain Access or use EXPORT_METHOD=mac-application."
    exit 1
  fi
fi

if [ "$ALLOW_PROVISIONING_UPDATES" != "0" ] && [ "$ALLOW_PROVISIONING_UPDATES" != "1" ]; then
  echo "Error: ALLOW_PROVISIONING_UPDATES must be 0 or 1."
  exit 1
fi

ORIGINAL_MARKETING_VERSION="$(project_setting_value MARKETING_VERSION)"
ORIGINAL_PROJECT_VERSION="$(project_setting_value CURRENT_PROJECT_VERSION)"

if [ -z "$ORIGINAL_MARKETING_VERSION" ] || [ -z "$ORIGINAL_PROJECT_VERSION" ]; then
  echo "Error: could not read MARKETING_VERSION/CURRENT_PROJECT_VERSION from $PROJECT_FILE"
  exit 1
fi

if ! [[ "$ORIGINAL_PROJECT_VERSION" =~ ^[0-9]+$ ]]; then
  echo "Error: CURRENT_PROJECT_VERSION must be numeric. Found: $ORIGINAL_PROJECT_VERSION"
  exit 1
fi

if [ -z "$MARKETING_VERSION_OVERRIDE" ]; then
  MARKETING_VERSION_OVERRIDE="$ORIGINAL_MARKETING_VERSION"
fi

if [ -z "$CURRENT_PROJECT_VERSION_OVERRIDE" ]; then
  CURRENT_PROJECT_VERSION_OVERRIDE="$((ORIGINAL_PROJECT_VERSION + 1))"
  AUTO_INCREMENTED_BUILD=1
fi

if ! [[ "$CURRENT_PROJECT_VERSION_OVERRIDE" =~ ^[0-9]+$ ]]; then
  echo "Error: build number must be numeric. Found: $CURRENT_PROJECT_VERSION_OVERRIDE"
  exit 1
fi

mkdir -p "$ARCHIVE_ROOT"
cleanup
trap cleanup EXIT

update_project_setting "MARKETING_VERSION" "$MARKETING_VERSION_OVERRIDE"
update_project_setting "CURRENT_PROJECT_VERSION" "$CURRENT_PROJECT_VERSION_OVERRIDE"
VERSION_SETTINGS_UPDATED=1

echo "Project: $PROJECT_PATH"
echo "Scheme: $SCHEME"
echo "Configuration: $CONFIGURATION"
echo "Export method: $EXPORT_METHOD"
echo "Version: $MARKETING_VERSION_OVERRIDE"
if [ "$AUTO_INCREMENTED_BUILD" = "1" ]; then
  echo "Build: $CURRENT_PROJECT_VERSION_OVERRIDE (auto-incremented from $ORIGINAL_PROJECT_VERSION)"
else
  echo "Build: $CURRENT_PROJECT_VERSION_OVERRIDE"
fi
if [ -n "$TEAM_ID" ]; then
  echo "Team ID: $TEAM_ID"
fi
echo ""

archive_args=(
  xcodebuild
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "generic/platform=macOS"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -archivePath "$TMP_ARCHIVE_PATH"
  archive
)

if [ "$EXPORT_METHOD" = "developer-id" ]; then
  archive_args+=(CODE_SIGN_STYLE=Automatic)
  if [ -n "$TEAM_ID" ]; then
    archive_args+=(DEVELOPMENT_TEAM="$TEAM_ID")
  fi
  if [ "$ALLOW_PROVISIONING_UPDATES" = "1" ]; then
    archive_args+=(-allowProvisioningUpdates)
  fi
else
  archive_args+=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=)
fi

if [ -n "$MARKETING_VERSION_OVERRIDE" ]; then
  archive_args+=(MARKETING_VERSION="$MARKETING_VERSION_OVERRIDE")
fi

if [ -n "$CURRENT_PROJECT_VERSION_OVERRIDE" ]; then
  archive_args+=(CURRENT_PROJECT_VERSION="$CURRENT_PROJECT_VERSION_OVERRIDE")
fi

echo "Archiving app..."
"${archive_args[@]}"

write_export_options
plutil -lint "$TMP_EXPORT_OPTIONS" >/dev/null

export_args=(
  xcodebuild
  -exportArchive
  -archivePath "$TMP_ARCHIVE_PATH"
  -exportPath "$TMP_EXPORT_DIR"
  -exportOptionsPlist "$TMP_EXPORT_OPTIONS"
)

if [ "$EXPORT_METHOD" = "developer-id" ] && [ "$ALLOW_PROVISIONING_UPDATES" = "1" ]; then
  export_args+=(-allowProvisioningUpdates)
fi

echo ""
echo "Exporting app..."
"${export_args[@]}"

if [ ! -d "$TMP_APP_PATH" ]; then
  echo "Error: exported app not found at $TMP_APP_PATH"
  exit 1
fi

APP_INFO_PLIST="$TMP_APP_PATH/Contents/Info.plist"
APP_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_INFO_PLIST" 2>/dev/null || true)"
APP_BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_INFO_PLIST" 2>/dev/null || true)"

if [ -n "$DMG_NAME_OVERRIDE" ]; then
  DMG_NAME="$DMG_NAME_OVERRIDE"
elif [ -n "$APP_VERSION" ]; then
  DMG_NAME="$APP_BASENAME-$APP_VERSION"
  if [ -n "$APP_BUILD" ] && [ "$APP_BUILD" != "$APP_VERSION" ]; then
    DMG_NAME="$DMG_NAME-$APP_BUILD"
  fi
  DMG_NAME="$DMG_NAME.dmg"
else
  DMG_NAME="$APP_BASENAME.dmg"
fi

if [ -n "$DMG_PATH_OVERRIDE" ]; then
  DMG_PATH="$DMG_PATH_OVERRIDE"
else
  DMG_PATH="$PROJECT_DIR/$DMG_NAME"
fi

echo ""
echo "Creating $DMG_NAME..."
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$TMP_APP_PATH" \
  -ov \
  -format UDZO \
  "$TMP_DMG_PATH"

rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
rm -f "$DMG_PATH"

mv "$TMP_ARCHIVE_PATH" "$ARCHIVE_PATH"
mv "$TMP_EXPORT_DIR" "$EXPORT_DIR"
mv "$TMP_DMG_PATH" "$DMG_PATH"

if [ -z "$DMG_PATH_OVERRIDE" ]; then
  cleanup_old_dmgs "$DMG_PATH"
fi

BUILD_SUCCEEDED=1

echo ""
echo "Done!"
echo "Archive: $ARCHIVE_PATH"
echo "App: $APP_PATH"
echo "DMG: $DMG_PATH"
echo "DMG Size: $(du -h "$DMG_PATH" | cut -f1)"
