package com.example.androidmacdisplay

import android.graphics.BitmapFactory
import android.graphics.Paint
import android.view.Surface

class VideoDecoder(private val surface: Surface) {

    private var isRunning = false
    private val paint = Paint().apply {
        isFilterBitmap = false
        isAntiAlias = false
        isDither = false
    }

    private val bitmapOptions = BitmapFactory.Options().apply {
        inPreferredConfig = android.graphics.Bitmap.Config.RGB_565
        inMutable = false
    }

    fun start() {
        isRunning = true
    }

    fun stop() {
        isRunning = false
    }

    fun decode(data: ByteArray, length: Int) {
        if (!isRunning) return
        
        try {
            val bitmap = BitmapFactory.decodeByteArray(data, 0, length, bitmapOptions) ?: return
            val canvas = surface.lockCanvas(null) ?: return
            
            // Simple draw - let SurfaceView handle scaling
            canvas.drawBitmap(bitmap, 0f, 0f, paint)
            
            surface.unlockCanvasAndPost(canvas)
            bitmap.recycle()
        } catch (e: Exception) {
            // Silent
        }
    }
}
