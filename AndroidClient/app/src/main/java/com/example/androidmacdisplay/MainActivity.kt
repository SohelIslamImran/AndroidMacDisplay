package com.example.androidmacdisplay

import android.os.Bundle
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity(), SurfaceHolder.Callback {

    private lateinit var surfaceView: SurfaceView
    private var tcpClient: TCPClient? = null
    private var videoDecoder: VideoDecoder? = null
    private var isConnected = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        surfaceView = findViewById(R.id.surfaceView)
        surfaceView.holder.addCallback(this)
        
        hideSystemUI()
        showToast("Waiting for connection...")
    }

    private fun hideSystemUI() {
        androidx.core.view.WindowCompat.setDecorFitsSystemWindows(window, false)
        val controller = androidx.core.view.WindowInsetsControllerCompat(window, window.decorView)
        controller.hide(androidx.core.view.WindowInsetsCompat.Type.systemBars())
        controller.systemBarsBehavior = androidx.core.view.WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
    }

    private fun showToast(message: String) {
        runOnUiThread {
            android.widget.Toast.makeText(this, message, android.widget.Toast.LENGTH_SHORT).show()
        }
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        startDisplay(holder)
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        // No-op
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        stopDisplay()
    }
    
    private fun startDisplay(holder: SurfaceHolder) {
        videoDecoder = VideoDecoder(holder.surface)
        videoDecoder?.start()
        
        tcpClient = TCPClient("127.0.0.1", 8000) { data ->
            if (data.isEmpty()) {
                if (!isConnected) {
                    isConnected = true
                    showToast("Connected")
                }
            } else {
                videoDecoder?.decode(data)
            }
        }
        tcpClient?.start()
    }
    
    private fun stopDisplay() {
        tcpClient?.stop()
        videoDecoder?.stop()
    }
}
