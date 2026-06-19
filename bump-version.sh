#!/usr/bin/env bash
#
# Bump the version before cutting a release.
# Usage: ./bump-version.sh <version>     e.g. ./bump-version.sh 1.6.0
#
# Hush keeps two numbers:
#   - MARKETING_VERSION  (CFBundleShortVersionString, e.g. 1.6.0) — set from the arg
#   - BUILD_VERSION      (CFBundleVersion, monotonic) — auto-incremented
#
# The VERSION file is the single source of truth (read by build-app.sh). This
# script also updates Hush.xcodeproj so the Xcode build path stays in sync.
#
set -euo pipefail

VERSION="${1:?usage: ./bump-version.sh <version>   e.g. ./bump-version.sh 1.6.0}"
VERSION="${VERSION#v}"  # accept either 1.6.0 or v1.6.0

VERSION_FILE="VERSION"
PBXPROJ="Hush.xcodeproj/project.pbxproj"

# Current build number from the VERSION file (default 0 if absent), then +1.
CURRENT_BUILD=0
if [ -f "$VERSION_FILE" ]; then
  # shellcheck disable=SC1090
  source "./$VERSION_FILE"
  CURRENT_BUILD="${BUILD_VERSION:-0}"
fi
NEW_BUILD=$((CURRENT_BUILD + 1))

cat > "$VERSION_FILE" <<EOF
MARKETING_VERSION=${VERSION}
BUILD_VERSION=${NEW_BUILD}
EOF
echo "Updated $VERSION_FILE -> ${VERSION} (build ${NEW_BUILD})"

# Keep the Xcode project in sync (all Debug + Release config occurrences).
if [ -f "$PBXPROJ" ]; then
  sed -i '' -E "s/(MARKETING_VERSION = )[^;]+;/\1${VERSION};/" "$PBXPROJ"
  sed -i '' -E "s/(CURRENT_PROJECT_VERSION = )[^;]+;/\1${NEW_BUILD};/" "$PBXPROJ"
  echo "Updated $PBXPROJ (MARKETING_VERSION=${VERSION}, CURRENT_PROJECT_VERSION=${NEW_BUILD})"
fi

echo
echo "Next steps:"
echo "  1. Review & commit:   git commit -am \"Release v${VERSION} (build ${NEW_BUILD})\""
echo "  2. Publish the DMG:   ./release.sh ${VERSION}"
