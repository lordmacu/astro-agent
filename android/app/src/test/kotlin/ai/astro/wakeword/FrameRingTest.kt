package ai.astro.wakeword

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FrameRingTest {
    @Test fun fillsThenReportsFull() {
        val ring = FrameRing(capacity = 2, width = 1)
        assertFalse(ring.isFull())
        ring.push(floatArrayOf(1f))
        assertFalse(ring.isFull())
        ring.push(floatArrayOf(2f))
        assertTrue(ring.isFull())
    }

    @Test fun snapshotIsOldestToNewestAndEvicts() {
        val ring = FrameRing(capacity = 2, width = 1)
        ring.push(floatArrayOf(1f))
        ring.push(floatArrayOf(2f))
        ring.push(floatArrayOf(3f)) // evicts 1
        val snap = ring.snapshot()
        assertEquals(2, snap.size)
        assertArrayEquals(floatArrayOf(2f), snap[0], 0f)
        assertArrayEquals(floatArrayOf(3f), snap[1], 0f)
    }

    @Test fun clearEmptiesBuffer() {
        val ring = FrameRing(capacity = 2, width = 1)
        ring.push(floatArrayOf(1f)); ring.push(floatArrayOf(2f))
        ring.clear()
        assertFalse(ring.isFull())
        assertEquals(0, ring.snapshot().size)
    }
}
