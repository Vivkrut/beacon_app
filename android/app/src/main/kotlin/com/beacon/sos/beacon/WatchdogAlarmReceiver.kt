package com.beacon.sos.beacon

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class WatchdogAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        // Disabled for now - watchdog functionality on hold
        // This receiver is triggered by BOOT_COMPLETED but disabled in AndroidManifest
        return
    }
}
