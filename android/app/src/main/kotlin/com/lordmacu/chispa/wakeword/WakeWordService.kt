package com.lordmacu.chispa.wakeword

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.IBinder

/** Always-on foreground service (type microphone) that hosts the wake-word
 *  engine so the mic survives backgrounding. Bound by [WakeWordChannel]. */
class WakeWordService : Service() {
    private val binder = LocalBinder()
    private var engine: WakeWordEngine? = null

    /** Set by the channel; receives the phrase id that fired. */
    var onDetect: ((String) -> Unit)? = null

    inner class LocalBinder : Binder() {
        fun service(): WakeWordService = this@WakeWordService
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        // API 29+ requires the typed 3-arg form for foregroundServiceType="microphone";
        // mandatory on API 34+ (throws MissingForegroundServiceTypeException otherwise).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIF_ID,
                buildNotification(),
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(NOTIF_ID, buildNotification())
        }
        engine = WakeWordEngine(assets) { phraseId -> onDetect?.invoke(phraseId) }
    }

    fun startListening() = engine?.start()
    fun pause() = engine?.pause()
    fun resume() = engine?.resume()
    fun setThreshold(phraseId: String, value: Float) = engine?.setThreshold(phraseId, value)

    override fun onDestroy() {
        engine?.close()
        engine = null
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        val mgr = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            mgr.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Chispa", NotificationManager.IMPORTANCE_LOW),
            )
        }
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Chispa")
            .setContentText("Escuchando \"Oye Chispa\"")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "chispa_wakeword"
        private const val NOTIF_ID = 42
    }
}
