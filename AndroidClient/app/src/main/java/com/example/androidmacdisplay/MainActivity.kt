package com.example.androidmacdisplay

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import android.widget.ProgressBar
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.GestureDetector
import android.graphics.Matrix


class MainActivity : AppCompatActivity(), SurfaceHolder.Callback {

    private lateinit var surfaceView: SurfaceView
    private lateinit var statusCard: CardView
    private lateinit var statusText: TextView
    private lateinit var statusSubText: TextView
    private lateinit var progressBar: ProgressBar

    private var tcpClient: TCPClient? = null
    private var videoDecoder: VideoDecoder? = null

    // Debounce helper
    private val handler = Handler(Looper.getMainLooper())
    private var connectionToastRunnable: Runnable? = null

    // Gesture Detectors
    private lateinit var scaleGestureDetector: ScaleGestureDetector
    private lateinit var gestureDetector: GestureDetector

    // Transformation State
    private val userMatrix = Matrix()
    private val matrixValues = FloatArray(9)


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        surfaceView = findViewById(R.id.surfaceView)
        statusCard = findViewById(R.id.statusCard)
        statusText = findViewById(R.id.statusText)

        progressBar = findViewById(R.id.progressBar)
        statusSubText = findViewById(R.id.statusSubText)

        surfaceView.holder.setFixedSize(1280, 720)
        surfaceView.holder.addCallback(this)

        setupGestures()

        surfaceView.setOnTouchListener { _, event ->
            scaleGestureDetector.onTouchEvent(event)
            gestureDetector.onTouchEvent(event)
            true
        }

        hideSystemUI()
    }

    private fun setupGestures() {
        scaleGestureDetector = ScaleGestureDetector(this, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                val scaleFactor = detector.scaleFactor

                // Get current scale
                userMatrix.getValues(matrixValues)
                val currentScale = matrixValues[Matrix.MSCALE_X]

                // Clamp min scale to 1.0
                var effectiveScaleFactor = scaleFactor
                if (currentScale * effectiveScaleFactor < 1.0f) {
                    effectiveScaleFactor = 1.0f / currentScale
                }
                // Clamp max scale (optional, e.g. 5.0)
                if (currentScale * effectiveScaleFactor > 5.0f) {
                    effectiveScaleFactor = 5.0f / currentScale
                }

                userMatrix.postScale(effectiveScaleFactor, effectiveScaleFactor, detector.focusX, detector.focusY)
                updateDecoderTransform()
                return true
            }
        })

        gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onScroll(e1: MotionEvent?, e2: MotionEvent, distanceX: Float, distanceY: Float): Boolean {
                userMatrix.postTranslate(-distanceX, -distanceY)
                fixTranslation() // Keep within bounds
                updateDecoderTransform()
                return true
            }
        })
    }

    private fun fixTranslation() {
        userMatrix.getValues(matrixValues)
        val scaleX = matrixValues[Matrix.MSCALE_X]
        val transX = matrixValues[Matrix.MTRANS_X]
        val transY = matrixValues[Matrix.MTRANS_Y]

        val viewWidth = surfaceView.width.toFloat()
        val viewHeight = surfaceView.height.toFloat()

        // Assuming the content fills the view at scale 1.0
        val contentWidth = viewWidth * scaleX
        val contentHeight = viewHeight * scaleX // Assuming uniform scale

        // Bounds:
        // transX should be <= 0 (left edge)
        // transX + contentWidth should be >= viewWidth (right edge)

        var newTransX = transX
        var newTransY = transY

        if (contentWidth <= viewWidth) {
            // Center horizontally if smaller (shouldn't happen with min scale 1.0)
            newTransX = (viewWidth - contentWidth) / 2
        } else {
            if (newTransX > 0) newTransX = 0f
            if (newTransX + contentWidth < viewWidth) newTransX = viewWidth - contentWidth
        }

        if (contentHeight <= viewHeight) {
            newTransY = (viewHeight - contentHeight) / 2
        } else {
            if (newTransY > 0) newTransY = 0f
            if (newTransY + contentHeight < viewHeight) newTransY = viewHeight - contentHeight
        }

        matrixValues[Matrix.MTRANS_X] = newTransX
        matrixValues[Matrix.MTRANS_Y] = newTransY
        userMatrix.setValues(matrixValues)
    }

    private fun updateDecoderTransform() {
        userMatrix.getValues(matrixValues)
        val scale = matrixValues[Matrix.MSCALE_X]
        val tx = matrixValues[Matrix.MTRANS_X]
        val ty = matrixValues[Matrix.MTRANS_Y]

        val viewWidth = surfaceView.width.toFloat()
        val viewHeight = surfaceView.height.toFloat()

        // Map View coordinates to Buffer coordinates (1280x720)
        // This ensures the pan distance matches the finger movement visually
        if (viewWidth > 0 && viewHeight > 0) {
             val bufferWidth = 1280f
             val bufferHeight = 720f

             val ratioX = bufferWidth / viewWidth
             val ratioY = bufferHeight / viewHeight

             videoDecoder?.updateTransform(scale, tx * ratioX, ty * ratioY)
        }
    }

    private fun hideSystemUI() {
        androidx.core.view.WindowCompat.setDecorFitsSystemWindows(window, false)
        val controller = androidx.core.view.WindowInsetsControllerCompat(window, window.decorView)
        controller.hide(androidx.core.view.WindowInsetsCompat.Type.systemBars())
        controller.systemBarsBehavior = androidx.core.view.WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
    }

    private fun showToast(message: String) {
        android.widget.Toast.makeText(this, message, android.widget.Toast.LENGTH_SHORT).show()
    }

    private fun updateStatus(state: ClientState) {
        runOnUiThread {
            // Remove any pending toast
            connectionToastRunnable?.let { handler.removeCallbacks(it) }

            when (state) {
                is ClientState.Connected -> {
                    statusCard.visibility = View.GONE
                    progressBar.visibility = View.GONE

                    // Debounce toast: only show if we stay connected for 500ms
                    connectionToastRunnable = Runnable {
                         showToast("Connected")
                    }
                    handler.postDelayed(connectionToastRunnable!!, 500)
                }
                is ClientState.Connecting -> {
                    statusCard.visibility = View.VISIBLE
                    progressBar.visibility = View.VISIBLE
                }
                is ClientState.Disconnected -> {
                    statusCard.visibility = View.VISIBLE
                    progressBar.visibility = View.VISIBLE
                }
                is ClientState.Error -> {
                    statusCard.visibility = View.VISIBLE
                    progressBar.visibility = View.GONE
                    statusText.text = "Error"
                    statusSubText.text = state.message
                }
            }
        }
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        startDisplay(holder)
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        stopDisplay()
    }

    private fun startDisplay(holder: SurfaceHolder) {
        videoDecoder = VideoDecoder(holder.surface)
        videoDecoder?.start()

        tcpClient = TCPClient("127.0.0.1", 9090,
            onStateChange = { state ->
                updateStatus(state)
            },
            onData = { data, length ->
                videoDecoder?.decode(data, length)
            }
        )
        tcpClient?.start()
    }

    private fun stopDisplay() {
        tcpClient?.stop()
        videoDecoder?.stop()
    }
}
