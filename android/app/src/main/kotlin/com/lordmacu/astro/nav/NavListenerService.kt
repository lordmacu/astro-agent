package com.lordmacu.astro.nav

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/** Forwards Google Maps turn-by-turn notification text to the app. Parsing lives
 *  in Dart (NavParser); this only extracts title/text and marks removals. A
 *  process-static sink lets [NavChannel] receive events without binding to the
 *  service instance (Android owns its lifecycle). */
class NavListenerService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val extras = sbn.notification?.extras
        val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString()

        if (sbn.packageName == MAPS_PKG) {
            Log.d(TAG, "maps posted: title='$title' text='$text'")
            sink?.invoke(
                mapOf("title" to title, "text" to text, "removed" to false),
            )
            return
        }

        // Buffer other apps' notifications for the read_notifications tool.
        // Skip ongoing (music, downloads), our own, and empty ones.
        val n = sbn.notification ?: return
        if ((n.flags and Notification.FLAG_ONGOING_EVENT) != 0) return
        if (sbn.packageName == packageName) return
        if (title.isNullOrBlank() && text.isNullOrBlank()) return
        record(
            mapOf(
                "app" to appLabel(sbn.packageName),
                "title" to title,
                "text" to text,
                "time" to sbn.postTime,
            ),
        )
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        if (sbn.packageName != MAPS_PKG) return
        sink?.invoke(mapOf("title" to null, "text" to null, "removed" to true))
    }

    private fun appLabel(pkg: String): String = try {
        val pm = packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    } catch (e: Exception) {
        pkg
    }

    companion object {
        private const val TAG = "AstroNav"
        private const val MAPS_PKG = "com.google.android.apps.maps"
        private const val CAP = 40

        /** Set by NavChannel while a Dart listener is active. */
        @Volatile
        var sink: ((Map<String, Any?>) -> Unit)? = null

        private val buffer = ArrayDeque<Map<String, Any?>>()

        private fun record(item: Map<String, Any?>) {
            synchronized(buffer) {
                buffer.addLast(item)
                while (buffer.size > CAP) buffer.removeFirst()
            }
        }

        /** The most recent buffered notifications, newest first. */
        fun recent(count: Int): List<Map<String, Any?>> = synchronized(buffer) {
            buffer.reversed().take(count.coerceIn(1, CAP))
        }
    }
}
