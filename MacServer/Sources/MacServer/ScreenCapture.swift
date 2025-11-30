import Foundation
import ScreenCaptureKit
import CoreGraphics

class ScreenCapture: NSObject, SCStreamOutput, @unchecked Sendable {
    private var stream: SCStream?
    var onFrame: ((CMSampleBuffer) -> Void)?
    
    private var targetWidth: Int = 1280
    private var targetHeight: Int = 720
    
    func setResolution(width: Int?, height: Int?) {
        self.targetWidth = width ?? 1280
        self.targetHeight = height ?? 720
    }
    
    func startCapture() async throws {
        // Check and Request Permission Loop
        if !CGPreflightScreenCaptureAccess() {
            print("Requesting Screen Capture Access...")
            CGRequestScreenCaptureAccess()
            
            // Poll for permission for a few seconds
            for i in 0..<30 { // Wait up to 30 seconds
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1s
                if CGPreflightScreenCaptureAccess() {
                    print("Permission granted!")
                    break
                }
                print("Waiting for permission... (\(i+1)/30)")
            }
            
            // Check again
            if !CGPreflightScreenCaptureAccess() {
                 throw NSError(domain: "ScreenCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Screen recording permission not granted. Please enable it in System Settings > Privacy & Security > Screen Recording, then restart the server."])
            }
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            guard let display = content.displays.first else {
                throw NSError(domain: "ScreenCapture", code: 2, userInfo: [NSLocalizedDescriptionKey: "No display found."])
            }
            
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            
            let streamConfig = SCStreamConfiguration()
            streamConfig.width = targetWidth
            streamConfig.height = targetHeight
            streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60fps for smooth cursor
            streamConfig.queueDepth = 3  // Minimal buffering
            streamConfig.showsCursor = true
            
            stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
            
            try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())
            try await stream?.startCapture()
            
            print("Screen capture started for display: \(display.width)x\(display.height)")
            
        } catch {
            print("Failed to start capture: \(error)")
            throw error
        }
    }
    
    func stopCapture() {
        stream?.stopCapture()
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        onFrame?(sampleBuffer)
    }
}
