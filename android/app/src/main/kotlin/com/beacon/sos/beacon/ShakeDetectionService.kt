package com.beacon.sos.beacon

import android.app.Service
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlin.math.abs

class ShakeDetectionService : Service(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private var sensitivity = 3
    private var requiredShakes = 6
    private var shakeCount = 0
    private var lastShakeTime = 0L
    private var isProcessing = false
    private var lastDirection: Int? = null
    private var lastAxis: Int? = null
    private val SHAKE_WINDOW_MS = 3500L
    private val MIN_SHAKE_INTERVAL_MS = 300L
    private val NOTIFICATION_ID = 1001
    private val gravity = FloatArray(3)
    private val alpha = 0.9f // Low-pass filter factor for gravity removal

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START_SHAKE_DETECTION" -> {
                sensitivity = intent.getIntExtra("sensitivity", 3)
                val providedShakes = intent.getIntExtra("requiredShakes", 6)
                requiredShakes = if (providedShakes < 3) 3 else providedShakes
                startShakeDetection()
            }
            "STOP_SHAKE_DETECTION" -> {
                stopShakeDetection()
            }
        }
        return START_STICKY
    }

    private fun startShakeDetection() {
        // Start foreground immediately to satisfy Android's 5s requirement
        showNotification("Shake Detection Active")

        if (accelerometer != null) {
            sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_NORMAL)
        } else {
            showNotification("Accelerometer unavailable")
            stopSelf()
        }
    }

    private fun stopShakeDetection() {
        sensorManager.unregisterListener(this)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || isProcessing) return

        val rawX = event.values[0]
        val rawY = event.values[1]
        val rawZ = event.values[2]

        // Remove gravity using a simple low-pass filter to reduce false positives
        gravity[0] = alpha * gravity[0] + (1 - alpha) * rawX
        gravity[1] = alpha * gravity[1] + (1 - alpha) * rawY
        gravity[2] = alpha * gravity[2] + (1 - alpha) * rawZ

        val linX = rawX - gravity[0]
        val linY = rawY - gravity[1]
        val linZ = rawZ - gravity[2]

        val axisValues = floatArrayOf(linX, linY, linZ)
        val dominant = axisValues.withIndex().maxByOrNull { abs(it.value) } ?: return
        val axisMagnitude = abs(dominant.value)
        val axisDirection = if (dominant.value >= 0) 1 else -1

        // Higher thresholds after gravity removal to require harder shakes
        val threshold = when (sensitivity) {
            1 -> 14f // Low: still responsive
            2 -> 18f // Medium
            else -> 22f // High: hardest to trigger
        }

        if (axisMagnitude <= threshold) return

        val currentTime = System.currentTimeMillis()
        val timeSinceLast = currentTime - lastShakeTime

        // Reset window if too much time passed since last shake
        if (timeSinceLast > SHAKE_WINDOW_MS) {
            shakeCount = 0
            lastDirection = null
            lastAxis = null
        }

        // Ignore events that arrive too fast to be separate shakes
        if (timeSinceLast in 1 until MIN_SHAKE_INTERVAL_MS) {
            return
        }

        // Require direction flip (up/down) to count as a shake
        if (lastDirection != null && axisDirection == lastDirection) {
            return
        }

        shakeCount++
        lastShakeTime = currentTime
        lastDirection = axisDirection
        lastAxis = dominant.index

        if (shakeCount >= requiredShakes && !isProcessing) {
            isProcessing = true
            triggerShakeDetected()
            shakeCount = 0
            isProcessing = false
        }
    }

    private fun triggerShakeDetected() {
        val intent = Intent("com.beacon.SHAKE_DETECTED")
        sendBroadcast(intent)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "beacon_shake",
                "Shake Detection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Beacon SOS shake detection service"
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun showNotification(message: String) {
        val notification = NotificationCompat.Builder(this, "beacon_shake")
            .setContentTitle("Beacon SOS")
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        startForeground(NOTIFICATION_ID, notification)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        sensorManager.unregisterListener(this)
    }
}
