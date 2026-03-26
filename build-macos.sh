#!/usr/bin/env bash
set -euo pipefail

# Set DEVELOPER_ID to your "Developer ID Application" certificate name, e.g.:
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"
# Leave empty to skip signing and notarization (local builds only).
DEVELOPER_ID="${DEVELOPER_ID:-}"

# Set NOTARYTOOL_PROFILE to your stored notarytool keychain profile name.
# Create one (once) with:
#   xcrun notarytool store-credentials "moonfin-notary" \
#     --apple-id "you@example.com" --team-id "TEAMID" --password "<app-specific-password>"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-}"

ENTITLEMENTS="macos/Runner/Release.entitlements"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Moonfin"
APP_PATH="$REPO_ROOT/build/macos/Build/Products/Release/${APP_NAME}.app"
STAGING_DIR="$REPO_ROOT/build/macos/dmg-staging"
DMG_OUTPUT=""

# Optional local overrides for private values.
PRIVATE_ENV_FILE="$REPO_ROOT/build-macos.private.env"
if [ -f "$PRIVATE_ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$PRIVATE_ENV_FILE"
fi

for cmd in flutter lipo hdiutil; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command not found: $cmd" >&2
    exit 1
  fi
done

APP_VERSION=$(grep '^version:' "$REPO_ROOT/pubspec.yaml" | sed 's/version:[[:space:]]*//' | cut -d'+' -f1 | tr -d '[:space:]')
if [ -z "$APP_VERSION" ]; then
  echo "Error: could not read version from pubspec.yaml" >&2
  exit 1
fi

DMG_OUTPUT="$REPO_ROOT/${APP_NAME}_macOS_v${APP_VERSION}.dmg"

echo "${APP_NAME} version: ${APP_VERSION}"

cd "$REPO_ROOT"

echo "Cleaning previous Flutter outputs..."
flutter clean

echo "Resolving packages..."
flutter pub get

echo "Building macOS release..."
flutter build macos --release

if [ ! -d "$APP_PATH" ]; then
  echo "Error: .app not found at $APP_PATH" >&2
  exit 1
fi

BINARY_PATH="$APP_PATH/Contents/MacOS/$APP_NAME"
ARCHS=$(lipo -archs "$BINARY_PATH" 2>/dev/null || echo "unknown")
echo "Binary architectures: $ARCHS"
if [[ "$ARCHS" != *"arm64"* ]] || [[ "$ARCHS" != *"x86_64"* ]]; then
  echo "Warning: binary is not universal (arm64 + x86_64). Got: $ARCHS" >&2
  echo "         It will only run on the current machine's architecture." >&2
fi

if [ -n "$DEVELOPER_ID" ]; then
  if [ ! -f "$REPO_ROOT/$ENTITLEMENTS" ]; then
    echo "Error: entitlements file not found: $REPO_ROOT/$ENTITLEMENTS" >&2
    exit 1
  fi
  if ! command -v codesign >/dev/null 2>&1; then
    echo "Error: required command not found: codesign" >&2
    exit 1
  fi
  echo "Signing .app with Developer ID..."
  codesign \
    --deep \
    --force \
    --options runtime \
    --entitlements "$REPO_ROOT/$ENTITLEMENTS" \
    --sign "$DEVELOPER_ID" \
    "$APP_PATH"
  codesign --verify --deep --strict "$APP_PATH"
  echo "Code signing complete."
else
  echo "Skipping code signing (DEVELOPER_ID not set)."
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_OUTPUT"

rm -rf "$STAGING_DIR"

if [ -n "$DEVELOPER_ID" ]; then
  codesign --force --sign "$DEVELOPER_ID" "$DMG_OUTPUT"
fi

if [ -n "$DEVELOPER_ID" ] && [ -n "$NOTARYTOOL_PROFILE" ]; then
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "Error: required command not found: xcrun" >&2
    exit 1
  fi
  echo "Submitting DMG for notarization (this may take a few minutes)..."
  xcrun notarytool submit "$DMG_OUTPUT" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait
  echo "Stapling notarization ticket..."
  xcrun stapler staple "$DMG_OUTPUT"
  echo "Notarization complete."
elif [ -n "$DEVELOPER_ID" ]; then
  echo "Skipping notarization (NOTARYTOOL_PROFILE not set)."
  echo "  Users may need to right-click and choose Open to bypass Gatekeeper."
fi

echo "DMG created: $DMG_OUTPUT"
