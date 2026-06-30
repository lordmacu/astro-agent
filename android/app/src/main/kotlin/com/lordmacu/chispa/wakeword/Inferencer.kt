package com.lordmacu.chispa.wakeword

import android.content.res.AssetManager
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel

/** One TFLite (or, parked, ONNX) model stage. Shapes are read from the model,
 *  so swapping a retrained model never requires code changes. */
interface Inferencer {
    /** Output tensor shape, e.g. [1, 96] or [1, frames, 32]. */
    val outputShape: IntArray
    /** Run one inference over a flat float input; returns a flat float output. */
    fun run(input: FloatArray): FloatArray
    fun close()
}

/** TFLite-backed stage. Loads [assetPath] from the APK assets via mmap. */
class TfliteModel(assets: AssetManager, assetPath: String) : Inferencer {
    private val interpreter: Interpreter

    init {
        val fd = assets.openFd(assetPath)
        val model = fd.createInputStream().channel.use { channel ->
            channel.map(FileChannel.MapMode.READ_ONLY, fd.startOffset, fd.declaredLength)
        }
        fd.close()
        interpreter = Interpreter(model)
    }

    override val outputShape: IntArray get() = interpreter.getOutputTensor(0).shape()

    override fun run(input: FloatArray): FloatArray {
        val inShape = interpreter.getInputTensor(0).shape()
        // Resize the input tensor to the flat length we feed, then run.
        interpreter.resizeInput(0, intArrayOf(1, input.size / batchInner(inShape)))
        interpreter.allocateTensors()

        val inBuf = ByteBuffer.allocateDirect(input.size * 4).order(ByteOrder.nativeOrder())
        for (v in input) inBuf.putFloat(v)
        inBuf.rewind()

        val outLen = outputShape.fold(1) { a, b -> a * if (b <= 0) 1 else b }
        val outBuf = ByteBuffer.allocateDirect(outLen * 4).order(ByteOrder.nativeOrder())
        interpreter.run(inBuf, outBuf)

        outBuf.rewind()
        return FloatArray(outLen) { outBuf.float }
    }

    private fun batchInner(shape: IntArray): Int =
        if (shape.size <= 1) 1 else shape.drop(1).fold(1) { a, b -> a * if (b <= 0) 1 else b }
            .let { if (it == 0) 1 else it }

    /** Number of frames the input tensor expects (its second-to-last dim),
     *  or 1 for a flat/variable input. */
    fun inputFrameCount(): Int {
        val shape = interpreter.getInputTensor(0).shape()
        return when {
            shape.size >= 2 && shape[shape.size - 2] > 0 -> shape[shape.size - 2]
            else -> 1
        }
    }

    override fun close() = interpreter.close()
}
