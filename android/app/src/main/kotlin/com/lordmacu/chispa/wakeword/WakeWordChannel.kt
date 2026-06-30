package com.lordmacu.chispa.wakeword

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Wires the Flutter Method/Event channels to the foreground [WakeWordService]. */
class WakeWordChannel(private val context: Context, messenger: BinaryMessenger) {
    private val control = MethodChannel(messenger, "chispa/wakeword/control")
    private val events = EventChannel(messenger, "chispa/wakeword")
    private val main = Handler(Looper.getMainLooper())

    private var sink: EventChannel.EventSink? = null
    private var service: WakeWordService? = null

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            val svc = (binder as WakeWordService.LocalBinder).service()
            service = svc
            svc.onDetect = { phraseId -> main.post { sink?.success(phraseId) } }
            svc.startListening()
        }
        override fun onServiceDisconnected(name: ComponentName?) { service = null }
    }

    init {
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, s: EventChannel.EventSink?) { sink = s }
            override fun onCancel(args: Any?) { sink = null }
        })
        control.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> { bindAndStart(); result.success(null) }
                "pause" -> { service?.pause(); result.success(null) }
                "resume" -> { service?.resume(); result.success(null) }
                "stop" -> { stop(); result.success(null) }
                "setThreshold" -> {
                    val phrase = call.argument<String>("phrase")
                    val value = (call.argument<Double>("value"))?.toFloat()
                    if (phrase != null && value != null) service?.setThreshold(phrase, value)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun bindAndStart() {
        val intent = Intent(context, WakeWordService::class.java)
        context.startForegroundService(intent)
        context.bindService(intent, connection, Context.BIND_AUTO_CREATE)
    }

    private fun stop() {
        service?.let { runCatching { context.unbindService(connection) } }
        context.stopService(Intent(context, WakeWordService::class.java))
        service = null
    }
}
