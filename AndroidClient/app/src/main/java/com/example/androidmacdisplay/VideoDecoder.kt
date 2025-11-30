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
            
            val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, 1920, 1080)
            // format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 100000)
            
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

    fun decode(data: ByteArray) {
        if (!isRunning || codec == null) return
        
        try {
            val inputBufferIndex = codec!!.dequeueInputBuffer(10000)
            if (inputBufferIndex >= 0) {
                val inputBuffer = codec!!.getInputBuffer(inputBufferIndex)
                inputBuffer?.clear()
                inputBuffer?.put(data)
                codec!!.queueInputBuffer(inputBufferIndex, 0, data.size, System.nanoTime() / 1000, 0)
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
