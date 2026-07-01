package com.lordmacu.astro.wakeword

/** Turns a stream of per-hop scores into discrete wake events: requires
 *  [minConsecutive] hops at/above [threshold], then suppresses for
 *  [refractoryFrames] hops. Pure — no Android deps, fully unit-tested. */
class WakeDebouncer(
    threshold: Float,
    private val minConsecutive: Int,
    private val refractoryFrames: Int,
) {
    private var threshold: Float = threshold
    private var consecutive = 0
    private var cooldown = 0

    /** Update the firing threshold at runtime (on-device calibration). */
    fun setThreshold(value: Float) {
        threshold = value
    }

    /** Returns true on exactly the hop a wake should fire. */
    fun update(score: Float): Boolean {
        if (cooldown > 0) {
            cooldown--
            consecutive = 0
            return false
        }
        if (score >= threshold) {
            consecutive++
            if (consecutive >= minConsecutive) {
                consecutive = 0
                cooldown = refractoryFrames
                return true
            }
        } else {
            consecutive = 0
        }
        return false
    }
}
