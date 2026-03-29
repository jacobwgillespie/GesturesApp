#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
METADATA_FILE="$ROOT_DIR/packaging-metadata.json"

read_metadata() {
  /usr/bin/plutil -extract "$1" raw -o - "$METADATA_FILE"
}

APP_NAME="$(read_metadata appBundleName)"
EXECUTABLE_NAME="$(read_metadata executableProductName)"
BUNDLE_ID="$(read_metadata bundleIdentifier)"
MINIMUM_SYSTEM_VERSION="$(read_metadata minimumMacOSVersion)"

APP_PATH="${1:-$ROOT_DIR/.build/${APP_NAME}.app}"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$APP_NAME"
ICON_PATH="$APP_PATH/Contents/Resources/AppIcon.icns"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Info.plist not found: $INFO_PLIST" >&2
  exit 1
fi

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "Executable not found: $EXECUTABLE_PATH" >&2
  exit 1
fi

if [[ ! -f "$ICON_PATH" ]]; then
  echo "App icon not found: $ICON_PATH" >&2
  exit 1
fi

extract_plist_value() {
  /usr/bin/plutil -extract "$1" raw -o - "$INFO_PLIST"
}

[[ "$(extract_plist_value CFBundleName)" == "$APP_NAME" ]]
[[ "$(extract_plist_value CFBundleExecutable)" == "$APP_NAME" ]]
[[ "$(extract_plist_value CFBundleIdentifier)" == "$BUNDLE_ID" ]]
[[ "$(extract_plist_value LSMinimumSystemVersion)" == "$MINIMUM_SYSTEM_VERSION" ]]
[[ "$(extract_plist_value LSUIElement)" == "true" ]]

codesign --verify --deep --strict "$APP_PATH" >/dev/null

echo "Verified $APP_PATH"
echo "Executable product: $EXECUTABLE_NAME"
