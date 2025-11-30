package com.example.androidmacdisplay

import android.graphics.BitmapFactory
import android.graphics.Paint
import android.view.Surface

class VideoDecoder(private val surface: Surface) {

    private var isRunning = false
    private val paint = Paint().apply {
        isFilterBitmap = true  // Enable filtering for smoother scaling
        isAntiAlias = true     // Better text rendering
        isDither = false
    }

    private val bitmapOptions = BitmapFactory.Options().apply {
        inPreferredConfig = android.graphics.Bitmap.Config.RGB_565 // Faster decoding
        inMutable = false
    }

    // Transformation state
    private val matrix = android.graphics.Matrix()
    private var scaleFactor = 1.0f
    private var translateX = 0.0f
    private var translateY = 0.0f
    
    // Caching and Synchronization
    private val lock = Any()
    private var activeBitmap: android.graphics.Bitmap? = null // Currently displayed
    private var decodingBitmap: android.graphics.Bitmap? = null // Next buffer to decode into
    
    // Threading for decoding
    private val decodeThread = android.os.HandlerThread("VideoDecoderThread")
    private var decodeHandler: android.os.Handler? = null
    private val pendingFrameData = java.util.concurrent.atomic.AtomicReference<ByteArray?>()
    private val isDecoding = java.util.concurrent.atomic.AtomicBoolean(false)

    fun start() {
        isRunning = true
        decodeThread.start()
        decodeHandler = android.os.Handler(decodeThread.looper)
    }

    fun stop() {
        isRunning = false
        decodeThread.quitSafely()
        synchronized(lock) {
            activeBitmap?.recycle()
            activeBitmap = null
            decodingBitmap?.recycle()
            decodingBitmap = null
        }
    }

    fun updateTransform(scale: Float, x: Float, y: Float) {
        synchronized(lock) {
            scaleFactor = scale
            translateX = x
            translateY = y
            // Immediate redraw with cached bitmap
            activeBitmap?.let { drawFrame(it) }
        }
    }

    // Called from Network Thread
    fun decode(data: ByteArray, length: Int) {
        if (!isRunning) return
        
        // 1. Copy data to ensure safety (TCPClient reuses buffer)
        // We only copy if we are going to use it.
        // Optimization: If a frame is already pending, we overwrite it (drop the old one).
        // This is the key "Frame Dropping" logic.
        
        val dataCopy = java.util.Arrays.copyOf(data, length)
        pendingFrameData.set(dataCopy)
        
        // 2. Trigger decode on background thread if not already running
        if (!isDecoding.getAndSet(true)) {
            decodeHandler?.post(decodeRunnable)
        }
    }
    
    private val decodeRunnable = object : Runnable {
        override fun run() {
            // Keep decoding as long as there is a pending frame
            while (true) {
                val data = pendingFrameData.getAndSet(null) ?: break
                
                try {
                    // Use the idle buffer for decoding
                    bitmapOptions.inBitmap = decodingBitmap
                    
                    val bitmap = BitmapFactory.decodeByteArray(data, 0, data.size, bitmapOptions)
                    
                    if (bitmap != null) {
                        synchronized(lock) {
                            // Swap buffers
                            val previousActive = activeBitmap
                            activeBitmap = bitmap
                            
                            // The previous active bitmap becomes the next decoding buffer
                            decodingBitmap = previousActive
                            
                            drawFrame(activeBitmap!!)
                        }
                    }
                } catch (e: Exception) {
                    // Silent
                }
            }
            isDecoding.set(false)
            
            // Double check if a new frame arrived while we were exiting loop
            if (pendingFrameData.get() != null) {
                if (!isDecoding.getAndSet(true)) {
                    decodeHandler?.post(this)
                }
            }
        }
    }
    
    private fun drawFrame(bitmap: android.graphics.Bitmap) {
        if (!surface.isValid) return
        
        try {
            val canvas = surface.lockCanvas(null) ?: return
            
            // Clear canvas
            canvas.drawColor(android.graphics.Color.BLACK)
            
            // Calculate matrix
            matrix.reset()
            
            val viewWidth = canvas.width.toFloat()
            val viewHeight = canvas.height.toFloat()
            val bmpWidth = bitmap.width.toFloat()
            val bmpHeight = bitmap.height.toFloat()
            
            // Base scale to fit the screen
            val scaleX = viewWidth / bmpWidth
            val scaleY = viewHeight / bmpHeight
            
            matrix.postScale(scaleX, scaleY)
            
            // Apply user zoom and pan
            matrix.postScale(scaleFactor, scaleFactor)
            matrix.postTranslate(translateX, translateY)
            
            canvas.drawBitmap(bitmap, matrix, paint)
            
            surface.unlockCanvasAndPost(canvas)
        } catch (e: Exception) {
            // Handle surface errors
        }
    }
}
