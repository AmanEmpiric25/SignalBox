package com.signalbox.signalbox

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Bridges the Android notification listener to Dart.
 *
 * The listener service and the Flutter engine have independent lifecycles, so
 * events are buffered while Dart is not listening and replayed on attach.
 */
object NotificationStreamHandler : EventChannel.StreamHandler {

    private const val MAX_BUFFERED_EVENTS = 100

    private val mainHandler = Handler(Looper.getMainLooper())
    private val buffer = ArrayDeque<Map<String, Any?>>()

    private var sink: EventChannel.EventSink? = null

    @Volatile
    private var listenerConnected: Boolean = false

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        synchronized(buffer) {
            while (buffer.isNotEmpty()) {
                val event = buffer.removeFirst()
                mainHandler.post { sink?.success(event) }
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun emit(payload: Map<String, Any?>) {
        val currentSink = sink
        if (currentSink == null) {
            synchronized(buffer) {
                if (buffer.size >= MAX_BUFFERED_EVENTS) {
                    buffer.removeFirst()
                }
                buffer.addLast(payload)
            }
            return
        }
        mainHandler.post { currentSink.success(payload) }
    }

    fun setListenerConnected(connected: Boolean) {
        listenerConnected = connected
    }

    fun isListenerConnected(): Boolean = listenerConnected
}
