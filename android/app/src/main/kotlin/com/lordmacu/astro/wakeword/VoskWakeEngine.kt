package com.lordmacu.astro.wakeword

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import java.io.File
import java.io.FileOutputStream
import java.text.Normalizer
import java.util.zip.ZipInputStream

/** Always-on wake word using OFFLINE Vosk — no Google recognizer, no language
 *  pack, no network. Unpacks the bundled Spanish model once, then runs
 *  continuous recognition biased (via a grammar) toward [keyword], calling
 *  [onDetect] when it's heard. Same control surface as [SttEngine] so
 *  [WakeWordService] can host either. On [pause] it fully stops the mic so the
 *  Dart-side Vosk command recognizer can use it; [resume] restarts. */
class VoskWakeEngine(
    private val context: Context,
    keyword: String = "hola astro",
    private val onDetect: (String) -> Unit,
) : WakeEngine {
    /** The phrase to listen for. Mutable so Settings can change it at runtime;
     *  a change rebuilds the grammar and restarts recognition. May be several
     *  words (e.g. "hola astro"): every word must be heard, in order. */
    @Volatile private var keyword: String = keyword.trim().ifEmpty { "hola astro" }
    private val main = Handler(Looper.getMainLooper())

    private var model: Model? = null
    private var recognizer: Recognizer? = null
    private var speechService: SpeechService? = null

    @Volatile private var running = false
    @Volatile private var paused = false

    /** Minimum keyword confidence to fire, driven by the Settings sensitivity
     *  slider (see [setSensitivity]). Higher = stricter (fewer false wakes). */
    @Volatile private var minConf = DEFAULT_MIN_CONF

    /** Throws if the model can't load, so the caller can fall back to STT. */
    override fun start() {
        if (running) return
        running = true
        paused = false
        Thread {
            try {
                val dir = ensureModel()
                model = Model(dir.absolutePath)
                main.post { if (running && !paused) startRecognition() }
                Log.d(TAG, "Vosk wake model loaded from ${dir.absolutePath}")
            } catch (e: Exception) {
                Log.e(TAG, "Vosk wake init failed: ${e.message}", e)
                running = false
                main.post { onInitError?.invoke() }
            }
        }.start()
    }

    /** Called on the main thread if the model fails to load. */
    var onInitError: (() -> Unit)? = null

    private fun startRecognition() {
        val m = model ?: return
        if (speechService != null) return
        // Grammar biases toward the keyword; "[unk]" absorbs everything else so
        // random speech doesn't get force-matched to "astro".
        val rec = Recognizer(m, SAMPLE_RATE, "[\"$keyword\", \"[unk]\"]")
        rec.setWords(true) // per-word confidences, to gate false wakes
        val svc = SpeechService(rec, SAMPLE_RATE)
        recognizer = rec
        speechService = svc
        svc.startListening(listener)
    }

    private val listener = object : RecognitionListener {
        // Partials are noisy and have no confidence — ignore them; only a final
        // result with a confident "astro" word fires the wake.
        override fun onPartialResult(hypothesis: String?) {}
        override fun onResult(hypothesis: String?) = handle(hypothesis)
        override fun onFinalResult(hypothesis: String?) = handle(hypothesis)
        override fun onError(e: Exception?) {
            Log.w(TAG, "vosk wake error: ${e?.message}")
        }
        override fun onTimeout() {}
    }

    private fun handle(hypothesis: String?) {
        if (paused || hypothesis == null) return
        val json = try {
            JSONObject(hypothesis)
        } catch (_: Exception) {
            return
        }
        val text = json.optString("text", "")
        if (text.isEmpty() || !normalize(text).contains(normalize(keyword))) return

        val conf = keywordConfidence(json)
        Log.d(TAG, "wake candidate \"$text\" conf=$conf (min=$minConf)")
        if (conf >= minConf) {
            Log.d(TAG, "wake heard: \"$text\" (conf=$conf)")
            onDetect(keyword)
        }
    }

    /** Confidence that the keyword phrase was heard, from a `setWords`-enabled
     *  result. For a multi-word phrase every word must be confident, so we take
     *  the WORST per-word confidence (a phrase is only as strong as its weakest
     *  word). Falls back to 1.0 when no per-word data is present (older models). */
    private fun keywordConfidence(json: JSONObject): Double {
        val arr = json.optJSONArray("result") ?: return 1.0
        val tokens = normalize(keyword).split(" ").filter { it.isNotEmpty() }
        if (tokens.isEmpty()) return 1.0
        var worst = 1.0
        for (token in tokens) {
            var best = 0.0
            for (i in 0 until arr.length()) {
                val w = arr.optJSONObject(i) ?: continue
                if (normalize(w.optString("word", "")).contains(token)) {
                    best = maxOf(best, w.optDouble("conf", 0.0))
                }
            }
            worst = minOf(worst, best)
        }
        return worst
    }

    /** Stop listening AND release the mic, so the command recognizer can use it. */
    override fun pause() {
        paused = true
        main.post { stopRecognition() }
    }

    override fun resume() {
        if (!paused) return
        paused = false
        main.post { if (running) startRecognition() }
    }

    /** No-op: Vosk has no per-phrase threshold here. */
    override fun setThreshold(phraseId: String, value: Float) {}

    /** Map the Settings sensitivity (0..1) to a confidence gate. 0.5 keeps the
     *  original 0.75 gate; higher sensitivity lowers it (fires more easily),
     *  lower raises it (stricter, fewer false wakes). No restart needed. */
    override fun setSensitivity(value: Float) {
        val s = value.coerceIn(0f, 1f)
        minConf = (1.0 - 0.5 * s).coerceIn(MIN_CONF_FLOOR, MIN_CONF_CEIL)
        Log.d(TAG, "sensitivity=$s → minConf=$minConf")
    }

    /** Change the phrase to listen for at runtime. Rebuilds the grammar and, if
     *  we're actively listening, restarts recognition so the new grammar takes. */
    override fun setKeyword(word: String) {
        val w = word.trim()
        if (w.isEmpty() || normalize(w) == normalize(keyword)) return
        keyword = w
        Log.d(TAG, "wake keyword set to \"$w\"")
        if (running && !paused) {
            main.post {
                stopRecognition()
                startRecognition()
            }
        }
    }

    override fun close() {
        running = false
        main.post {
            stopRecognition()
            model?.close()
            model = null
        }
    }

    private fun stopRecognition() {
        runCatching { speechService?.stop() }
        runCatching { speechService?.shutdown() }
        speechService = null
        runCatching { recognizer?.close() }
        recognizer = null
    }

    /** Unzip the bundled model once to app storage; return its directory. */
    private fun ensureModel(): File {
        val root = File(context.filesDir, "vosk-wake")
        val out = File(root, MODEL_DIR)
        // A known model file means it's already unpacked.
        if (File(out, "am/final.mdl").exists()) return out

        root.mkdirs()
        context.assets.open("flutter_assets/assets/models/$MODEL_ZIP").use { input ->
            ZipInputStream(input.buffered()).use { zis ->
                var entry = zis.nextEntry
                while (entry != null) {
                    val file = File(root, entry.name)
                    if (entry.isDirectory) {
                        file.mkdirs()
                    } else {
                        file.parentFile?.mkdirs()
                        FileOutputStream(file).use { zis.copyTo(it) }
                    }
                    entry = zis.nextEntry
                }
            }
        }
        return out
    }

    private fun normalize(s: String): String =
        Normalizer.normalize(s.lowercase(), Normalizer.Form.NFD)
            .replace("\\p{Mn}+".toRegex(), "")

    companion object {
        private const val TAG = "VoskWakeEngine"
        private const val SAMPLE_RATE = 16000f
        private const val DEFAULT_MIN_CONF = 0.75 // gate at 0.5 sensitivity
        private const val MIN_CONF_FLOOR = 0.5 // loosest allowed (max sensitivity)
        private const val MIN_CONF_CEIL = 1.0 // strictest allowed (min sensitivity)
        private const val MODEL_ZIP = "vosk-model-small-es-0.42.zip"
        private const val MODEL_DIR = "vosk-model-small-es-0.42"
    }
}
