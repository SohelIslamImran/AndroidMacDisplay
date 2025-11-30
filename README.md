# Android Mac USB Display

Use your Android phone as a wired secondary monitor (mirror) for your Mac.

## Prerequisites

1.  **USB Cable**: Connect your Android phone to your Mac.
2.  **Android Developer Options**:
    -   Go to **Settings > About Phone**.
    -   Tap **Build Number** 7 times to enable Developer Mode.
    -   Go to **Settings > System > Developer Options**.
    -   Enable **USB Debugging**.
3.  **ADB (Android Debug Bridge)**:
    -   If you have Android Studio, you likely have this.
    -   Otherwise, install via Homebrew: `brew install android-platform-tools`.

## Quick Start

### 1. Run Mac Server
The Mac app captures your screen and sends it to the phone.

1.  Open Terminal in this directory.
2.  Run the helper script:
    ```bash
    ./run_mac_server.sh
    ```
    *(Or manually: `cd MacServer && swift run`)*
3.  **Grant Permissions**: The first time you run this, macOS will ask for **Screen Recording** permission. Allow it, then you may need to restart the script.

### 2. Install & Run Android App
1.  Open the `AndroidClient` folder in **Android Studio**.
2.  Trust the project if asked.
3.  Click the green **Run** button (Play icon) in the toolbar.
4.  Select your connected phone.
5.  The app will install and open.

### 3. Connect
-   Once both apps are running and the USB cable is connected, your Mac screen should appear on your phone!
-   If it doesn't appear immediately, check the Terminal output for "ADB Reverse successful".

## Troubleshooting
-   **Black Screen**: Ensure `adb` is in your PATH. The script tries to find it.
-   **Permission Denied**: Make sure you granted Screen Recording permission to Terminal (or the app).
