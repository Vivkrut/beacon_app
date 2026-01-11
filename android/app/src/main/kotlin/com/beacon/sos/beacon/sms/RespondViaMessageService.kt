package com.beacon.sos.beacon.sms

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log

class RespondViaMessageService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Required placeholder service for default SMS role; no processing needed.
        Log.d("BeaconSms", "RespondViaMessageService invoked")
        stopSelf(startId)
        return START_NOT_STICKY
    }
}
