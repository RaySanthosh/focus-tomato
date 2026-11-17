package com.santosh.focus_tomato

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bridge for the few phone features Flutter can't reach on its own:
 * Do Not Disturb, and a "session finished" alarm that fires even when the app is closed.
 * Nothing here touches the network or stores personal data.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focus_tomato/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasDndAccess" -> result.success(Dnd.hasAccess(this))
                    "openDndSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "setDnd" -> result.success(
                        if (call.argument<Boolean>("on") == true) Dnd.turnOn(this) else Dnd.restore(this)
                    )
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
                        }
                        result.success(null)
                    }
                    "scheduleEnd" -> {
                        SessionEndReceiver.schedule(
                            this,
                            call.argument<Number>("atMillis")!!.toLong(),
                            call.argument<String>("title") ?: "",
                            call.argument<String>("body") ?: "",
                        )
                        result.success(null)
                    }
                    "cancelEnd" -> {
                        SessionEndReceiver.cancel(this)
                        result.success(null)
                    }
                    "completeNow" -> {
                        SessionEndReceiver.cancel(this)
                        SessionEndReceiver.complete(
                            this,
                            call.argument<String>("title") ?: "",
                            call.argument<String>("body") ?: "",
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

/** Turns DND on for a focus session and only turns it off again if we were the ones who turned it on. */
object Dnd {
    private const val PREFS = "focus_tomato_native"
    private const val KEY_BY_US = "dnd_by_us"

    private fun nm(c: Context) = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun hasAccess(c: Context) = nm(c).isNotificationPolicyAccessGranted

    fun turnOn(c: Context): Boolean {
        val n = nm(c)
        if (!n.isNotificationPolicyAccessGranted) return false
        if (n.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL) {
            n.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_BY_US, true).apply()
        }
        return true
    }

    fun restore(c: Context): Boolean {
        val prefs = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val n = nm(c)
        if (prefs.getBoolean(KEY_BY_US, false) && n.isNotificationPolicyAccessGranted) {
            n.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
        }
        prefs.edit().putBoolean(KEY_BY_US, false).apply()
        return true
    }
}
