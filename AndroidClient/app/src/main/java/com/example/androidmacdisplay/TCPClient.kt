package com.example.androidmacdisplay

import java.io.InputStream
import java.net.Socket
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

class TCPClient(
    private val host: String, 
    private val port: Int, 
    private val onStateChange: (Boolean) -> Unit,
    private val onData: (ByteArray, Int) -> Unit
) {

    private var socket: Socket? = null
    private val isRunning = AtomicBoolean(false)
    private var thread: Thread? = null

    fun start() {
        if (isRunning.get()) return
        isRunning.set(true)
        
        thread = Thread {
            // Reusable buffer (1MB should be enough for a frame)
            val buffer = ByteArray(1024 * 1024) 
            
            while (isRunning.get()) {
                try {
                    socket = Socket(host, port)
                    socket!!.tcpNoDelay = true // Critical for low latency
                    val inputStream: InputStream = socket!!.getInputStream()
                    val headerBuffer = ByteArray(4)
                    
                    // Connected
                    onStateChange(true)
                    
                    while (isRunning.get()) {
                        // Read Length
                        readFully(inputStream, headerBuffer)
                        val length = ByteBuffer.wrap(headerBuffer).int
                        
                        if (length > 0) {
                            if (length > buffer.size) {
                                // Should rarely happen, but handle it if frame is huge
                                // For now, just skip or maybe we should resize. 
                                // 1MB is huge for 1080p H.264 frame (usually < 100KB)
                                // Let's just read into a temp buffer if it exceeds, or crash.
                                // Safe bet: just read what we can.
                                val temp = ByteArray(length)
                                readFully(inputStream, temp)
                                onData(temp, length)
                            } else {
                                readFully(inputStream, buffer, length)
                                onData(buffer, length)
                            }
                        }
                    }
                } catch (e: Exception) {
                    // e.printStackTrace()
                    // Sleep before retry
                    try { Thread.sleep(1000) } catch (e: InterruptedException) {}
                } finally {
                    onStateChange(false)
                    close()
                }
            }
        }
        thread?.start()
    }

    private fun readFully(inputStream: InputStream, buffer: ByteArray, length: Int = buffer.size) {
        var offset = 0
        while (offset < length) {
            val read = inputStream.read(buffer, offset, length - offset)
            if (read == -1) throw Exception("End of stream")
            offset += read
        }
    }

    fun stop() {
        isRunning.set(false)
        close()
        try {
            thread?.join(1000)
        } catch (e: InterruptedException) {
            e.printStackTrace()
        }
    }
    
    private fun close() {
        try {
            socket?.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
