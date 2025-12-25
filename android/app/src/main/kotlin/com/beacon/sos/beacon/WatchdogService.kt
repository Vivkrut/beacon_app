package com.beacon.sos.beacon

import android.app.Service
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Intent
import android.os.IBinder
import android.os.SystemClock

class WatchdogService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        scheduleWatchdogCheck()
        return START_STICKY
    }

    private fun scheduleWatchdogCheck() {
        val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, WatchdogAlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Check every 5 minutes
        val interval = 5 * 60 * 1000L
        val triggerAtMs = SystemClock.elapsedRealtime() + interval

        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerAtMs,
                pendingIntent
            )
        } catch (e: Exception) {
            // Fallback to setAndAllowWhileIdle
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerAtMs,
                pendingIntent
            )
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
