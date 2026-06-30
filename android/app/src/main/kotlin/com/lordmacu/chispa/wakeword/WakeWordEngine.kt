package com.lordmacu.chispa.wakeword

import android.annotation.SuppressLint
import android.content.res.AssetManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import kotlin.concurrent.thread

/** openWakeWord streaming engine: mic → melspectrogram → embedding → per-phrase
 *  classifiers → debouncers → [onWake](phraseId). Window sizes come from each
 *  model's I/O shape (read at load), never hardcoded.
 *
 *  Pause/resume design (deliberate trade-off): [pause] keeps [AudioRecord] open
 *  and the inference loop running, but discards audio. This avoids the startup
 *  latency and glitches that stopping and restarting the recorder would cause on
 *  an always-on dashboard device. [resume] clears the rolling mel and embedding
 *  windows so detection restarts from a clean state after the silent gap. */
class WakeWordEngine(
    private val assets: AssetManager,
    private val onWake: (String) -> Unit,
) {
    private val melspec = TfliteModel(assets, WakeConfig.MELSPEC_ASSET)
    private val embedding = TfliteModel(assets, WakeConfig.EMBEDDING_ASSET)

    private data class Phrase(
        val id: String,
        val model: Inferencer,
        val debouncer: WakeDebouncer,
        val policy: PhrasePolicy,
    )

    private val phrases: List<Phrase> = WakeConfig.phrases.map { p ->
        Phrase(
            id = WakeConfig.phraseId(p.assetFile),
            model = TfliteModel(assets, p.assetFile),
            debouncer = WakeDebouncer(p.threshold, p.minConsecutive, p.refractoryFrames),
            policy = p,
        )
    }

    // melBins = melspec output width; embWindow = mel frames the embedding model
    // consumes; classWindow = embeddings the classifier consumes; embDim = embedding width.
    private val melBins = melspec.outputShape.last()
    private val embWindow = embedding.inputFrameCount()
    private val embDim = embedding.outputShape.last()
    private val classWindow = phrases.first().model.inputFrameCount()

    private val melRing = FrameRing(capacity = embWindow, width = melBins)
    private val embRing = FrameRing(capacity = classWindow, width = embDim)

    @Volatile private var running = false
    @Volatile private var paused = false
    private var worker: Thread? = null
    private var record: AudioRecord? = null

    fun setThreshold(phraseId: String, value: Float) {
        phrases.firstOrNull { it.id == phraseId }?.let {
            it.policy.threshold = value
            it.debouncer.setThreshold(value)
        }
    }

    /** Suppresses detection without stopping [AudioRecord]. The inference loop
     *  keeps running but discards all audio while paused, avoiding the startup
     *  latency and glitches of stopping/restarting the recorder. Call this on
     *  TTS start so Chispa doesn't hear herself speak. */
    fun pause() { paused = true }

    /** Re-enables detection and clears the rolling mel and embedding windows so
     *  the first post-resume detection window starts from a clean state (no
     *  pre-pause frames straddling the gap). Call this on TTS end. */
    fun resume() {
        melRing.clear()
        embRing.clear()
        paused = false
    }

    @SuppressLint("MissingPermission") // RECORD_AUDIO granted before the service starts
    fun start() {
        if (running) return
        running = true
        val minBuf = AudioRecord.getMinBufferSize(
            WakeConfig.SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        record = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            WakeConfig.SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            maxOf(minBuf, WakeConfig.HOP_SAMPLES * 2 * 4),
        ).apply { startRecording() }

        worker = thread(name = "wakeword-engine") { loop() }
    }

    private fun loop() {
        val pcm = ShortArray(WakeConfig.HOP_SAMPLES)
        val rec = record ?: return
        try {
            while (running) {
                val n = rec.read(pcm, 0, pcm.size)
                if (n <= 0 || paused) continue

                val audio = FloatArray(n) { pcm[it] / 32768f } // PCM16 -> [-1,1]
                val mels = melspec.run(audio) // flat: framesOut * melBins
                var off = 0
                while (off + melBins <= mels.size) {
                    melRing.push(mels.copyOfRange(off, off + melBins))
                    off += melBins
                }
                if (!melRing.isFull()) continue

                val emb = embedding.run(flatten(melRing.snapshot())) // embDim
                embRing.push(emb)
                if (!embRing.isFull()) continue

                val ctx = flatten(embRing.snapshot())
                for (p in phrases) {
                    val score = p.model.run(ctx).last() // classifier prob in [0,1]
                    if (p.debouncer.update(score)) onWake(p.id)
                }
            }
        } finally {
            rec.stop()
            rec.release()
        }
    }

    private fun flatten(frames: Array<FloatArray>): FloatArray {
        val out = FloatArray(frames.size * frames[0].size)
        var i = 0
        for (f in frames) for (v in f) out[i++] = v
        return out
    }

    fun stop() {
        running = false
        worker?.join(800)
        worker = null
        record = null
        melRing.clear()
        embRing.clear()
    }

    fun close() {
        stop()
        melspec.close(); embedding.close()
        phrases.forEach { it.model.close() }
    }
}

