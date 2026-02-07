#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$PROJECT_DIR/build/ClaudeTokenCat.app"

echo "Building ClaudeTokenCat..."

# Build with Swift Package Manager (using Xcode toolchain)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    swift build --package-path "$PROJECT_DIR"

# Create .app bundle
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$PROJECT_DIR/.build/debug/ClaudeTokenCat" "$APP_DIR/Contents/MacOS/ClaudeTokenCat"
cp "$PROJECT_DIR/ClaudeTokenCat/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "Build complete: $APP_DIR"
echo ""
echo "To run:  open $APP_DIR"
echo "To kill: pkill -f ClaudeTokenCat"
