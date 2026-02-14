#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$PROJECT_DIR/build/ClaudeTokenCat.app"

echo "Building ClaudeTokenCat..."

# Xcode.app is required — Xcode Command Line Tools alone lack the macOS SDK
# frameworks (SwiftUI, AppKit, Combine) needed for GUI apps.
if [ ! -d "/Applications/Xcode.app/Contents/Developer" ]; then
    echo "Error: Xcode.app is required to build ClaudeTokenCat."
    echo ""
    echo "The Xcode Command Line Tools don't include the macOS SDK frameworks"
    echo "(SwiftUI, AppKit) needed for GUI apps. Install Xcode from the App Store:"
    echo "  https://apps.apple.com/app/xcode/id497799835"
    echo ""
    echo "After installing, run:"
    echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    swift build --package-path "$PROJECT_DIR"

# Create .app bundle
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$PROJECT_DIR/.build/debug/ClaudeTokenCat" "$APP_DIR/Contents/MacOS/ClaudeTokenCat"
cp "$PROJECT_DIR/ClaudeTokenCat/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/ClaudeTokenCat/Assets.xcassets/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

# Inject version from latest git tag (e.g. v1.1.0 → 1.1.0) into the .app bundle
VERSION=$(git -C "$PROJECT_DIR" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
if [ -n "$VERSION" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_DIR/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP_DIR/Contents/Info.plist"
    echo "Version: $VERSION"
fi

echo "Build complete: $APP_DIR"
echo ""
echo "To run:  open $APP_DIR"
echo "To kill: pkill -f ClaudeTokenCat"
