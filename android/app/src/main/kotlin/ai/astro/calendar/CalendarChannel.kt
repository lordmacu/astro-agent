package ai.astro.calendar

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.provider.CalendarContract
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

/** Creates calendar events silently through the Calendar provider, for the
 *  `calendar` tool. Picks the primary writable calendar, inserts the event and
 *  an optional reminder. Requires READ/WRITE_CALENDAR (requested from Dart).
 *  Returns true on success, false on any failure so the tool can report it. */
class CalendarChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    @Suppress("unused")
    private val channel = MethodChannel(messenger, CHANNEL).also {
        it.setMethodCallHandler { call, result ->
            when (call.method) {
                "listCalendars" -> result.success(listCalendars())
                "createEvent" -> result.success(
                    createEvent(
                        calendarId = call.argument<Number>("calendarId")?.toLong() ?: -1L,
                        title = call.argument<String>("title") ?: "",
                        startMillis = call.argument<Number>("startMillis")?.toLong() ?: 0L,
                        durationMinutes = call.argument<Int>("durationMinutes") ?: 60,
                        reminderMinutes = call.argument<Int>("reminderMinutes") ?: 10,
                    ),
                )
                else -> result.notImplemented()
            }
        }
    }

    /** All writable calendars as `{id, name, account}`, for the picker. */
    private fun listCalendars(): List<Map<String, Any>> {
        val out = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
        )
        context.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI, projection, null, null, null,
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(CalendarContract.Calendars._ID)
            val nameCol =
                cursor.getColumnIndexOrThrow(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME)
            val acctCol = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.ACCOUNT_NAME)
            val accessCol =
                cursor.getColumnIndexOrThrow(CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL)
            while (cursor.moveToNext()) {
                if (cursor.getInt(accessCol) < CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR) {
                    continue
                }
                out.add(
                    mapOf(
                        "id" to cursor.getLong(idCol),
                        "name" to (cursor.getString(nameCol) ?: "Calendar"),
                        "account" to (cursor.getString(acctCol) ?: ""),
                    ),
                )
            }
        }
        return out
    }

    private fun createEvent(
        calendarId: Long,
        title: String,
        startMillis: Long,
        durationMinutes: Int,
        reminderMinutes: Int,
    ): Boolean {
        if (title.isBlank() || startMillis <= 0L) return false
        val targetId = if (calendarId > 0L) calendarId else primaryCalendarId()
        if (targetId == null) {
            Log.w(TAG, "no writable calendar found")
            return false
        }
        return try {
            val endMillis = startMillis + durationMinutes.coerceAtLeast(1) * 60_000L
            val values = ContentValues().apply {
                put(CalendarContract.Events.CALENDAR_ID, targetId)
                put(CalendarContract.Events.TITLE, title)
                put(CalendarContract.Events.DTSTART, startMillis)
                put(CalendarContract.Events.DTEND, endMillis)
                put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
            }
            val uri = context.contentResolver
                .insert(CalendarContract.Events.CONTENT_URI, values) ?: return false
            val eventId = ContentUris.parseId(uri)
            if (reminderMinutes > 0) {
                context.contentResolver.insert(
                    CalendarContract.Reminders.CONTENT_URI,
                    ContentValues().apply {
                        put(CalendarContract.Reminders.EVENT_ID, eventId)
                        put(CalendarContract.Reminders.MINUTES, reminderMinutes)
                        put(
                            CalendarContract.Reminders.METHOD,
                            CalendarContract.Reminders.METHOD_ALERT,
                        )
                    },
                )
            }
            Log.d(TAG, "created event '$title' in calendar $targetId")
            true
        } catch (e: SecurityException) {
            Log.w(TAG, "createEvent denied: $e")
            false
        } catch (e: Exception) {
            Log.w(TAG, "createEvent failed: $e")
            false
        }
    }

    /** The best calendar to write to: prefer a primary, writable one; else any
     *  writable one. Needs READ_CALENDAR to query. */
    private fun primaryCalendarId(): Long? {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.IS_PRIMARY,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
        )
        context.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI, projection, null, null, null,
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(CalendarContract.Calendars._ID)
            val primCol = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.IS_PRIMARY)
            val accessCol =
                cursor.getColumnIndexOrThrow(CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL)
            var fallback: Long? = null
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idCol)
                val writable =
                    cursor.getInt(accessCol) >= CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR
                if (!writable) continue
                if (cursor.getInt(primCol) == 1) return id
                if (fallback == null) fallback = id
            }
            return fallback
        }
        return null
    }

    companion object {
        private const val CHANNEL = "astro/calendar"
        private const val TAG = "AstroCalendar"
    }
}
