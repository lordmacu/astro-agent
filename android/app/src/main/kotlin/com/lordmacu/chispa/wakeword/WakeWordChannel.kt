package com.lordmacu.chispa.wakeword

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Build
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
    private var bound = false

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            val svc = (binder as? WakeWordService.LocalBinder)?.service() ?: return
            service = svc
            svc.onDetect = { phraseId -> main.post { sink?.success(phraseId) } }
            svc.startListening()
        }
        override fun onServiceDisconnected(name: ComponentName?) {
            service?.onDetect = null
            service = null
        }
    }

    init {
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, s: EventChannel.EventSink?) { sink = s }
            override fun onCancel(args: Any?) { sink = null }
        })
        control.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    if (hasRecordAudio()) { bindAndStart(); result.success(true) }
                    else { result.success(false) }
                }
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

    private fun hasRecordAudio(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    private fun bindAndStart() {
        val intent = Intent(context, WakeWordService::class.java)
        context.startForegroundService(intent)
        context.bindService(intent, connection, Context.BIND_AUTO_CREATE)
        bound = true
    }

    /** Called by the host Activity once RECORD_AUDIO is granted, to start what
     *  an earlier start() call skipped. Guards on [bound] (not [service]) so a
     *  pending bindService (service still null, bind already in flight) is not
     *  double-bound. */
    fun startIfPermitted() {
        if (hasRecordAudio() && !bound) bindAndStart()
    }

    private fun stop() {
        if (bound) {
            runCatching { context.unbindService(connection) }
            bound = false
        }
        context.stopService(Intent(context, WakeWordService::class.java))
        service = null
    }
}
