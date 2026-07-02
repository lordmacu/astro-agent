package ai.astro.wakeword

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log
import ai.astro.R

/** Always-on foreground service (type microphone) that hosts the wake-word
 *  engine so the mic survives backgrounding. Bound by [WakeWordChannel].
 *
 *  Precondition: RECORD_AUDIO must be granted BEFORE the service is started.
 *  [WakeWordChannel] enforces this gate; the service therefore never needs to
 *  call stopSelf() before startForeground() (which would cause an ANR). */
class WakeWordService : Service() {
    private val binder = LocalBinder()
    private var engine: WakeEngine? = null
    private var started = false

    /** The phrase to listen for; the channel pushes the user's Settings value.
     *  Kept here so a fallback engine (or a re-created one) inherits it. */
    private var keyword = "hola astro"

    /** Detection sensitivity (0..1) from Settings; remembered like [keyword]. */
    private var sensitivity = 0.5f

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

        // Offline Vosk wake word (no Google, no language pack), hosted in this
        // foreground service so it keeps listening in the background. If the Vosk
        // model can't load, fall back to Google's SpeechRecognizer (SttEngine).
        val vosk = VoskWakeEngine(applicationContext, keyword) { phraseId ->
            onDetect?.invoke(phraseId)
        }
        vosk.setSensitivity(sensitivity)
        vosk.onInitError = {
            Log.w(TAG, "Vosk wake failed; falling back to Google STT")
            runCatching { vosk.close() }
            val stt = SttEngine(applicationContext, keyword = keyword) { phraseId ->
                onDetect?.invoke(phraseId)
            }
            engine = stt
            if (started) stt.start()
        }
        engine = vosk
    }

    /** Update the wake phrase (from Settings). Remembered so a re-created or
     *  fallback engine inherits it too. */
    fun setKeyword(word: String) {
        val w = word.trim()
        if (w.isEmpty()) return
        keyword = w
        engine?.setKeyword(w)
    }

    /** Update detection sensitivity (from Settings). Remembered for re-creation. */
    fun setSensitivity(value: Float) {
        sensitivity = value.coerceIn(0f, 1f)
        engine?.setSensitivity(sensitivity)
    }

    fun startListening() {
        started = true
        engine?.start()
    }

    fun pause() {
        engine?.pause()
    }

    fun resume() {
        engine?.resume()
    }

    fun setThreshold(phraseId: String, value: Float) {
        engine?.setThreshold(phraseId, value)
    }

    override fun onDestroy() {
        engine?.close()
        engine = null
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        val mgr = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            mgr.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Astro", NotificationManager.IMPORTANCE_LOW),
            )
        }
        // Tapping the notification opens the app, just like the launcher icon:
        // reuse the existing task if Astro is already running instead of stacking
        // a new activity.
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(this, 0, it, piFlags)
        }

        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Astro")
            .setContentText("Escuchando \"$keyword\"")
            // Status-bar icon must be a monochrome silhouette (Android tints it);
            // the colored Astro shows as the large icon in the expanded view.
            .setSmallIcon(R.drawable.ic_notification)
            .setLargeIcon(
                BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher),
            )
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val TAG = "WakeWordService"
        private const val CHANNEL_ID = "astro_wakeword"
        private const val NOTIF_ID = 42
    }
}
