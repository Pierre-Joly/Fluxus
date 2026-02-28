#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Build a distributable macOS app bundle in dist/.

Usage:
  ./scripts/build-release.sh [options]

Options:
  --install                  Copy dist/Fluxus.app to /Applications/Fluxus.app
  --sign                     Sign the app with DEVELOPER_ID_APPLICATION
  --identity "<name>"        Signing identity override (Developer ID Application: ...)
  -h, --help                 Show this help

Environment variables:
  DEVELOPER_ID_APPLICATION   Signing identity used by --sign
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Fluxus.xcodeproj"
SCHEME="Fluxus"
CONFIGURATION="Release"
DESTINATION="platform=macOS"
DERIVED_DATA_PATH="$ROOT_DIR/.build/DerivedData"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Fluxus"

INSTALL_TO_APPLICATIONS=0
SIGN_APP=0
SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)
      INSTALL_TO_APPLICATIONS=1
      shift
      ;;
    --sign)
      SIGN_APP=1
      shift
      ;;
    --identity)
      if [[ $# -lt 2 ]]; then
        echo "error: --identity requires a value" >&2
        exit 1
      fi
      SIGNING_IDENTITY="$2"
      SIGN_APP=1
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$SIGN_APP" -eq 1 ]] && [[ -z "$SIGNING_IDENTITY" ]]; then
  echo "error: --sign requires DEVELOPER_ID_APPLICATION or --identity." >&2
  exit 1
fi

echo "Building $APP_NAME ($CONFIGURATION)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

PRODUCTS_DIR="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION"
SOURCE_APP="$PRODUCTS_DIR/$APP_NAME.app"
SOURCE_DSYM="$PRODUCTS_DIR/$APP_NAME.app.dSYM"
TARGET_APP="$DIST_DIR/$APP_NAME.app"
TARGET_DSYM="$DIST_DIR/$APP_NAME.app.dSYM"

if [[ ! -d "$SOURCE_APP" ]]; then
  echo "error: Missing build output: $SOURCE_APP" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$TARGET_APP" "$TARGET_DSYM"
/usr/bin/ditto "$SOURCE_APP" "$TARGET_APP"

if [[ -d "$SOURCE_DSYM" ]]; then
  /usr/bin/ditto "$SOURCE_DSYM" "$TARGET_DSYM"
fi

if [[ "$SIGN_APP" -eq 1 ]]; then
  HELPER_PATH="$TARGET_APP/Contents/MacOS/Fluxusctl"
  if [[ -f "$HELPER_PATH" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$HELPER_PATH"
  fi
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$TARGET_APP"
  codesign --verify --deep --strict --verbose=2 "$TARGET_APP"
  echo "Signed app with identity: $SIGNING_IDENTITY"
fi

if [[ "$INSTALL_TO_APPLICATIONS" -eq 1 ]]; then
  INSTALL_PATH="/Applications/$APP_NAME.app"
  /usr/bin/ditto "$TARGET_APP" "$INSTALL_PATH"
  echo "Installed to: $INSTALL_PATH"
fi

echo "App bundle: $TARGET_APP"
