package ai.astro.proximity

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/** Proximity as a near/far boolean, read straight from the sensor so we own the
 *  "near" test. The proximity_sensor plugin treats only `distance == 0` as near,
 *  which never fires on devices whose default TYPE_PROXIMITY is a "Palm" gesture
 *  sensor (some Samsungs) — it reports maxRange when clear and a smaller,
 *  non-zero value when covered. Android's real contract is: near when
 *  `value < maximumRange`. This channel uses that and emits a bool over the
 *  EventChannel `astro/proximity`. It logs the raw value + maxRange under the
 *  `AstroProximity` tag while we validate on device. */
class ProximityChannel(
    context: Context,
    messenger: BinaryMessenger,
) {
    private val sensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val sensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_PROXIMITY)
    private var listener: SensorEventListener? = null

    @Suppress("unused")
    private val channel = EventChannel(messenger, CHANNEL).also {
        it.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                val s = sensor
                if (s == null) {
                    Log.w(TAG, "no TYPE_PROXIMITY sensor available")
                    events?.success(false)
                    return
                }
                Log.d(TAG, "using '${s.name}' maxRange=${s.maximumRange}")
                val l = object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent) {
                        // Android's real near test: closer than the sensor's max.
                        // (The proximity_sensor plugin used `== 0`, which never
                        // fires on OEM "Palm" gesture sensors.)
                        events?.success(event.values[0] < s.maximumRange)
                    }

                    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                }
                listener = l
                sensorManager.registerListener(l, s, SensorManager.SENSOR_DELAY_NORMAL)
            }

            override fun onCancel(arguments: Any?) {
                listener?.let { sensorManager.unregisterListener(it) }
                listener = null
            }
        })
    }

    companion object {
        private const val CHANNEL = "astro/proximity"
        private const val TAG = "AstroProximity"
    }
}
