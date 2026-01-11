package com.beacon.sos.beacon.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        // Stub receiver required for SMS role; no-op to avoid crashes.
        Log.d("BeaconSms", "SMS_DELIVER received")
    }
}
