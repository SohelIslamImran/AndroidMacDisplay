package com.example.androidmacdisplay

import java.io.InputStream
import java.net.Socket
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

sealed interface ClientState {
    object Disconnected : ClientState
    object Connecting : ClientState
    object Connected : ClientState
    data class Error(val message: String) : ClientState
}

class TCPClient(
    private val host: String, 
    private val port: Int, 
    private val onStateChange: (ClientState) -> Unit,
    private val onData: (ByteArray, Int) -> Unit
) {

    private var socket: Socket? = null
    private val isRunning = AtomicBoolean(false)
    private var thread: Thread? = null

    fun start() {
        if (isRunning.get()) return
        isRunning.set(true)
        
        thread = Thread {
            val buffer = ByteArray(1024 * 1024) 
            
            while (isRunning.get()) {
                try {
                    onStateChange(ClientState.Connecting)
                    
                    socket = Socket(host, port)
                    socket!!.tcpNoDelay = true 
                    val inputStream: InputStream = socket!!.getInputStream()
                    val headerBuffer = ByteArray(4)
                    
                    onStateChange(ClientState.Connected)
                    
                    while (isRunning.get()) {
                        readFully(inputStream, headerBuffer)
                        val length = ByteBuffer.wrap(headerBuffer).int
                        
                        if (length > 0) {
                            if (length > buffer.size) {
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
                    onStateChange(ClientState.Disconnected)
                    // Sleep before retry to prevent tight loop spamming
                    try { Thread.sleep(2000) } catch (e: InterruptedException) {}
                } finally {
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
            // Ignore
        }
    }
}
