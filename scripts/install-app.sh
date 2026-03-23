#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Gestures"
EXECUTABLE_NAME="GesturesApp"
BUNDLE_ID="${BUNDLE_ID:-com.jacobwgillespie.gestures}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
CONFIGURATION="${CONFIGURATION:-release}"
BUILD_FLAGS=()

usage() {
  cat <<EOF
Usage: scripts/install-app.sh [--debug] [--release] [--install-dir PATH]

Builds the SwiftPM app, creates ${APP_NAME}.app, and installs it.

Options:
  --debug               Build the debug configuration
  --release             Build the release configuration (default)
  --install-dir PATH    Install destination (default: ~/Applications)
  -h, --help            Show this help

Environment overrides:
  BUNDLE_ID             Bundle identifier (default: ${BUNDLE_ID})
  INSTALL_DIR           Install destination
  CONFIGURATION         debug or release
  SIGNING_IDENTITY      Code signing identity (default: auto-detect, falls back to ad-hoc)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      CONFIGURATION="debug"
      shift
      ;;
    --release)
      CONFIGURATION="release"
      shift
      ;;
    --install-dir)
      INSTALL_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer only supports macOS." >&2
  exit 1
fi

if [[ "$CONFIGURATION" == "release" ]]; then
  BUILD_FLAGS=(-c release)
elif [[ "$CONFIGURATION" == "debug" ]]; then
  BUILD_FLAGS=(-c debug)
else
  echo "Unsupported CONFIGURATION: $CONFIGURATION" >&2
  exit 1
fi

cd "$ROOT_DIR"

echo "Building ${EXECUTABLE_NAME} (${CONFIGURATION})..."
swift build "${BUILD_FLAGS[@]}" --product "$EXECUTABLE_NAME"

BIN_PATH="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"
EXECUTABLE_PATH="${BIN_PATH}/${EXECUTABLE_NAME}"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "Built executable not found at $EXECUTABLE_PATH" >&2
  exit 1
fi

APP_DIR="$ROOT_DIR/.build/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST="$CONTENTS_DIR/Info.plist"
PKGINFO_PATH="$CONTENTS_DIR/PkgInfo"
INSTALLED_APP_DIR="$INSTALL_DIR/${APP_NAME}.app"
SHORT_VERSION="${MARKETING_VERSION:-0.1.0}"
BUILD_VERSION="${CURRENT_PROJECT_VERSION:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"

cat > "$INFO_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${SHORT_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_VERSION}</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>26.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

printf 'APPL????' > "$PKGINFO_PATH"

ASSETS_DIR="$ROOT_DIR/Sources/GesturesApp/Resources/Assets.xcassets"
if [[ -d "$ASSETS_DIR" ]]; then
  echo "Compiling asset catalog..."
  xcrun actool "$ASSETS_DIR" \
    --compile "$RESOURCES_DIR" \
    --platform macosx \
    --minimum-deployment-target 26.0 \
    --app-icon AppIcon \
    --output-partial-info-plist /dev/null 2>/dev/null || true
fi

# Code sign so macOS TCC preserves accessibility permissions across reinstalls.
# A stable designated requirement (based on bundle ID) prevents macOS from treating
# each rebuild as a different app and revoking permissions.
echo "Code signing app bundle..."
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  # Check for any available signing identity
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -oE '"[^"]+"' | head -1 | tr -d '"' || true)"
fi
if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --sign "$SIGNING_IDENTITY" --deep "$APP_DIR"
else
  # Ad-hoc sign with an explicit designated requirement pinned to the bundle ID,
  # so TCC matches on identifier rather than the per-build cdhash.
  codesign --force --sign - \
    -r "=designated => identifier \"$BUNDLE_ID\"" \
    --deep "$APP_DIR"
fi

mkdir -p "$INSTALL_DIR"
echo "Installing to $INSTALLED_APP_DIR..."
rm -rf "$INSTALLED_APP_DIR"
ditto "$APP_DIR" "$INSTALLED_APP_DIR"

echo "Installed ${APP_NAME}.app"
echo "App bundle: $INSTALLED_APP_DIR"
