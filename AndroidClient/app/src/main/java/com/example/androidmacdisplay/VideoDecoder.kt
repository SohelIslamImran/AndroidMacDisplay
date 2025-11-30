package com.example.androidmacdisplay

import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.view.Surface

class VideoDecoder(private val surface: Surface) {

    private var isRunning = false
    private val canvas: Canvas? = null

    fun start() {
        isRunning = true
    }

    fun stop() {
        isRunning = false
    }

    fun decode(data: ByteArray, length: Int) {
        if (!isRunning) return
        
        try {
            // Decode JPEG
            val bitmap = BitmapFactory.decodeByteArray(data, 0, length) ?: return
            
            // Draw to surface
            val canvas = surface.lockCanvas(null)
            canvas?.drawBitmap(bitmap, 0f, 0f, null)
            surface.unlockCanvasAndPost(canvas)
            
            bitmap.recycle()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
