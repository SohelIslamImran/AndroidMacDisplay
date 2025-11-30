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
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.android.material.floatingactionbutton.FloatingActionButton
import android.widget.RadioGroup
import android.widget.ProgressBar

class MainActivity : AppCompatActivity(), SurfaceHolder.Callback {

    private lateinit var surfaceView: SurfaceView
    private lateinit var statusCard: CardView
    private lateinit var statusText: TextView
    private lateinit var statusSubText: TextView
    private lateinit var progressBar: ProgressBar
    private lateinit var fabSettings: FloatingActionButton
    
    private var tcpClient: TCPClient? = null
    private var videoDecoder: VideoDecoder? = null
    private var isFillScreen = false
    
    // Debounce helper
    private val handler = Handler(Looper.getMainLooper())
    private var connectionToastRunnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        surfaceView = findViewById(R.id.surfaceView)
        statusCard = findViewById(R.id.statusCard)
        statusText = findViewById(R.id.statusText)
        // We need to find the subtext view. It was not in the member variables in the old file but likely exists in XML.
        // Let's assume we need to add ID to XML or find it by index/tag?
        // Actually, looking at XML, the subtext didn't have an ID in the previous read_file.
        // I will add finding it dynamically or just updating statusText for now to be safe,
        // but better to update XML ID. For now, I'll assume I can find it or just append text.
        // Wait, I should update XML to add ID to subtext.
        // But I can't update XML in this tool call.
        // I'll assume I can find it via traversal or just use statusText.
        // Let's just use statusText for main message and maybe another textview if I can find it.
        // The previous XML showed a TextView with text "Connect USB..." below statusText.
        // I will assume it is the 3rd child of LinearLayout inside CardView.
        
        progressBar = findViewById(R.id.progressBar)
        fabSettings = findViewById(R.id.fabSettings)
        statusSubText = findViewById(R.id.statusSubText)
        
        surfaceView.holder.setFixedSize(1280, 720) 
        surfaceView.holder.addCallback(this)
        
        fabSettings.setOnClickListener {
            showSettings()
        }
        
        hideSystemUI()
    }

    private fun showSettings() {
        val dialog = BottomSheetDialog(this)
        val view = layoutInflater.inflate(R.layout.layout_settings_bottom_sheet, null)
        dialog.setContentView(view)
        
        val radioGroup = view.findViewById<RadioGroup>(R.id.scaleRadioGroup)
        radioGroup.check(if (isFillScreen) R.id.radioFill else R.id.radioFit)
        
        radioGroup.setOnCheckedChangeListener { _, checkedId ->
            isFillScreen = (checkedId == R.id.radioFill)
            updateSurfaceLayout()
            dialog.dismiss()
        }
        
        view.findViewById<View>(R.id.btnClose).setOnClickListener {
            dialog.dismiss()
        }
        
        dialog.show()
    }
    
    private fun updateSurfaceLayout() {
        if (isFillScreen) {
             surfaceView.scaleX = 1.2f 
             surfaceView.scaleY = 1.2f
        } else {
             surfaceView.scaleX = 1.0f
             surfaceView.scaleY = 1.0f
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
                    fabSettings.show()
                    
                    // Debounce toast: only show if we stay connected for 500ms
                    connectionToastRunnable = Runnable {
                         showToast("Connected")
                    }
                    handler.postDelayed(connectionToastRunnable!!, 500)
                }
                is ClientState.Connecting -> {
                    statusCard.visibility = View.VISIBLE
                    progressBar.visibility = View.VISIBLE
                    statusText.text = "Waiting for connection..."
                    statusSubText.text = "Ensure Mac Server is running"
                    // fabSettings.hide()
                }
                is ClientState.Disconnected -> {
                    statusCard.visibility = View.VISIBLE
                    progressBar.visibility = View.VISIBLE // Keep spinning or show error icon? User wanted "Not connected"
                    statusText.text = "Not Connected"
                    statusSubText.text = "1. Check USB Cable\n2. Check Mac Server\n3. Check USB Debugging"
                    // fabSettings.hide()
                }
                is ClientState.Error -> {
                     // Same as disconnected usually
                    statusCard.visibility = View.VISIBLE
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