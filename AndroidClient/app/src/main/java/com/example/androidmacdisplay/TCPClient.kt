package com.example.androidmacdisplay

import java.io.InputStream
import java.net.Socket
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

class TCPClient(
    private val host: String, 
    private val port: Int, 
    private val onStateChange: (Boolean) -> Unit,
    private val onData: (ByteArray) -> Unit
) {

    private var socket: Socket? = null
    private val isRunning = AtomicBoolean(false)
    private var thread: Thread? = null

    fun start() {
        if (isRunning.get()) return
        isRunning.set(true)
        
        thread = Thread {
            while (isRunning.get()) {
                try {
                    socket = Socket(host, port)
                    val inputStream: InputStream = socket!!.getInputStream()
                    val headerBuffer = ByteArray(4)
                    
                    // Connected
                    onStateChange(true)
                    
                    while (isRunning.get()) {
                        // Read Length
                        readFully(inputStream, headerBuffer)
                        val length = ByteBuffer.wrap(headerBuffer).int
                        
                        if (length > 0) {
                            val data = ByteArray(length)
                            readFully(inputStream, data)
                            onData(data)
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

    private fun readFully(inputStream: InputStream, buffer: ByteArray) {
        var offset = 0
        while (offset < buffer.size) {
            val read = inputStream.read(buffer, offset, buffer.size - offset)
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
