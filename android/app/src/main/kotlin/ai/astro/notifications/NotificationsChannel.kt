package ai.astro.notifications

import ai.astro.nav.NavListenerService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Exposes the notifications buffered by [NavListenerService] to the
 *  read_notifications tool. `getRecent(count)` → newest-first list of
 *  `{app, title, text, time}`. Empty when there's no notification access or
 *  nothing has arrived since the listener connected. */
class NotificationsChannel(messenger: BinaryMessenger) {
    @Suppress("unused")
    private val channel = MethodChannel(messenger, CHANNEL).also {
        it.setMethodCallHandler { call, result ->
            when (call.method) {
                "getRecent" -> result.success(
                    NavListenerService.recent(call.argument<Int>("count") ?: 10),
                )
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val CHANNEL = "astro/notifications"
    }
}
