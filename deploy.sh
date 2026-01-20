#!/bin/bash
set -e

echo "=== Mactrix Screensaver Deploy Script ==="

# Kill any running screensaver processes and System Settings
echo "Killing screensaver processes and System Settings..."
pkill -f legacyScreenSaver 2>/dev/null || true
pkill -f "Screen Saver" 2>/dev/null || true
pkill -f "System Settings" 2>/dev/null || true

# Wait a moment for processes to terminate
sleep 1

# Build the project
echo "Building..."
cd "$(dirname "$0")"
xcodebuild -project mactrix.xcodeproj -scheme mactrix -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD)" | grep -v "Metadata extraction skipped"

# Check if build succeeded
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "ERROR: Build failed!"
    exit 1
fi

# Find the built product (exclude Index.noindex which contains incomplete builds)
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
SAVER_PATH=$(find "$DERIVED_DATA" -name "mactrix.saver" -path "*/Build/Products/Debug/*" -not -path "*/Index.noindex/*" -type d 2>/dev/null | head -1)

if [ -z "$SAVER_PATH" ]; then
    echo "ERROR: Could not find built mactrix.saver"
    exit 1
fi

echo "Found built screensaver at: $SAVER_PATH"

# Remove old installation
echo "Removing old installation..."
rm -rf "$HOME/Library/Screen Savers/mactrix.saver"

# Install new version (preserve timestamps for code signing)
echo "Installing..."
cp -Rp "$SAVER_PATH" "$HOME/Library/Screen Savers/"

# Verify installation
if [ -d "$HOME/Library/Screen Savers/mactrix.saver" ]; then
    echo "=== Deployment successful! ==="
    echo ""
    echo "Opening System Settings → Screen Saver..."
    sleep 1
    open "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension"
else
    echo "ERROR: Installation failed!"
    exit 1
fi
