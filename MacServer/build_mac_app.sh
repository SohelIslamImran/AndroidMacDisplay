#!/bin/bash

# Ensure we are in the script's directory (MacServer/)
cd "$(dirname "$0")"

# Version parameters (can be passed via environment variables)
SHORT_VERSION="${SHORT_VERSION:-1.0}"
BUILD_VERSION="${BUILD_VERSION:-1}"

APP_NAME="MacDisplay"
INSTALL_PATH="/Applications"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building MacServer..."
swift build -c release --product MacServer

if [ $? -ne 0 ]; then
    echo "Build failed"
    exit 1
fi

echo "Creating App Bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy binary
cp "$BUILD_DIR/MacServer" "$MACOS/$APP_NAME"

# Create Info.plist
cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.sohel.MacDisplay</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$SHORT_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_VERSION</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>MacDisplay needs screen recording permission to stream your desktop to your Android device.</string>
</dict>
</plist>
EOF

# Remove quarantine attributes (Fixes "Damaged" or permission issues)
echo "Removing quarantine attributes..."
xattr -cr "$APP_BUNDLE"

# Sign the app (Crucial for permissions to work)
# Removed --options runtime to avoid ad-hoc signing complications
echo "Signing app..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "App created at $APP_BUNDLE"
