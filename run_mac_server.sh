#!/bin/bash

# Ensure we are in the right directory
cd "$(dirname "$0")/MacServer"

# Check for ADB
if ! command -v adb &> /dev/null; then
    echo "Error: 'adb' not found. Please install android-platform-tools."
    echo "  brew install android-platform-tools"
    exit 1
fi

echo "Starting Mac Server..."
echo "Please ensure your Android device is connected with USB Debugging enabled."

# Kill old server if running
echo "Cleaning up old server instances..."
lsof -ti:8000 | xargs kill -9 2>/dev/null || true

# Run the Swift app
swift run
