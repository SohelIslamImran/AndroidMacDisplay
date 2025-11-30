#!/bin/bash

# Ensure we are in the script's directory (MacServer/)
cd "$(dirname "$0")"

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
    <string>1.0</string>
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

# Reset permissions for this app (Clean slate)
tccutil reset ScreenCapture com.sohel.MacDisplay 2>/dev/null

# Note: LSUIElement=true makes it a pure agent app (no dock icon), which is good for menu bar apps.

echo "App created at $APP_BUNDLE"

# Move to /Applications
echo "Moving $APP_BUNDLE to $INSTALL_PATH..."
# User might need to enter password if they don't have write access to /Applications
if sudo mv -f "$APP_BUNDLE" "$INSTALL_PATH/"; then
    echo "Successfully moved to $INSTALL_PATH/$APP_BUNDLE"
    
    # Fix ownership to the current user (sudo mv makes it root:wheel)
    USER_ID=$(id -u)
    GROUP_ID=$(id -g)
    echo "Fixing ownership to $USER_ID:$GROUP_ID..."
    sudo chown -R $USER_ID:$GROUP_ID "$INSTALL_PATH/$APP_BUNDLE"
    
    # Force register with Launch Services
    echo "Registering with Launch Services..."
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALL_PATH/$APP_BUNDLE"
    
    # Open the app
    echo "Opening $APP_NAME..."
    open "$INSTALL_PATH/$APP_BUNDLE"
else
    echo "Failed to move app to $INSTALL_PATH. You might need to run the script with 'sudo' or move it manually."
    echo "App bundle is available at $(pwd)/$APP_BUNDLE"
fi

