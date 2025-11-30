import Foundation
import CoreGraphics
import CoreMedia
import CoreImage
import ImageIO
import UniformTypeIdentifiers

class VideoEncoder {
    var onEncodedData: ((Data) -> Void)?
    private let context = CIContext(options: [.useSoftwareRenderer: false]) // Reuse context, use GPU
    
    func encode(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Convert CVPixelBuffer to CGImage
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        // Encode as JPEG
        guard let jpegData = encodeAsJPEG(cgImage) else { return }
        
        // Prepend length header
        var packet = Data()
        var length = UInt32(jpegData.count).bigEndian
        packet.append(Data(bytes: &length, count: 4))
        packet.append(jpegData)
        
        onEncodedData?(packet)
    }
    
    private func encodeAsJPEG(_ cgImage: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.7 // Good balance of quality and speed
        ]
        
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        CGImageDestinationFinalize(destination)
        
        return mutableData as Data
    }
}
