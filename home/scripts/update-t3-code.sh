#!/usr/bin/env bash
set -euo pipefail

CHANNEL=${1:-}
case "$CHANNEL" in
  stable)
    APP_NAME="T3 Code (Alpha).app"
    ;;
  nightly)
    APP_NAME="T3 Code (Nightly).app"
    ;;
  *)
    echo "usage: $0 stable|nightly" >&2
    exit 2
    ;;
esac

APP_PATH="/Applications/$APP_NAME"
if [ ! -d "$APP_PATH" ]; then
  echo "$APP_NAME is not installed; skipping"
  exit 0
fi

if [ "$CHANNEL" = stable ]; then
  TAG=$(gh api repos/pingdotgg/t3code/releases/latest --jq .tag_name)
else
  TAG=$(gh api 'repos/pingdotgg/t3code/releases?per_page=100' \
    --jq '[.[] | select(.prerelease and (.tag_name | contains("-nightly.")))][0].tag_name')
fi
VERSION=${TAG#v}
CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  "$APP_PATH/Contents/Info.plist")
if [ "$CURRENT_VERSION" = "$VERSION" ]; then
  echo "$APP_NAME is already at $VERSION"
  exit 0
fi

case "$(uname -m)" in
  arm64) ARCH=arm64 ;;
  x86_64) ARCH=x64 ;;
  *)
    echo "unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

ASSET="T3-Code-$VERSION-$ARCH.dmg"
TEMP_DIR=$(mktemp -d)
MOUNT_DIR="$TEMP_DIR/mount"
DMG_PATH="$TEMP_DIR/$ASSET"
STAGE_DIR=""
MOUNTED=0

cleanup() {
  if [ "$MOUNTED" -eq 1 ]; then
    hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
  fi
  rm -rf "$TEMP_DIR"
  if [ -n "$STAGE_DIR" ]; then
    rm -rf "$STAGE_DIR"
  fi
}
trap cleanup EXIT

mkdir "$MOUNT_DIR"
gh release download "$TAG" --repo pingdotgg/t3code --pattern "$ASSET" --dir "$TEMP_DIR"
hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT_DIR" "$DMG_PATH" >/dev/null
MOUNTED=1

SOURCE_APP="$MOUNT_DIR/$APP_NAME"
SOURCE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  "$SOURCE_APP/Contents/Info.plist")
if [ "$SOURCE_VERSION" != "$VERSION" ]; then
  echo "downloaded $SOURCE_VERSION, expected $VERSION" >&2
  exit 1
fi
codesign --verify --deep --strict "$SOURCE_APP"
spctl --assess --type execute "$SOURCE_APP"

STAGE_DIR=$(mktemp -d "/Applications/.t3-code-update.XXXXXX")
STAGED_APP="$STAGE_DIR/$APP_NAME"
BACKUP_APP="$STAGE_DIR/current.app"
ditto "$SOURCE_APP" "$STAGED_APP"

APP_TITLE=${APP_NAME%.app}
is_running() {
  while IFS= read -r command; do
    if [ "$command" = "$APP_PATH/Contents/MacOS/$APP_TITLE" ]; then
      return 0
    fi
  done < <(ps -axo command=)
  return 1
}

WAS_RUNNING=0
if is_running; then
  WAS_RUNNING=1
  osascript -e "tell application \"$APP_TITLE\" to quit"
  for _ in {1..30}; do
    is_running || break
    sleep 1
  done
  if is_running; then
    echo "$APP_TITLE did not quit; update cancelled" >&2
    exit 1
  fi
fi

mv "$APP_PATH" "$BACKUP_APP"
if ! mv "$STAGED_APP" "$APP_PATH"; then
  mv "$BACKUP_APP" "$APP_PATH"
  if [ "$WAS_RUNNING" -eq 1 ]; then
    open -gj "$APP_PATH"
  fi
  exit 1
fi

if [ "$WAS_RUNNING" -eq 1 ]; then
  open -gj "$APP_PATH"
fi
echo "Updated $APP_NAME from $CURRENT_VERSION to $VERSION"
