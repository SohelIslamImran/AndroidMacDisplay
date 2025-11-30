import Foundation
import ScreenCaptureKit
import CoreGraphics

class ScreenCapture: NSObject, SCStreamOutput, @unchecked Sendable {
    private var stream: SCStream?
    var onFrame: ((CMSampleBuffer) -> Void)?
    
    func startCapture() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            guard let display = content.displays.first else {
                print("No display found")
                return
            }
            
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 FPS
            config.queueDepth = 5
            
            stream = SCStream(filter: filter, configuration: config, delegate: nil)
            
            try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())
            try await stream?.startCapture()
            
            print("Screen capture started for display: \(display.width)x\(display.height)")
            
        } catch {
            print("Failed to start capture: \(error)")
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
