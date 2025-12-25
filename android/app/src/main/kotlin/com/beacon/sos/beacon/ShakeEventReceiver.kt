package com.beacon.sos.beacon

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ShakeEventReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == "com.beacon.SHAKE_DETECTED") {
            // Flutter will be notified via MethodChannel
            // This receiver just passes the event through
        }
    }
}
