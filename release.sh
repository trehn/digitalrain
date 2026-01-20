#!/bin/bash
set -e

echo "=== Digital Rain Screensaver Release Build ==="

cd "$(dirname "$0")"

# Clean and build universal Release
echo "Building universal binary (arm64 + x86_64)..."
xcodebuild -project digitalrain.xcodeproj -scheme digitalrain -configuration Release clean build \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    2>&1 | grep -E "(error:|warning:|BUILD)" | grep -v "Metadata extraction skipped"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "ERROR: Build failed!"
    exit 1
fi

# Find the built product
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
SAVER_PATH=$(find "$DERIVED_DATA" -name "Digital Rain.saver" -path "*/Build/Products/Release/*" -not -path "*/Index.noindex/*" -type d 2>/dev/null | head -1)

if [ -z "$SAVER_PATH" ]; then
    echo "ERROR: Could not find built Digital Rain.saver"
    exit 1
fi

echo "Found: $SAVER_PATH"

# Verify universal binary
echo ""
echo "Verifying architectures..."
file "$SAVER_PATH/Contents/MacOS/Digital Rain"

# Create release zip
RELEASE_DIR="$(pwd)/release"
mkdir -p "$RELEASE_DIR"
ZIP_PATH="$RELEASE_DIR/Digital-Rain.saver.zip"

echo ""
echo "Creating release zip..."
rm -f "$ZIP_PATH"
cd "$(dirname "$SAVER_PATH")"
zip -r "$ZIP_PATH" "Digital Rain.saver"

echo ""
echo "=== Release build complete ==="
echo "Output: $ZIP_PATH"
echo ""
ls -lh "$ZIP_PATH"
