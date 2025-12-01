# 📱 Android Mac Display

**Turn your Android phone into a wired secondary monitor for your Mac via USB**

Stream your Mac screen to your Android device with minimal latency using a USB connection. Perfect for extending your workspace or monitoring applications while on the go.

[![Build Status](https://github.com/SohelIslamImran/AndroidMacDisplay/actions/workflows/build.yml/badge.svg)](https://github.com/SohelIslamImran/AndroidMacDisplay/actions)

---

## ✨ Features

- 🚀 **Low Latency**: Direct USB connection for fast, reliable streaming
- 🖥️ **Menu Bar App**: Clean macOS menu bar integration - no dock clutter
- 📱 **Native Android**: Smooth, hardware-accelerated video decoding
- 🔒 **Privacy First**: No internet required - everything stays local
- ⚡ **Easy Setup**: Automated ADB configuration and port forwarding

---

## 📥 Download & Install

### Quick Download (Recommended)

**Download the latest pre-built apps from [GitHub Releases](https://github.com/SohelIslamImran/AndroidMacDisplay/releases/latest):**

1. **For Mac**: Download `MacDisplay.dmg`
2. **For Android**: Download `AndroidMacDisplay-debug.apk`

### Installation Instructions

#### macOS App

1. **Download** `MacDisplay.dmg` from the [latest release](https://github.com/SohelIslamImran/AndroidMacDisplay/releases/latest)
2. **Open** the DMG file
3. **Drag** `MacDisplay.app` to your Applications folder
4. **Open** the app from Applications
5. **Grant Permissions**:
   - First launch will request Screen Recording permission
   - Go to **System Preferences → Privacy & Security → Screen Recording**
   - Enable permission for MacDisplay
   - Restart the app

The app will appear in your menu bar (top-right corner of screen).

#### Android App

1. **Download** `AndroidMacDisplay-debug.apk` from the [latest release](https://github.com/SohelIslamImran/AndroidMacDisplay/releases/latest)
2. **Transfer** the APK to your Android device
3. **Enable** "Install from Unknown Sources":
   - Go to **Settings → Security → Install Unknown Apps**
   - Allow your file manager or browser to install apps
4. **Tap** the APK file to install
5. **Enable Developer Options** (if not already enabled):
   - Go to **Settings → About Phone**
   - Tap **Build Number** 7 times
6. **Enable USB Debugging**:
   - Go to **Settings → System → Developer Options**
   - Toggle **USB Debugging** ON

---

## 🚀 Quick Start

### Prerequisites

1. **USB Cable**: A data-capable USB cable (not just charging-only)
2. **ADB (Android Debug Bridge)** on your Mac:

   ```bash
   brew install android-platform-tools
   ```

   *(If you have Android Studio, you already have ADB)*

### Usage

1. **Connect** your Android device to your Mac via USB
2. **Open** MacDisplay app on Mac (menu bar icon)
3. **Open** Android Mac Display app on your phone
4. **Accept** the USB debugging prompt on your Android device
5. **Watch** your Mac screen appear on your phone! 🎉

The Mac app will automatically:

- ✅ Detect your connected Android device via ADB
- ✅ Configure port forwarding
- ✅ Start streaming your screen

### Menu Bar Controls (Mac)

Click the menu bar icon to access:

- **Streaming Status**: See if streaming is active
- **Connected Device**: View connected Android device info
- **Start/Stop Streaming**: Manual control
- **Quit**: Exit the application

---

## 🛠️ Building from Source

### Mac App

#### Requirements

- macOS 13.0 or later
- Swift 6.2 or later
- Xcode Command Line Tools

#### Build & Install

```bash
cd MacServer
chmod +x build_mac_app.sh
./build_mac_app.sh
```

This will:

1. Build the Swift package in release mode
2. Create a proper `.app` bundle
3. Sign the application
4. Install to `/Applications`
5. Launch the app

#### Manual Build (for development)

```bash
cd MacServer
swift build -c release
swift run  # For testing
```

### Android App

#### Requirements

- Android Studio Arctic Fox or later
- JDK 17 or later
- Android SDK 26+ (Android 8.0 or higher)

#### Build APK

##### Using Android Studio (Recommended)

1. Open the `AndroidClient` folder in Android Studio
2. Wait for Gradle sync to complete
3. Select **Build → Build Bundle(s) / APK(s) → Build APK(s)**
4. Find APK in `AndroidClient/app/build/outputs/apk/`

##### Using Command Line

```bash
cd AndroidClient

# Debug build
./gradlew assembleDebug

# Release build (unsigned)
./gradlew assembleRelease
```

APKs will be in `app/build/outputs/apk/debug/` or `release/`.

---

## 🔧 Troubleshooting

### Mac Issues

**"MacDisplay" cannot be opened because the developer cannot be verified**

- Right-click the app → **Open** → Confirm
- Or: System Preferences → Security & Privacy → Click "Open Anyway"

**Black screen on Android**

- Ensure Screen Recording permission is granted in System Preferences
- Quit and restart the Mac app
- Check that ADB is working: `adb devices` should list your device

**"ADB not found" error**

- Install ADB: `brew install android-platform-tools`
- Restart the Mac app

### Android Issues

**App not installing**

- Enable "Install from Unknown Sources" for your browser/file manager
- Try: `adb install AndroidMacDisplay-debug.apk`

**USB debugging not working**

- Revoke USB debugging authorizations: Settings → Developer Options
- Reconnect USB and accept the prompt
- Check cable - some cables are charge-only

**Black screen / "Not Connected"**

- Ensure USB debugging is enabled
- Check that Mac app is running
- Try disconnecting and reconnecting USB
- Run `adb devices` on Mac to verify device is detected

**Laggy video**

- Use a high-quality USB cable (USB 3.0 recommended)
- Close other apps on Android to free up resources
- Try a lower resolution setting (future feature)

---

## 🏗️ Architecture

### Mac Server (Swift)

- **ScreenCapture**: Captures Mac screen frames using `SCShareableContent`
- **VideoEncoder**: Encodes frames to H.264 using `VideoToolbox`
- **TCPServer**: Streams encoded video over TCP
- **USBManager**: Manages ADB and port forwarding
- **MacApp**: SwiftUI menu bar interface

### Android Client (Kotlin)

- **MainActivity**: Main UI with TextureView for video display
- **TCPClient**: Connects to Mac server via forwarded port
- **VideoDecoder**: Hardware-accelerated H.264 decoding using `MediaCodec`

### Communication Protocol

1. Mac app starts TCP server on port 8000
2. ADB reverse port forwards Android's localhost:8000 → Mac's localhost:8000
3. Android app connects to localhost:8000
4. Mac streams H.264-encoded video frames
5. Android decodes and displays in real-time

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Test on both Mac and Android
5. Commit: `git commit -m 'Add amazing feature'`
6. Push: `git push origin feature/amazing-feature`
7. Open a Pull Request

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
