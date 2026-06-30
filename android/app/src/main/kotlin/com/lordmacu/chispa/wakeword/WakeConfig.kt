package com.lordmacu.chispa.wakeword

/** One phrase's firing policy. Short words (e.g. "chispa") get a higher
 *  threshold than longer ones ("oye chispa") to curb false positives. */
data class PhrasePolicy(
    val assetFile: String,
    /** Firing threshold in [0,1]. Mutable on purpose: WakeWordEngine.setThreshold()
     *  adjusts it at runtime for on-device calibration. */
    var threshold: Float,
    val minConsecutive: Int,
    val refractoryFrames: Int,
)

/** All wake-word numeric knobs in one place (native analog of thresholds.dart). */
object WakeConfig {
    const val SAMPLE_RATE = 16_000
    const val HOP_SAMPLES = 1_280 // 80 ms at 16 kHz

    /** Fallback embedding/classifier window length when a model's input rank
     *  doesn't expose a frame dimension. */
    const val DEFAULT_WINDOW_FRAMES = 16

    const val MELSPEC_ASSET = "oww/melspectrogram.tflite"
    const val EMBEDDING_ASSET = "oww/embedding.tflite"

    // refractoryFrames are counted in hops (~80 ms each): ~25 ≈ 2 s.
    val phrases = listOf(
        PhrasePolicy("oww/oye_chispa.tflite", threshold = 0.5f, minConsecutive = 2, refractoryFrames = 25),
        PhrasePolicy("oww/chispa.tflite",     threshold = 0.7f, minConsecutive = 3, refractoryFrames = 25),
    )

    fun phraseId(assetFile: String): String =
        assetFile.substringAfterLast('/').removeSuffix(".tflite")
}
