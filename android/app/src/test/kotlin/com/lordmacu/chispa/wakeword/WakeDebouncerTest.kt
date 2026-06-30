package com.lordmacu.chispa.wakeword

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class WakeDebouncerTest {
    @Test fun firesOnlyAfterEnoughConsecutiveHighScores() {
        val d = WakeDebouncer(threshold = 0.5f, minConsecutive = 3, refractoryFrames = 5)
        assertFalse(d.update(0.9f)) // 1
        assertFalse(d.update(0.9f)) // 2
        assertEquals(true, d.update(0.9f)) // 3 -> fire
    }

    @Test fun resetsConsecutiveOnALowScore() {
        val d = WakeDebouncer(threshold = 0.5f, minConsecutive = 2, refractoryFrames = 5)
        assertFalse(d.update(0.9f))
        assertFalse(d.update(0.1f)) // reset
        assertFalse(d.update(0.9f)) // 1 again
        assertEquals(true, d.update(0.9f)) // 2 -> fire
    }

    @Test fun suppressesDuringRefractoryWindow() {
        val d = WakeDebouncer(threshold = 0.5f, minConsecutive = 1, refractoryFrames = 3)
        assertEquals(true, d.update(0.9f)) // fire
        assertFalse(d.update(0.9f)) // cooldown 3
        assertFalse(d.update(0.9f)) // cooldown 2
        assertFalse(d.update(0.9f)) // cooldown 1
        assertEquals(true, d.update(0.9f)) // ready again
    }
}
