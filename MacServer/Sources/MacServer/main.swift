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
// We need to wait for the screen capture to determine the resolution, or pick a default.
// For simplicity, let's start capture and setup encoder on the first frame or use a fixed resolution if possible.
// ScreenCaptureKit gives us the display size.

let screenCapture = ScreenCapture()
var videoEncoder: VideoEncoder?

screenCapture.onFrame = { sampleBuffer in
    // Initialize encoder if needed
    if videoEncoder == nil {
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let width = Int32(CVPixelBufferGetWidth(imageBuffer))
            let height = Int32(CVPixelBufferGetHeight(imageBuffer))
            print("Initializing Encoder: \(width)x\(height)")
            videoEncoder = VideoEncoder(width: width, height: height)
            
            videoEncoder?.onEncodedData = { data in
                // Send data to clients
                tcpServer.send(data: data)
            }
        }
    }
    
    videoEncoder?.encode(sampleBuffer)
}

// Start Capture
Task {
    await screenCapture.startCapture()
}

// Keep alive
RunLoop.main.run()
