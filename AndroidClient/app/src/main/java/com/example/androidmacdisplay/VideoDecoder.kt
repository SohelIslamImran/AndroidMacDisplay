package com.example.androidmacdisplay

import android.media.MediaCodec
import android.media.MediaFormat
import android.view.Surface
import java.nio.ByteBuffer

class VideoDecoder(private val surface: Surface) {

    private var codec: MediaCodec? = null
    private var isRunning = false

    fun start() {
        try {
            codec = MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
            
            // We might need to pass CSD-0/CSD-1 (SPS/PPS) here if not in stream.
            // But our Mac encoder sends them in-band (hopefully).
            // If not, we need to extract them or hardcode common values (risky).
            // For now, let's assume the stream has them or we configure a generic format.
            
            val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, 1280, 720)
            
            // Low Latency Settings
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                format.setInteger(MediaFormat.KEY_LOW_LATENCY, 1)
            }
            format.setInteger(MediaFormat.KEY_PRIORITY, 0) // Realtime priority
            format.setInteger(MediaFormat.KEY_OPERATING_RATE, 120) // Hint 120fps processing speed
            
            codec?.configure(format, surface, null, 0)
            codec?.start()
            isRunning = true
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun stop() {
        isRunning = false
        try {
            codec?.stop()
            codec?.release()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun decode(data: ByteArray, length: Int) {
        if (!isRunning || codec == null) return
        
        try {
            val inputBufferIndex = codec!!.dequeueInputBuffer(10000)
            if (inputBufferIndex >= 0) {
                val inputBuffer = codec!!.getInputBuffer(inputBufferIndex)
                inputBuffer?.clear()
                inputBuffer?.put(data, 0, length)
                codec!!.queueInputBuffer(inputBufferIndex, 0, length, System.nanoTime() / 1000, 0)
            }
            
            val bufferInfo = MediaCodec.BufferInfo()
            var outputBufferIndex = codec!!.dequeueOutputBuffer(bufferInfo, 0)
            
            while (outputBufferIndex >= 0) {
                codec!!.releaseOutputBuffer(outputBufferIndex, true)
                outputBufferIndex = codec!!.dequeueOutputBuffer(bufferInfo, 0)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
