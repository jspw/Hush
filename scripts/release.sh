#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$PROJECT_DIR/Hush.xcodeproj}"
PROJECT_FILE="$PROJECT_PATH/project.pbxproj"
APP_NAME="${APP_NAME:-Hush}"
APP_BASENAME="${APP_NAME%.app}"
DRAFT_RELEASE="${DRAFT_RELEASE:-0}"
DMG_PATH_OVERRIDE="${DMG_PATH:-}"

usage() {
  cat <<EOF
Usage: $0 [--draft]

Publishes a release from the current project version/build, commits the
pending version bump, tags the release, pushes branch and tag, and creates
the GitHub release.

This script does not build artifacts. Run scripts/build-dmg.sh first.

Options:
  --draft   Create the GitHub release as a draft instead of publishing it.
  -h, --help
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: $1 is required."
    exit 1
  fi
}

project_setting_value() {
  local key="$1"
  sed -n "s/.*${key} = \\([^;]*\\);/\\1/p" "$PROJECT_FILE" | head -n 1
}

ensure_clean_worktree() {
  local status_lines
  local path
  local release_change_found=0

  status_lines="$(git status --porcelain)"
  if [ -z "$status_lines" ]; then
    echo "Error: no pending release commit found."
    echo "Update the project version/build first, then run this script."
    exit 1
  fi

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    path="${line:3}"
    if [ "$path" = "Hush.xcodeproj/project.pbxproj" ]; then
      release_change_found=1
      continue
    fi

    echo "Error: found unrelated working tree change: $path"
    echo "Release publishing expects only Hush.xcodeproj/project.pbxproj to be pending."
    exit 1
  done <<< "$status_lines"

  if [ "$release_change_found" != "1" ]; then
    echo "Error: Hush.xcodeproj/project.pbxproj is not modified."
    echo "Bump the release version/build first, then run this script."
    exit 1
  fi
}

POSITIONAL_ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --draft)
      DRAFT_RELEASE=1
      shift
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

if [ "${#POSITIONAL_ARGS[@]}" -ne 0 ]; then
  echo "Error: unexpected positional arguments."
  usage
  exit 1
fi

require_command git
require_command gh

if [ ! -d "$PROJECT_PATH" ]; then
  echo "Error: project not found at $PROJECT_PATH"
  exit 1
fi

if [ ! -f "$PROJECT_FILE" ]; then
  echo "Error: project file not found at $PROJECT_FILE"
  exit 1
fi

ensure_clean_worktree

if ! gh auth status >/dev/null 2>&1; then
  echo "Error: GitHub CLI is not authenticated. Run 'gh auth login' first."
  exit 1
fi

CURRENT_BRANCH="$(git branch --show-current)"
if [ -z "$CURRENT_BRANCH" ]; then
  echo "Error: could not determine current git branch."
  exit 1
fi

MARKETING_VERSION="$(project_setting_value MARKETING_VERSION)"
CURRENT_PROJECT_VERSION="$(project_setting_value CURRENT_PROJECT_VERSION)"

if [ -z "$MARKETING_VERSION" ] || [ -z "$CURRENT_PROJECT_VERSION" ]; then
  echo "Error: could not read MARKETING_VERSION/CURRENT_PROJECT_VERSION from $PROJECT_FILE"
  exit 1
fi

RELEASE_TAG="v$MARKETING_VERSION"
if git rev-parse "$RELEASE_TAG" >/dev/null 2>&1; then
  echo "Error: git tag $RELEASE_TAG already exists."
  exit 1
fi

echo "Branch: $CURRENT_BRANCH"
echo "Project version: $MARKETING_VERSION"
echo "Current build: $CURRENT_PROJECT_VERSION"
echo ""
if [ -n "$DMG_PATH_OVERRIDE" ]; then
  DMG_PATH="$DMG_PATH_OVERRIDE"
else
  DMG_PATH="$PROJECT_DIR/$APP_BASENAME-$MARKETING_VERSION-$CURRENT_PROJECT_VERSION.dmg"
fi

if [ ! -f "$DMG_PATH" ]; then
  echo "Error: expected DMG not found at $DMG_PATH"
  echo "Run scripts/build-dmg.sh first, or set DMG_PATH to an existing artifact."
  exit 1
fi

COMMIT_MESSAGE="Release $RELEASE_TAG (build $CURRENT_PROJECT_VERSION)"
RELEASE_TITLE="$APP_BASENAME $RELEASE_TAG"

echo ""
echo "Creating release commit..."
git add "$PROJECT_FILE"
git commit -m "$COMMIT_MESSAGE"

echo ""
echo "Creating git tag $RELEASE_TAG..."
git tag -a "$RELEASE_TAG" -m "$COMMIT_MESSAGE"

echo ""
echo "Pushing branch $CURRENT_BRANCH..."
git push origin "$CURRENT_BRANCH"

echo ""
echo "Pushing tag $RELEASE_TAG..."
git push origin "$RELEASE_TAG"

echo ""
echo "Creating GitHub release..."
release_args=(
  gh release create
  "$RELEASE_TAG"
  "$DMG_PATH"
  --title "$RELEASE_TITLE"
  --generate-notes
  --target "$CURRENT_BRANCH"
)

if [ "$DRAFT_RELEASE" = "1" ]; then
  release_args+=(--draft)
fi

"${release_args[@]}"

echo ""
echo "Done!"
echo "Tag: $RELEASE_TAG"
echo "DMG: $DMG_PATH"
