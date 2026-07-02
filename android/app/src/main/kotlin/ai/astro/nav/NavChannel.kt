package ai.astro.nav

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Bridges [NavListenerService] to Dart: an EventChannel of raw notification
 *  maps and a MethodChannel for the notification-access permission. */
class NavChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val main = Handler(Looper.getMainLooper())

    @Suppress("unused")
    private val events = EventChannel(messenger, EVENTS).also {
        it.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                NavListenerService.sink = { event ->
                    // EventSink must be used on the main thread.
                    main.post { sink?.success(event) }
                }
            }

            override fun onCancel(arguments: Any?) {
                NavListenerService.sink = null
            }
        })
    }

    @Suppress("unused")
    private val control = MethodChannel(messenger, CONTROL).also {
        it.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasAccess())
                "openSettings" -> {
                    context.startActivity(
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasAccess(): Boolean {
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return enabled.split(":").any { it.contains(context.packageName) }
    }

    companion object {
        private const val EVENTS = "astro/nav"
        private const val CONTROL = "astro/nav/control"
    }
}
