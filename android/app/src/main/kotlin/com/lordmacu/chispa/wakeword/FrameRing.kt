package com.lordmacu.chispa.wakeword

/** Fixed-size rolling window of equal-width float frames. Holds the latest
 *  [capacity] frames; [snapshot] returns them oldest→newest as the dense input
 *  the next model stage expects. Pure — unit-tested. */
class FrameRing(private val capacity: Int, private val width: Int) {
    private val buf = ArrayDeque<FloatArray>(capacity)

    fun push(frame: FloatArray) {
        require(frame.size == width) { "frame width ${frame.size} != $width" }
        if (buf.size == capacity) buf.removeFirst()
        buf.addLast(frame)
    }

    fun isFull(): Boolean = buf.size == capacity

    fun snapshot(): Array<FloatArray> = Array(buf.size) { buf[it] }

    fun clear() = buf.clear()
}
