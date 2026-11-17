package com.santosh.focus_tomato

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Fires when a session's time is up, even if the app was closed:
 * turns Do Not Disturb back off (if we turned it on), then shows a notification.
 * Uses an inexact alarm, so no exact-alarm permission is needed (Play restricts that one).
 */
class SessionEndReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        complete(context, intent.getStringExtra(EXTRA_TITLE) ?: "", intent.getStringExtra(EXTRA_BODY) ?: "")
    }

    companion object {
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_BODY = "body"
        private const val CHANNEL_ID = "session_end"
        private const val NOTIFICATION_ID = 1

        private fun pending(c: Context, title: String = "", body: String = ""): PendingIntent {
            val i = Intent(c, SessionEndReceiver::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_BODY, body)
            return PendingIntent.getBroadcast(
                c, 0, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        fun schedule(c: Context, atMillis: Long, title: String, body: String) {
            val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pending(c, title, body))
        }

        fun cancel(c: Context) {
            val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(pending(c))
        }

        fun complete(c: Context, title: String, body: String) {
            Dnd.restore(c)
            val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 33 && !nm.areNotificationsEnabled()) return

            val open = PendingIntent.getActivity(
                c, 0,
                Intent(c, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE,
            )
            val builder = if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, "Session finished", NotificationManager.IMPORTANCE_HIGH)
                )
                Notification.Builder(c, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(c).setDefaults(Notification.DEFAULT_ALL)
            }
            val n = builder
                .setSmallIcon(R.drawable.ic_stat_tomato)
                .setContentTitle(title)
                .setContentText(body)
                .setContentIntent(open)
                .setAutoCancel(true)
                .build()
            nm.notify(NOTIFICATION_ID, n)
        }
    }
}
