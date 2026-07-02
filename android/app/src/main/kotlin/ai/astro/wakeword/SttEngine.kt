package ai.astro.wakeword

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import java.text.Normalizer

/** Always-on wake word using Android's SpeechRecognizer (on-device when the
 *  language pack is present), restarted in a loop so it never sleeps. Detects
 *  [keyword] in Spanish and calls [onDetect]. Same control surface as
 *  WakeWordEngine so [WakeWordService] can host either engine. Heavier than
 *  openWakeWord, but uses Google's Spanish recognition (no trained model) and,
 *  living in the foreground service, keeps listening in the background. */
class SttEngine(
    private val context: Context,
    keyword: String = "hola astro",
    private val locale: String = "es-ES",
    private val onDetect: (String) -> Unit,
) : WakeEngine {
    /** The phrase to match; mutable so Settings can change it at runtime. */
    @Volatile private var keyword: String = keyword.trim().ifEmpty { "hola astro" }
    private val main = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null

    @Volatile private var running = false
    @Volatile private var paused = false

    private val intent: Intent by lazy {
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            // NOTE: offline (EXTRA_PREFER_OFFLINE + on-device recognizer) needs the
            // es-ES language pack installed; without it the recognizer throws
            // LANGUAGE_PACK_ERROR. Use the network recognizer for now (works today);
            // for true in-car offline, install the Spanish offline pack and switch
            // back to createOnDeviceSpeechRecognizer + EXTRA_PREFER_OFFLINE.
        }
    }

    private var downloadTried = false

    override fun start() {
        if (running) return
        running = true
        paused = false
        main.post {
            triggerOfflineDownload()
            ensureAndListen()
        }
    }

    /** Ask the system to download the on-device model for [locale] (needs internet
     *  once). After it lands, offline recognition works in the car. Fire-and-forget;
     *  the network recognizer keeps working meanwhile. */
    private fun triggerOfflineDownload() {
        if (downloadTried || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        downloadTried = true
        runCatching {
            if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) return
            val dl = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                )
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            }
            dl.triggerModelDownload(i)
            Log.d(TAG, "requested offline model download for $locale")
            main.postDelayed({ runCatching { dl.destroy() } }, 120_000)
        }.onFailure { Log.w(TAG, "model download trigger failed: ${it.message}") }
    }

    private fun ensureAndListen() {
        if (!running) return
        if (recognizer == null) {
            // Network recognizer: works without the offline pack (needs connectivity).
            recognizer = SpeechRecognizer.createSpeechRecognizer(context)
                .also { it.setRecognitionListener(listener) }
        }
        if (!paused) runCatching { recognizer?.startListening(intent) }
    }

    private fun restart(delayMs: Long) {
        if (!running || paused) return
        main.postDelayed({
            if (running && !paused) {
                runCatching {
                    recognizer?.cancel()
                    recognizer?.startListening(intent)
                }
            }
        }, delayMs)
    }

    private val listener = object : RecognitionListener {
        override fun onPartialResults(partialResults: Bundle?) = check(partialResults)
        override fun onResults(results: Bundle?) {
            check(results)
            restart(200) // a full result ends the session; keep going
        }

        override fun onError(error: Int) {
            // NO_MATCH / SPEECH_TIMEOUT are normal in a quiet loop; just restart.
            restart(400)
        }

        override fun onReadyForSpeech(params: Bundle?) {}
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    private fun check(bundle: Bundle?) {
        val hyps = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION) ?: return
        val target = normalize(keyword)
        for (text in hyps) {
            if (normalize(text).contains(target)) {
                Log.d(TAG, "wake heard: \"$text\"")
                onDetect(keyword)
                return
            }
        }
    }

    private fun normalize(s: String): String =
        Normalizer.normalize(s.lowercase(), Normalizer.Form.NFD)
            .replace("\\p{Mn}+".toRegex(), "")

    /** Stop listening (e.g. while Astro speaks) without tearing down. */
    override fun pause() {
        paused = true
        main.post { runCatching { recognizer?.cancel() } }
    }

    override fun resume() {
        if (!paused) return
        paused = false
        restart(150)
    }

    /** No-op: STT has no per-phrase threshold. */
    override fun setThreshold(phraseId: String, value: Float) {}

    /** Change the phrase to match; free-form recognition needs no restart. */
    override fun setKeyword(word: String) {
        val w = word.trim()
        if (w.isNotEmpty()) keyword = w
    }

    /** No-op: the Google recognizer has no confidence gate to tune. */
    override fun setSensitivity(value: Float) {}

    override fun close() {
        running = false
        main.post {
            runCatching { recognizer?.destroy() }
            recognizer = null
        }
    }

    companion object {
        private const val TAG = "SttEngine"
    }
}
