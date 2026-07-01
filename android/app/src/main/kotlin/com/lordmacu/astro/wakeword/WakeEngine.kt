package com.lordmacu.astro.wakeword

/** Common control surface for a wake-word engine, so [WakeWordService] can host
 *  either the offline Vosk engine or the Google-SpeechRecognizer fallback. */
interface WakeEngine {
    fun start()
    fun pause()
    fun resume()
    fun setThreshold(phraseId: String, value: Float)

    /** Change the phrase the engine listens for (e.g. from Settings). */
    fun setKeyword(word: String)

    /** Set detection sensitivity in [0,1] (from the Settings slider). */
    fun setSensitivity(value: Float)
    fun close()
}
