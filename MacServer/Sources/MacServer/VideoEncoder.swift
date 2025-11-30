import Foundation
import VideoToolbox

class VideoEncoder {
    private var session: VTCompressionSession?
    var onEncodedData: ((Data) -> Void)?
    
    init(width: Int32, height: Int32) {
        setupSession(width: width, height: height)
    }
    
    private func setupSession(width: Int32, height: Int32) {
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: compressionCallback,
            refcon: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            compressionSessionOut: &session
        )
        
        if status != noErr {
            print("Failed to create compression session: \(status)")
            return
        }
        
        VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel) // Baseline = faster
        VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_AverageBitRate, value: 8_000_000 as CFNumber) // 8 Mbps
        VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: 30 as CFNumber) // More keyframes
        VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: 30 as CFNumber)
    }
    
    func encode(_ sampleBuffer: CMSampleBuffer) {
        guard let session = session else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let presentationTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)
        
        var flags: VTEncodeInfoFlags = []
        
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: imageBuffer,
            presentationTimeStamp: presentationTimestamp,
            duration: duration,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: &flags
        )
        
        if status != noErr {
            print("Failed to encode frame: \(status)")
        }
    }
}

private func compressionCallback(
    outputCallbackRefCon: UnsafeMutableRawPointer?,
    sourceFrameRefCon: UnsafeMutableRawPointer?,
    status: OSStatus,
    infoFlags: VTEncodeInfoFlags,
    sampleBuffer: CMSampleBuffer?
) {
    guard status == noErr, let sampleBuffer = sampleBuffer, let refCon = outputCallbackRefCon else {
        return
    }
    
    let encoder = Unmanaged<VideoEncoder>.fromOpaque(refCon).takeUnretainedValue()
    
    // Extract NAL units
    if let data = dataFromSampleBuffer(sampleBuffer) {
        encoder.onEncodedData?(data)
    }
}

private func dataFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> Data? {
    guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
    
    // Handle SPS/PPS (Parameter Sets) if they are in the format description (usually for the first frame or IDR)
    // Note: In a real stream, we might need to send SPS/PPS periodically or with every IDR frame.
    // For simplicity, we'll assume the decoder can handle the stream or we send it out-of-band,
    // but typically for H.264 streams, we need to prefix IDR frames with SPS/PPS.
    
    // Let's extract the raw H.264 NALUs.
    // CMSampleBuffer contains NALUs in AVCC format (Length Prefix). We might need Annex B (Start Code 00 00 00 01) for some decoders (like MediaCodec sometimes prefers).
    // But MediaCodec can often handle AVCC if configured correctly with CSD-0/CSD-1.
    // However, sending raw NALUs with a simple length header or start code is common.
    // Let's convert to Annex B (00 00 00 01) for broad compatibility.
    
    var data = Data()
    
    // Check for SPS/PPS in format description and prepend if keyframe
    if isKeyFrame(sampleBuffer) {
         if let sps = getParameterSet(formatDescription, index: 0),
            let pps = getParameterSet(formatDescription, index: 1) {
             data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
             data.append(sps)
             data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
             data.append(pps)
         }
    }
    
    guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
    var lengthAtOffset: Int = 0
    var totalLength: Int = 0
    var dataPointer: UnsafeMutablePointer<Int8>?
    
    let status = CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)
    
    if status == noErr, let pointer = dataPointer {
        var offset = 0
        let bufferPointer = UnsafeRawPointer(pointer)
        
        while offset < totalLength - 4 {
            // Read NAL unit length (4 bytes, big endian)
            var naluLength: UInt32 = 0
            memcpy(&naluLength, bufferPointer + offset, 4)
            naluLength = CFSwapInt32BigToHost(naluLength)
            
            // Move past length header
            offset += 4
            
            // Append Start Code
            data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
            
            // Append NAL Unit
            let naluData = Data(bytes: bufferPointer + offset, count: Int(naluLength))
            data.append(naluData)
            
            offset += Int(naluLength)
        }
    }
    
    // Prepend total length of the frame data (4 bytes)
    var packet = Data()
    var length = UInt32(data.count).bigEndian
    packet.append(Data(bytes: &length, count: 4))
    packet.append(data)
    
    return packet
}

private func isKeyFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
    guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]],
          let attachment = attachments.first else {
        return true // Assume keyframe if no info
    }
    
    let notSync = attachment[kCMSampleAttachmentKey_NotSync] as? Bool ?? false
    return !notSync
}

private func getParameterSet(_ formatDescription: CMFormatDescription, index: Int) -> Data? {
    var parameterSetPointer: UnsafePointer<UInt8>?
    var parameterSetLength: Int = 0
    var parameterSetCount: Int = 0
    var nalUnitHeaderLength: Int32 = 0
    
    let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
        formatDescription,
        parameterSetIndex: index,
        parameterSetPointerOut: &parameterSetPointer,
        parameterSetSizeOut: &parameterSetLength,
        parameterSetCountOut: &parameterSetCount,
        nalUnitHeaderLengthOut: &nalUnitHeaderLength
    )
    
    if status == noErr, let pointer = parameterSetPointer {
        return Data(bytes: pointer, count: parameterSetLength)
    }
    return nil
}
