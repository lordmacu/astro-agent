package ai.astro.media

import android.app.SearchManager
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.media.MediaActionSound
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import android.view.KeyEvent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Bridges Astro's `music` tool to the phone's media stack, no root and no app
 *  lock-in:
 *   - play(query): fires MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH so the
 *     user's default music app starts playing the request.
 *   - pause/resume/next/previous: dispatches media-button key events to whatever
 *     media session is active (works across Spotify, YouTube Music, local, ...).
 *  Methods return true on a best-effort dispatch, false if nothing handled it. */
class MediaChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val actionSound = MediaActionSound()

    private val channel = MethodChannel(messenger, CHANNEL).also {
        it.setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> result.success(play(call.argument<String>("query") ?: ""))
                "pause" -> result.success(sendKey(KeyEvent.KEYCODE_MEDIA_PAUSE))
                "resume" -> result.success(sendKey(KeyEvent.KEYCODE_MEDIA_PLAY))
                "next" -> result.success(sendKey(KeyEvent.KEYCODE_MEDIA_NEXT))
                "previous" -> result.success(sendKey(KeyEvent.KEYCODE_MEDIA_PREVIOUS))
                "setVolume" -> result.success(setVolume(call.argument<Double>("level") ?: 0.0))
                "nudgeVolume" -> result.success(nudgeVolume(call.argument<Int>("direction") ?: 0))
                "beep" -> result.success(beep())
                "shutter" -> result.success(shutter())
                "torch" -> result.success(torch(call.argument<Boolean>("on") ?: false))
                else -> result.notImplemented()
            }
        }
    }

    private fun play(query: String): Boolean {
        val intent = Intent(MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (query.isNotBlank()) {
                putExtra(SearchManager.QUERY, query)
                putExtra(MediaStore.EXTRA_MEDIA_FOCUS, "vnd.android.cursor.item/*")
            }
        }
        return runCatching {
            if (intent.resolveActivity(context.packageManager) != null) {
                context.startActivity(intent)
                true
            } else {
                false
            }
        }.getOrDefault(false)
    }

    private fun sendKey(keyCode: Int): Boolean {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            ?: return false
        return runCatching {
            audio.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
            audio.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, keyCode))
            true
        }.getOrDefault(false)
    }

    /** Set the media stream volume to [level] (0..1). */
    private fun setVolume(level: Double): Boolean {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            ?: return false
        return runCatching {
            val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val target = (level.coerceIn(0.0, 1.0) * max).toInt()
            audio.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
            true
        }.getOrDefault(false)
    }

    /** Nudge the media volume up (+1) or down (-1) by one step. */
    private fun nudgeVolume(direction: Int): Boolean {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            ?: return false
        val dir = when {
            direction > 0 -> AudioManager.ADJUST_RAISE
            direction < 0 -> AudioManager.ADJUST_LOWER
            else -> return false
        }
        return runCatching {
            audio.adjustStreamVolume(AudioManager.STREAM_MUSIC, dir, AudioManager.FLAG_SHOW_UI)
            true
        }.getOrDefault(false)
    }

    /** Short "listening" earcon so the driver knows when to speak. Uses the
     *  system ToneGenerator (no audio asset). Best-effort. */
    private fun beep(): Boolean = runCatching {
        val tone = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
        tone.startTone(ToneGenerator.TONE_PROP_BEEP2, 180)
        // Release after the tone finishes so we don't leak the generator.
        Handler(Looper.getMainLooper()).postDelayed({ tone.release() }, 400)
        true
    }.getOrDefault(false)

    /** Play the system camera shutter sound. Uses MediaActionSound, which honors
     *  the device's shutter-sound policy (silent mode). Best-effort. */
    private fun shutter(): Boolean = runCatching {
        actionSound.play(MediaActionSound.SHUTTER_CLICK)
        true
    }.getOrDefault(false)

    /** Toggle the flashlight via CameraManager (no permission needed). To turn
     *  ON, use the first back camera with a flash; to turn OFF, clear the torch
     *  on EVERY flash-capable camera, so it reliably goes off even if a
     *  different camera was lit. Verbose logs so failures are visible. */
    private fun torch(on: Boolean): Boolean {
        val cm = context.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
        if (cm == null) {
            Log.w(TAG, "torch($on): no CameraManager")
            return false
        }
        val ids = try {
            cm.cameraIdList
        } catch (e: Exception) {
            Log.e(TAG, "torch($on): cameraIdList failed: ${e.message}", e)
            return false
        }
        Log.d(TAG, "torch($on): cameras=${ids.joinToString()}")

        var handled = false
        for (id in ids) {
            val chars = try {
                cm.getCameraCharacteristics(id)
            } catch (e: Exception) {
                Log.w(TAG, "torch: chars[$id] failed: ${e.message}")
                continue
            }
            val hasFlash =
                chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            val facing = chars.get(CameraCharacteristics.LENS_FACING)
            Log.d(TAG, "torch: camera $id flash=$hasFlash facing=$facing")
            if (!hasFlash) continue

            if (on) {
                val back = facing == CameraCharacteristics.LENS_FACING_BACK
                if (!back) continue
                try {
                    cm.setTorchMode(id, true)
                    Log.d(TAG, "torch: ON via camera $id")
                    return true
                } catch (e: Exception) {
                    Log.e(TAG, "torch: ON camera $id failed: ${e.message}", e)
                }
            } else {
                try {
                    cm.setTorchMode(id, false)
                    Log.d(TAG, "torch: OFF via camera $id")
                    handled = true
                } catch (e: Exception) {
                    Log.e(TAG, "torch: OFF camera $id failed: ${e.message}", e)
                }
            }
        }
        Log.d(TAG, "torch($on): handled=$handled")
        return handled
    }

    companion object {
        private const val CHANNEL = "astro/media"
        private const val TAG = "MediaChannel"
    }
}
