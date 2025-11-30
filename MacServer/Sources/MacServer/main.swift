import Foundation
import CoreMedia

// Keep the run loop running
let runLoop = RunLoop.current

print("Starting MacServer...")

// 1. Setup USB (ADB Reverse)
let usbManager = USBManager()
usbManager.startMonitoring()

// 2. Setup TCP Server
let tcpServer = TCPServer()
if !tcpServer.start() {
    print("FATAL: Failed to start TCP Server. Port 8000 might be in use.")
    print("Try running: lsof -i :8000 -t | xargs kill -9")
    exit(1)
}

// 3. Setup Video Pipeline
var encoder: VideoEncoder?

let screenCapture = ScreenCapture()
screenCapture.onFrame = { sampleBuffer in
    // Lazy init encoder (JPEG doesn't need resolution upfront)
    if encoder == nil {
        encoder = VideoEncoder()
        encoder?.onEncodedData = { data in
            tcpServer.send(data: data)
        }
        print("JPEG Encoder initialized")
    }
    encoder?.encode(sampleBuffer)
}

// Start Capture
Task {
    await screenCapture.startCapture()
}

// Keep alive
RunLoop.main.run()
