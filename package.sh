#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ClaudeTokenCat"
APP_DIR="$PROJECT_DIR/build/$APP_NAME.app"
DMG_DIR="$PROJECT_DIR/build/dmg"
DMG_PATH="$PROJECT_DIR/build/$APP_NAME.dmg"

# Build the app first
"$PROJECT_DIR/build.sh"

# Clean previous DMG artifacts
rm -rf "$DMG_DIR"
rm -f "$DMG_PATH"

# Stage the .app in a temporary folder
mkdir -p "$DMG_DIR"
cp -R "$APP_DIR" "$DMG_DIR/"

# Create the .dmg
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# Clean up staging folder
rm -rf "$DMG_DIR"

echo ""
echo "DMG created: $DMG_PATH"
echo "Upload this to a GitHub Release."
