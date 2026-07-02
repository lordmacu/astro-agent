package ai.astro.apps

import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** Launches an installed app by (fuzzy) name, for the device tool's `open_app`
 *  action. Queries the launcher activities, matches the spoken name against
 *  their labels, and starts the best match. Needs the MAIN/LAUNCHER `<queries>`
 *  entry in the manifest to see other apps on Android 11+. */
class AppLauncherChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    @Suppress("unused")
    private val channel = MethodChannel(messenger, CHANNEL).also {
        it.setMethodCallHandler { call, result ->
            when (call.method) {
                "openApp" -> result.success(openApp(call.argument<String>("name") ?: ""))
                else -> result.notImplemented()
            }
        }
    }

    private fun openApp(name: String): Boolean {
        val query = name.trim().lowercase(Locale.getDefault())
        if (query.isEmpty()) return false

        val pm = context.packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_LAUNCHER)

        var bestPackage: String? = null
        var bestScore = 0
        for (info in pm.queryIntentActivities(launcherIntent, 0)) {
            val label = info.loadLabel(pm).toString().lowercase(Locale.getDefault())
            val score = when {
                label == query -> 4
                label.startsWith(query) -> 3
                label.contains(query) -> 2
                query.contains(label) && label.length >= 3 -> 1
                else -> 0
            }
            if (score > bestScore) {
                bestScore = score
                bestPackage = info.activityInfo.packageName
            }
        }

        val pkg = bestPackage
        if (pkg == null) {
            Log.d(TAG, "no app match for '$name'")
            return false
        }
        val launch = pm.getLaunchIntentForPackage(pkg)?.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK,
        ) ?: return false
        return try {
            context.startActivity(launch)
            Log.d(TAG, "opened '$pkg' for '$name'")
            true
        } catch (e: Exception) {
            Log.w(TAG, "failed to open '$pkg': $e")
            false
        }
    }

    companion object {
        private const val CHANNEL = "astro/apps"
        private const val TAG = "AstroApps"
    }
}
