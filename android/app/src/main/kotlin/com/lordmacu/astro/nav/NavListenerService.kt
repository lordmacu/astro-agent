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
        if (sbn.packageName != MAPS_PKG) return
        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        Log.d(TAG, "maps posted: title='$title' text='$text'")
        sink?.invoke(mapOf("title" to title, "text" to text, "removed" to false))
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        if (sbn.packageName != MAPS_PKG) return
        sink?.invoke(mapOf("title" to null, "text" to null, "removed" to true))
    }

    companion object {
        private const val TAG = "AstroNav"
        private const val MAPS_PKG = "com.google.android.apps.maps"

        /** Set by NavChannel while a Dart listener is active. */
        @Volatile
        var sink: ((Map<String, Any?>) -> Unit)? = null
    }
}
