package ai.astro

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import ai.astro.apps.AppLauncherChannel
import ai.astro.calendar.CalendarChannel
import ai.astro.media.MediaChannel
import ai.astro.nav.NavChannel
import ai.astro.notifications.NotificationsChannel
import ai.astro.proximity.ProximityChannel
import ai.astro.wakeword.WakeWordChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var wakeWordChannel: WakeWordChannel
    private lateinit var mediaChannel: MediaChannel
    private lateinit var proximityChannel: ProximityChannel
    private lateinit var navChannel: NavChannel
    private lateinit var calendarChannel: CalendarChannel
    private lateinit var appLauncherChannel: AppLauncherChannel
    private lateinit var notificationsChannel: NotificationsChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        wakeWordChannel = WakeWordChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        mediaChannel = MediaChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        proximityChannel = ProximityChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        navChannel = NavChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        calendarChannel = CalendarChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        appLauncherChannel = AppLauncherChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        notificationsChannel = NotificationsChannel(
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) requestWakeWordPermissions()
    }

    private fun requestWakeWordPermissions() {
        val needed = mutableListOf<String>()
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            needed.add(Manifest.permission.RECORD_AUDIO)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            needed.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        if (needed.isNotEmpty()) requestPermissions(needed.toTypedArray(), REQ_WAKE_PERMS)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_WAKE_PERMS && this::wakeWordChannel.isInitialized) {
            wakeWordChannel.startIfPermitted()
        }
    }

    companion object {
        private const val REQ_WAKE_PERMS = 4201
    }
}
