package com.beacon.sos.beacon

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.IntentFilter
import android.content.Context
import android.content.BroadcastReceiver
import android.os.Build

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.beacon/shake_service"
    private val SHAKE_EVENTS_CHANNEL = "com.beacon/shake_events"
    private var shakeReceiver: BroadcastReceiver? = null
    private lateinit var shakeEventsChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startShakeDetection" -> {
                        val sensitivity = call.argument<Int>("sensitivity") ?: 3
                        val requiredShakes = call.argument<Int>("requiredShakes") ?: 6
                        startShakeDetection(sensitivity, requiredShakes)
                        result.success(null)
                    }
                    "stopShakeDetection" -> {
                        stopShakeDetection()
                        result.success(null)
                    }
                    "setShakeSensitivity" -> {
                        val sensitivity = call.argument<Int>("sensitivity") ?: 3
                        setShakeSensitivity(sensitivity)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Register ShakeEventReceiver
        shakeEventsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHAKE_EVENTS_CHANNEL)
        registerShakeReceiver()
    }

    private fun startShakeDetection(sensitivity: Int, requiredShakes: Int) {
        val intent = Intent(this, ShakeDetectionService::class.java).apply {
            action = "START_SHAKE_DETECTION"
            putExtra("sensitivity", sensitivity)
            putExtra("requiredShakes", requiredShakes)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopShakeDetection() {
        val intent = Intent(this, ShakeDetectionService::class.java)
        stopService(intent)
    }

    private fun setShakeSensitivity(sensitivity: Int) {
        val intent = Intent("com.beacon.SET_SENSITIVITY").apply {
            putExtra("sensitivity", sensitivity)
        }
        sendBroadcast(intent)
    }

    private fun registerShakeReceiver() {
        if (shakeReceiver == null) {
            shakeReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == "com.beacon.SHAKE_DETECTED") {
                        shakeEventsChannel.invokeMethod("shakeDetected", null)
                    }
                }
            }
            val filter = IntentFilter("com.beacon.SHAKE_DETECTED")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(shakeReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(shakeReceiver, filter)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (shakeReceiver != null) {
            unregisterReceiver(shakeReceiver)
            shakeReceiver = null
        }
    }
}

