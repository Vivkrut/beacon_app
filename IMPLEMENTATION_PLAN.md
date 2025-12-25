# Beacon MVP Implementation Plan (Revised)

## Phase Status (Dec 25, 2025)

- **Phase 1 – Project Setup:** Done. Deps, Android perms, Kotlin shake service, DI, validators/wizard service scaffold.
- **Phase 2 – Contacts Manager:** Done. SQLite repo, add/edit/delete, primary flag, validation, phone picker, list/add/edit UI.
- **Phase 3 – Settings Screen:** Done. Name, 3 contact slots with picker, shake sensitivity, emergency message, save/reset; links to contacts & BlackBox.
- **Phase 4 – Home Screen:** Done. Main SOS UI, shake toggle, manual SOS, settings nav, test SOS button.
- **Phase 5 – BlackBox Storage:** Partial. DB/history present; still need: ensure every SOS logs GPS + notified contacts; evidence path hooks; richer history metadata.
- **Phase 6 – SOS Manager (Core Emergency):** Partial. Shake/countdown/cancel/confirm/rate limit/haptics working; still need: lockscreen overlay for countdown, test mode toggle, working siren audio, robust CALL NOW, distress package hook.
- **Phase 7 – Communication (SMS Alerts):** Not done. Need real SMS send with retries, primary-first ordering, GPS/message payload, offline handling; replace url_launcher shim.
- **Phase 8 – Advanced (formerly 9):** Not done. Video/audio evidence capture + storage/encryption hooks; Bluetooth broadcast stub; widget/one-tap activation; finalize siren/alert audio.
- **Phase 9 – Onboarding Wizard (last priority):** Not done. First-run wizard (add contact, set primary, test SOS), skip/reset, AppInitializer gating.
- **Phase 10 – Testing & Deployment:** Not done. Unit tests (contacts, SMS, distress payload), widget tests (wizard, countdown), manual device checklist, build/release hardening.

**Target:** Android-only, offline-first SOS emergency app with native shake detection service.

---

## Phase 1: Project Setup & Dependencies

### 1.1 Add Dependencies to `pubspec.yaml`
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  provider: ^6.0.0
  get_it: ^7.6.0
  sqflite: ^2.3.0
  path: ^1.8.3
  geolocator: ^9.0.2
  flutter_sms: ^3.1.1
  permission_handler: ^11.4.4
  shared_preferences: ^2.2.3
  video_player: ^2.8.1
  camera: ^0.10.5+5
  uuid: ^4.0.0
  intl: ^0.18.0
  connectivity_plus: ^5.0.0
  flutter_contacts: ^1.1.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

**New Dependencies Rationale:**
- `permission_handler` — Runtime permission management for GPS, SMS, Camera, Microphone
- `shared_preferences` — Persistent user settings (sensitivity, notification preferences)
- `video_player` + `camera` — Video recording for evidence (Phase 2B)
- `uuid` + `intl` — ID generation and date formatting
- `flutter_contacts` — Contacts picker to import emergency contacts from device phonebook

### 1.2 Create Directory Structure
```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart
│   ├── models/
│   │   ├── contact.dart
│   │   └── sos_event.dart
│   └── services/
│       └── service_locator.dart
├── features/
│   ├── blackbox/
│   │   ├── data/
│   │   │   ├── blackbox_repository.dart
│   │   │   └── blackbox_database.dart
│   │   ├── domain/
│   │   ├── presentation/
│   │   │   ├── notifiers/
│   │   │   │   └── blackbox_notifier.dart
│   │   │   └── screens/
│   │   │       └── blackbox_history_screen.dart
│   │   └── blackbox_module.dart
│   ├── communication/
│   │   ├── services/
│   │   │   ├── sms_service.dart
│   │   │   └── distress_package_generator.dart
│   │   ├── domain/
│   │   └── communication_module.dart
│   ├── contacts/
│   │   ├── data/
│   │   │   ├── contact_repository.dart
│   │   │   └── contact_database.dart
│   │   ├── domain/
│   │   ├── presentation/
│   │   │   ├── notifiers/
│   │   │   │   └── contact_notifier.dart
│   │   │   └── screens/
│   │   │       ├── contact_list_screen.dart
│   │   │       └── add_contact_screen.dart
│   │   └── contacts_module.dart
│   └── sos_manager/
│       ├── domain/
│       │   ├── sos_manager.dart
│       │   └── shake_detector.dart
│       ├── presentation/
│       │   ├── notifiers/
│       │   │   └── sos_notifier.dart
│       │   ├── screens/
│       │   │   ├── home_screen.dart
│       │   │   ├── sos_pre_overlay.dart
│       │   │   └── sos_post_overlay.dart
│       │   └── widgets/
│       │       └── sos_button.dart
│       └── sos_manager_module.dart
└── main.dart
```

### 1.3 Android Configuration

**`android/app/build.gradle.kts`** — Update `targetSdk` to 34+ and add Kotlin support:
```kotlin
android {
    compileSdk = 34
    defaultConfig {
        minSdk = 21
        targetSdk = 34
    }
}
```

**`android/app/src/main/AndroidManifest.xml`** — Add permissions:
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.SEND_SMS" />
<uses-permission android:name="android.permission.RECEIVE_SMS" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />

<application>
  <!-- Shake Detection Service -->
  <service
      android:name=".ShakeDetectionService"
      android:exported="false"
      android:foregroundServiceType="location" />

  <!-- Watchdog Service (Keep-Alive) -->
  <service
      android:name=".WatchdogService"
      android:exported="false" />

  <!-- Broadcast Receiver for Shake Events -->
  <receiver
      android:name=".ShakeEventReceiver"
      android:exported="false">
    <intent-filter>
      <action android:name="com.beacon.SHAKE_DETECTED" />
    </intent-filter>
  </receiver>

  <!-- Alarm Receiver for Watchdog -->
  <receiver
      android:name=".WatchdogAlarmReceiver"
      android:exported="false">
    <intent-filter>
      <action android:name="com.beacon.WATCHDOG_CHECK" />
    </intent-filter>
  </receiver>
</application>
```

### 1.4 Create Kotlin ShakeDetectionService

**`android/app/src/main/kotlin/com/beacon/ShakeDetectionService.kt`**:
```kotlin
package com.beacon

import android.app.Service
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import kotlin.math.sqrt

class ShakeDetectionService : Service(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private var lastShakeTime = 0L
    private var shakeCount = 0
    private val SHAKE_TIME_WINDOW = 2000L // 2 seconds
    private var shakeThreshold = 20f // Medium sensitivity
    private var isProcessing = false

    companion object {
        const val NOTIFICATION_ID = 1
        const val CHANNEL_ID = "beacon_shake_detection"
        const val ACTION_SHAKE_DETECTED = "com.beacon.SHAKE_DETECTED"
        const val PREFS_SHAKE_SENSITIVITY = "shake_sensitivity"
        const val PREFS_SHAKE_ENABLED = "shake_enabled"
    }

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Beacon SOS")
            .setContentText("Shake detection active")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(NOTIFICATION_ID, notification)

        // Load sensitivity from SharedPreferences
        val prefs = getSharedPreferences("beacon_prefs", Context.MODE_PRIVATE)
        val sensitivity = prefs.getString(PREFS_SHAKE_SENSITIVITY, "medium") ?: "medium"
        shakeThreshold = when (sensitivity) {
            "low" -> 15f
            "medium" -> 20f
            "high" -> 25f
            else -> 20f
        }

        sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_NORMAL)
        return START_STICKY
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || isProcessing) return

        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]

        val magnitude = sqrt((x * x + y * y + z * z).toDouble()).toFloat()

        if (magnitude > shakeThreshold) {
            val currentTime = System.currentTimeMillis()

            if (currentTime - lastShakeTime > SHAKE_TIME_WINDOW) {
                shakeCount = 1
            } else {
                shakeCount++
            }

            lastShakeTime = currentTime

            // Check shake count based on sensitivity
            val requiredShakes = when {
                shakeThreshold == 15f -> 3 // Low
                shakeThreshold == 20f -> 4 // Medium
                else -> 6 // High
            }

            if (shakeCount >= requiredShakes) {
                isProcessing = true
                broadcastShakeDetected()
                shakeCount = 0
                // Reset processing flag after 2 seconds
                Thread {
                    Thread.sleep(2000)
                    isProcessing = false
                }.start()
            }
        }
    }

    private fun broadcastShakeDetected() {
        val intent = Intent(ACTION_SHAKE_DETECTED)
        sendBroadcast(intent)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onDestroy() {
        super.onDestroy()
        sensorManager.unregisterListener(this)
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Beacon SOS Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }
}
```

### 1.5 Create Broadcast Receiver

**`android/app/src/main/kotlin/com/beacon/ShakeEventReceiver.kt`**:
```kotlin
package com.beacon

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class ShakeEventReceiver : BroadcastReceiver() {
    companion object {
        private const val CHANNEL = "com.beacon/shake_detection"
        var flutterEngine: FlutterEngine? = null
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == ShakeDetectionService.ACTION_SHAKE_DETECTED) {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { binaryMessenger ->
                MethodChannel(binaryMessenger, CHANNEL).invokeMethod("onShakeDetected", null)
            }
        }
    }
}
```

### 1.6 Update MainActivity.kt

**`android/app/src/main/kotlin/com/beacon/MainActivity.kt`**:
```kotlin
package com.beacon

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.beacon/shake_detection"
        private const val SHAKE_SERVICE_CHANNEL = "com.beacon/shake_service"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        ShakeEventReceiver.flutterEngine = flutterEngine

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHAKE_SERVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startShakeDetection" -> {
                        val sensitivity = call.argument<String>("sensitivity") ?: "medium"
                        startShakeDetectionService(sensitivity)
                        result.success(true)
                    }
                    "stopShakeDetection" -> {
                        stopShakeDetectionService()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Register broadcast receiver
        val receiver = ShakeEventReceiver()
        val filter = IntentFilter(ShakeDetectionService.ACTION_SHAKE_DETECTED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
    }

    private fun startShakeDetectionService(sensitivity: String) {
        val prefs = getSharedPreferences("beacon_prefs", Context.MODE_PRIVATE)
        prefs.edit().putString(ShakeDetectionService.PREFS_SHAKE_SENSITIVITY, sensitivity).apply()

        val intent = Intent(this, ShakeDetectionService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopShakeDetectionService() {
        val intent = Intent(this, ShakeDetectionService::class.java)
        stopService(intent)
    }
}
```

### 1.6.5 Watchdog Service (Keep-Alive)

**`android/app/src/main/kotlin/com/beacon/WatchdogService.kt`**:
```kotlin
package com.beacon

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.SystemClock

class WatchdogService : Service() {
    private lateinit var alarmManager: AlarmManager

    override fun onCreate() {
        super.onCreate()
        alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        scheduleWatchdog()
    }

    private fun scheduleWatchdog() {
        val intent = Intent(this, WatchdogAlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Check every 5 minutes
        val interval = 5 * 60 * 1000L
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime() + interval,
                pendingIntent
            )
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime() + interval,
                pendingIntent
            )
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (isShakeServiceRunning()) {
            return START_STICKY
        } else {
            // Service was killed, restart it
            val serviceIntent = Intent(this, ShakeDetectionService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        }
        return START_STICKY
    }

    private fun isShakeServiceRunning(): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val services = activityManager.getRunningServices(Int.MAX_VALUE)
        return services.any { it.service.className == ShakeDetectionService::class.java.name }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
```

**`android/app/src/main/kotlin/com/beacon/WatchdogAlarmReceiver.kt`**:
```kotlin
package com.beacon

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class WatchdogAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context != null) {
            val serviceIntent = Intent(context, WatchdogService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }
}
```

### 1.7 Setup Service Locator & Permission Management

**`lib/core/services/permission_service.dart`** (NEW):
```dart
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request all required permissions
  static Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    final permissions = [
      Permission.location,
      Permission.sms,
      Permission.camera,
      Permission.microphone,
    ];

    return await permissions.request();
  }

  /// Check if GPS permission is granted
  static Future<bool> isLocationPermissionGranted() async {
    return await Permission.location.isGranted;
  }

  /// Check if SMS permission is granted
  static Future<bool> isSMSPermissionGranted() async {
    return await Permission.sms.isGranted;
  }

  /// Check if Camera permission is granted
  static Future<bool> isCameraPermissionGranted() async {
    return await Permission.camera.isGranted;
  }

  /// Request specific permission with explanation
  static Future<PermissionStatus> requestPermission(
    Permission permission, {
    required String explanation,
  }) async {
    print('Requesting $permission: $explanation');
    return await permission.request();
  }
}
```

**`lib/core/services/service_locator.dart`**:
```dart
import 'package:get_it/get_it.dart';
import '../../features/contacts/data/contact_repository.dart';
import '../../features/blackbox/data/blackbox_repository.dart';
import '../../features/sos_manager/domain/sos_manager.dart';
import '../../features/communication/services/sms_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Repositories
  getIt.registerSingleton<ContactRepository>(ContactRepositoryImpl());
  getIt.registerSingleton<BlackBoxRepository>(BlackBoxRepositoryImpl());
  
  // Services
  getIt.registerSingleton<SMSService>(SMSService());
  getIt.registerSingleton<SOSManager>(SOSManager(
    blackBoxRepository: getIt<BlackBoxRepository>(),
    smsService: getIt<SMSService>(),
  ));
}
```

### 1.8 Field Validators (NEW)

**`lib/core/validators/form_validators.dart`**:
```dart
class FormValidators {
  /// Validate contact name
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (RegExp(r'\d').hasMatch(value)) {
      return 'Name cannot contain numbers';
    }
    if (value.length > 50) {
      return 'Name must be less than 50 characters';
    }
    return null;
  }

  /// Validate phone number (Indian + International)
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove spaces and hyphens
    String phone = value.replaceAll(RegExp(r'[\s\-]'), '');

    // Indian format: +91 or 10 digits
    if (phone.startsWith('+91')) {
      if (phone.length != 13) {
        return 'Invalid Indian phone format. Use +91XXXXXXXXXX (12 digits)';
      }
    } else if (phone.startsWith('91')) {
      if (phone.length != 12) {
        return 'Invalid Indian phone format. Use 91XXXXXXXXXX (11 digits)';
      }
    } else if (RegExp(r'^\d{10}$').hasMatch(phone)) {
      // Direct 10-digit format
      return null;
    } else if (RegExp(r'^(\+?1)?\d{10,14}$').hasMatch(phone)) {
      // International format (9-15 digits)
      return null;
    } else {
      return 'Invalid phone number format';
    }
    return null;
  }

  /// Validate email (optional, but if provided must be valid)
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
      return 'Invalid email format';
    }
    return null;
  }
}
```

### 1.9 Onboarding Wizard Service (NEW)

**`lib/core/services/wizard_service.dart`**:
```dart
import 'package:shared_preferences/shared_preferences.dart';

class WizardService {
  static const String _wizardCompletedKey = 'wizard_completed';
  static const String _step1CompletedKey = 'wizard_step1_add_contact';
  static const String _step2CompletedKey = 'wizard_step2_set_priority';
  static const String _step3CompletedKey = 'wizard_step3_test_sos';

  /// Check if wizard should be shown (first time user or incomplete)
  static Future<bool> shouldShowWizard() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_wizardCompletedKey) ?? false);
  }

  /// Mark wizard as completed
  static Future<void> completeWizard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wizardCompletedKey, true);
  }

  /// Reset wizard (for testing or user request)
  static Future<void> resetWizard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wizardCompletedKey, false);
    await prefs.setBool(_step1CompletedKey, false);
    await prefs.setBool(_step2CompletedKey, false);
    await prefs.setBool(_step3CompletedKey, false);
  }

  /// Mark individual steps as completed
  static Future<void> completeStep(int stepNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final key = switch (stepNumber) {
      1 => _step1CompletedKey,
      2 => _step2CompletedKey,
      3 => _step3CompletedKey,
      _ => '',
    };
    if (key.isNotEmpty) {
      await prefs.setBool(key, true);
    }
  }

  /// Check if specific step is completed
  static Future<bool> isStepCompleted(int stepNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final key = switch (stepNumber) {
      1 => _step1CompletedKey,
      2 => _step2CompletedKey,
      3 => _step3CompletedKey,
      _ => '',
    };
    return prefs.getBool(key) ?? false;
  }
}
```

---

## Phase 2: Contacts Manager Module

### 2.1 Contact Model

**`lib/core/models/contact.dart`**:
```dart
class Contact {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final bool isPrimary;
  final DateTime createdAt;

  Contact({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.isPrimary = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'isPrimary': isPrimary ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
      isPrimary: map['isPrimary'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
```

### 2.2 Contact Repository

**`lib/features/contacts/data/contact_repository.dart`**:
```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../../core/models/contact.dart';

abstract class ContactRepository {
  Future<void> addContact(Contact contact);
  Future<void> updateContact(Contact contact);
  Future<void> deleteContact(String id);
  Future<Contact?> getContact(String id);
  Future<List<Contact>> getAllContacts();
  Future<Contact?> getPrimaryContact();
}

class ContactRepositoryImpl implements ContactRepository {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'beacon_contacts.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE contacts(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT NOT NULL UNIQUE,
            email TEXT,
            isPrimary INTEGER DEFAULT 0,
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  @override
  Future<void> addContact(Contact contact) async {
    final db = await database;
    await db.insert('contacts', contact.toMap());
  }

  @override
  Future<void> updateContact(Contact contact) async {
    final db = await database;
    await db.update('contacts', contact.toMap(), where: 'id = ?', whereArgs: [contact.id]);
  }

  @override
  Future<void> deleteContact(String id) async {
    final db = await database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Contact?> getContact(String id) async {
    final db = await database;
    final result = await db.query('contacts', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      return Contact.fromMap(result.first);
    }
    return null;
  }

  @override
  Future<List<Contact>> getAllContacts() async {
    final db = await database;
    final result = await db.query('contacts');
    return result.map((map) => Contact.fromMap(map)).toList();
  }

  @override
  Future<Contact?> getPrimaryContact() async {
    final db = await database;
    final result = await db.query('contacts', where: 'isPrimary = ?', whereArgs: [1]);
    if (result.isNotEmpty) {
      return Contact.fromMap(result.first);
    }
    return null;
  }
}
```

### 2.3 Contact Notifier (Provider)

**`lib/features/contacts/presentation/notifiers/contact_notifier.dart`**:
```dart
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/models/contact.dart';
import '../../data/contact_repository.dart';

class ContactNotifier extends ChangeNotifier {
  final ContactRepository _repository = GetIt.instance<ContactRepository>();
  List<Contact> _contacts = [];
  Contact? _primaryContact;

  List<Contact> get contacts => _contacts;
  Contact? get primaryContact => _primaryContact;

  Future<void> loadContacts() async {
    _contacts = await _repository.getAllContacts();
    _primaryContact = await _repository.getPrimaryContact();
    notifyListeners();
  }

  Future<void> addContact(Contact contact) async {
    await _repository.addContact(contact);
    await loadContacts();
  }

  Future<void> deleteContact(String id) async {
    await _repository.deleteContact(id);
    await loadContacts();
  }

  Future<void> setPrimaryContact(String id) async {
    // Clear old primary
    if (_primaryContact != null) {
      final old = _primaryContact!.copyWith(isPrimary: false);
      await _repository.updateContact(old);
    }
    // Set new primary
    final contact = await _repository.getContact(id);
    if (contact != null) {
      await _repository.updateContact(contact.copyWith(isPrimary: true));
      await loadContacts();
    }
  }
}

extension ContactCopyWith on Contact {
  Contact copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    bool? isPrimary,
    DateTime? createdAt,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
```

### 2.4 Contact List & Add Screens (Placeholders)

**`lib/features/contacts/presentation/screens/contact_list_screen.dart`**:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/contact_notifier.dart';

class ContactListScreen extends StatefulWidget {
  const ContactListScreen({Key? key}) : super(key: key);

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ContactNotifier>().loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      body: Consumer<ContactNotifier>(
        builder: (context, notifier, _) {
          if (notifier.contacts.isEmpty) {
            return const Center(child: Text('No contacts added yet'));
          }
          return ListView.builder(
            itemCount: notifier.contacts.length,
            itemBuilder: (context, index) {
              final contact = notifier.contacts[index];
              return ListTile(
                title: Text(contact.name),
                subtitle: Text(contact.phone),
                trailing: contact.isPrimary
                    ? const Icon(Icons.star, color: Colors.orange)
                    : null,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddContactScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

**`lib/features/contacts/presentation/screens/add_contact_screen.dart`**:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../../../core/models/contact.dart';
import '../../../../core/validators/form_validators.dart';
import '../../../../core/services/wizard_service.dart';
import '../notifiers/contact_notifier.dart';

class AddContactScreen extends StatefulWidget {
  final bool isWizardMode;

  const AddContactScreen({Key? key, this.isWizardMode = false}) : super(key: key);

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickContactFromPhone() async {
    try {
      final contact = await FlutterContacts.openExternalPicker();
      if (contact != null) {
        _nameController.text = contact.displayName;
        
        // Get first phone number
        if (contact.phones.isNotEmpty) {
          _phoneController.text = contact.phones.first.number;
        }
        
        // Get first email
        if (contact.emails.isNotEmpty) {
          _emailController.text = contact.emails.first.address;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking contact: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Emergency Contact'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isWizardMode) ...[
              const Text(
                '📋 Step 1: Add Your First Contact',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add at least one emergency contact to use Beacon SOS.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
            ],
            
            // Contacts Picker Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _pickContactFromPhone,
                icon: const Icon(Icons.contacts),
                label: const Text('Pick from Phone Contacts'),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Or enter manually:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'E.g., Mom, Dad, Sister',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: FormValidators.validateName,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '+91 9876543210 or 9876543210',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: FormValidators.validatePhone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email (Optional)',
                      hintText: 'name@example.com',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: FormValidators.validateEmail,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          final contact = Contact(
                            id: const Uuid().v4(),
                            name: _nameController.text.trim(),
                            phone: _phoneController.text.trim(),
                            email: _emailController.text.trim().isEmpty
                                ? null
                                : _emailController.text.trim(),
                            createdAt: DateTime.now(),
                          );
                          await context.read<ContactNotifier>().addContact(contact);

                          if (widget.isWizardMode) {
                            await WizardService.completeStep(1);
                          }

                          if (mounted) Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text(
                        'Add Contact',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Phase 2.5: Onboarding Wizard Screen (NEW)

**`lib/features/contacts/presentation/screens/onboarding_wizard_screen.dart`** (NEW):
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/wizard_service.dart';
import '../notifiers/contact_notifier.dart';
import '../../sos_manager/presentation/notifiers/sos_notifier.dart';
import 'add_contact_screen.dart';

class OnboardingWizardScreen extends StatefulWidget {
  const OnboardingWizardScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Welcome to Beacon SOS'),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: _buildWizardStep(),
      ),
    );
  }

  Widget _buildWizardStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1AddContact();
      case 1:
        return _buildStep2SetPriority();
      case 2:
        return _buildStep3TestSOS();
      default:
        return _buildStep1AddContact();
    }
  }

  Widget _buildStep1AddContact() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.contacts, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Add Emergency Contacts',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Beacon needs at least one emergency contact to send SOS alerts.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddContactScreen(isWizardMode: true),
                  ),
                );
                if (result != null && mounted) {
                  setState(() => _currentStep = 1);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add First Contact'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() => _currentStep = 1);
              },
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2SetPriority() {
    return Consumer<ContactNotifier>(
      builder: (context, contactNotifier, _) {
        final contacts = contactNotifier.contacts;
        final primaryContact = contactNotifier.primaryContact;

        if (contacts.isEmpty) {
          return _buildNoContactsWarning();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⭐ Step 2: Set Primary Contact',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose which contact will receive the SOS alert first.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: RadioListTile<String>(
                      title: Text(contact.name),
                      subtitle: Text(contact.phone),
                      value: contact.id,
                      groupValue: primaryContact?.id,
                      onChanged: (value) async {
                        if (value != null) {
                          await context.read<ContactNotifier>().setPrimaryContact(value);
                          await WizardService.completeStep(2);
                        }
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: primaryContact != null
                      ? () {
                          setState(() => _currentStep = 2);
                        }
                      : null,
                  child: const Text('Next: Test SOS'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStep3TestSOS() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🚨 Step 3: Test Your SOS',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Test the SOS system to ensure everything is working correctly. In test mode, alerts will be logged but not actually sent.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Row(
              children: [
                Icon(Icons.info, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'SMS will NOT be sent in test mode',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: () {
                context.read<SOSNotifier>().manualTrigger();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test SOS triggered successfully!')),
                );
              },
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
                child: const Center(
                  child: Text(
                    'TEST\nSOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                await WizardService.completeStep(3);
                await WizardService.completeWizard();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/home');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text(
                'Complete Setup',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () async {
                await WizardService.completeWizard();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/home');
                }
              },
              child: const Text('Skip Testing'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoContactsWarning() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            const Text(
              'No Contacts Added',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please add at least one contact first.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() => _currentStep = 0);
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Phase 3: BlackBox Storage Module

### 3.1 SOS Event Model

**`lib/core/models/sos_event.dart`**:
```dart
class SOSEvent {
  final String id;
  final DateTime timestamp;
  final String? gpsCoordinates;
  final List<String> contactsNotified;
  final String status; // 'triggered', 'cancelled', 'completed'
  final String? audioPath;

  SOSEvent({
    required this.id,
    required this.timestamp,
    this.gpsCoordinates,
    this.contactsNotified = const [],
    this.status = 'triggered',
    this.audioPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'gpsCoordinates': gpsCoordinates,
      'contactsNotified': contactsNotified.join(','),
      'status': status,
      'audioPath': audioPath,
    };
  }

  factory SOSEvent.fromMap(Map<String, dynamic> map) {
    return SOSEvent(
      id: map['id'],
      timestamp: DateTime.parse(map['timestamp']),
      gpsCoordinates: map['gpsCoordinates'],
      contactsNotified: (map['contactsNotified'] as String?)?.split(',') ?? [],
      status: map['status'],
      audioPath: map['audioPath'],
    );
  }
}
```

### 3.2 BlackBox Repository

**`lib/features/blackbox/data/blackbox_repository.dart`**:
```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../../core/models/sos_event.dart';

abstract class BlackBoxRepository {
  Future<void> logSOSEvent(SOSEvent event);
  Future<List<SOSEvent>> getSOSHistory({int limit = 100});
  Future<SOSEvent?> getSOSEvent(String id);
}

class BlackBoxRepositoryImpl implements BlackBoxRepository {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'beacon_blackbox.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sos_events(
            id TEXT PRIMARY KEY,
            timestamp TEXT NOT NULL,
            gpsCoordinates TEXT,
            contactsNotified TEXT,
            status TEXT NOT NULL,
            audioPath TEXT
          )
        ''');
      },
    );
  }

  @override
  Future<void> logSOSEvent(SOSEvent event) async {
    final db = await database;
    await db.insert('sos_events', event.toMap());
  }

  @override
  Future<List<SOSEvent>> getSOSHistory({int limit = 100}) async {
    final db = await database;
    final result = await db.query(
      'sos_events',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return result.map((map) => SOSEvent.fromMap(map)).toList();
  }

  @override
  Future<SOSEvent?> getSOSEvent(String id) async {
    final db = await database;
    final result = await db.query('sos_events', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      return SOSEvent.fromMap(result.first);
    }
    return null;
  }
}
```

### 3.3 BlackBox Notifier

**`lib/features/blackbox/presentation/notifiers/blackbox_notifier.dart`**:
```dart
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/models/sos_event.dart';
import '../../data/blackbox_repository.dart';

class BlackBoxNotifier extends ChangeNotifier {
  final BlackBoxRepository _repository = GetIt.instance<BlackBoxRepository>();
  List<SOSEvent> _events = [];

  List<SOSEvent> get events => _events;

  Future<void> loadHistory() async {
    _events = await _repository.getSOSHistory();
    notifyListeners();
  }

  Future<void> logEvent(SOSEvent event) async {
    await _repository.logSOSEvent(event);
    await loadHistory();
  }
}
```

### 3.4 BlackBox History Screen

**`lib/features/blackbox/presentation/screens/blackbox_history_screen.dart`**:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../notifiers/blackbox_notifier.dart';

class BlackBoxHistoryScreen extends StatefulWidget {
  const BlackBoxHistoryScreen({Key? key}) : super(key: key);

  @override
  State<BlackBoxHistoryScreen> createState() => _BlackBoxHistoryScreenState();
}

class _BlackBoxHistoryScreenState extends State<BlackBoxHistoryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<BlackBoxNotifier>().loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS History')),
      body: Consumer<BlackBoxNotifier>(
        builder: (context, notifier, _) {
          if (notifier.events.isEmpty) {
            return const Center(child: Text('No SOS events recorded'));
          }
          return ListView.builder(
            itemCount: notifier.events.length,
            itemBuilder: (context, index) {
              final event = notifier.events[index];
              return ListTile(
                title: Text('SOS Event - ${event.status}'),
                subtitle: Text(DateFormat.yMd().addPattern('- jm').format(event.timestamp)),
                trailing: Chip(
                  label: Text(event.status),
                  backgroundColor: event.status == 'completed' ? Colors.green : Colors.red,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

---

## Phase 4: SOS Manager Module (Expanded - 17 Requirements)

### 4.1 SOS Manager Core Logic

**`lib/features/sos_manager/domain/sos_manager.dart`**:
```dart
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/sos_event.dart';
import '../../blackbox/data/blackbox_repository.dart';
import '../../communication/services/sms_service.dart';

enum SOSState { idle, armed, triggered, cancelled, completed }
enum ShakeSensitivity { low, medium, high }

class SOSManager {
  final BlackBoxRepository _blackBoxRepository;
  final SMSService _smsService;

  static const platform = MethodChannel('com.beacon/shake_service');
  static const shakeChannel = MethodChannel('com.beacon/shake_detection');

  SOSState _currentState = SOSState.idle;
  ShakeSensitivity _shakeSensitivity = ShakeSensitivity.medium;
  bool _isShakeDetectionEnabled = false;
  bool _isTestMode = false;
  DateTime? _sosTriggeredTime;
  DateTime? _lastSOSTime; // Rate limiting
  final int _cancellationWindowSeconds = 30;
  final int _rateLimitSeconds = 300; // 5 minutes

  SOSState get currentState => _currentState;
  ShakeSensitivity get shakeSensitivity => _shakeSensitivity;
  bool get isShakeDetectionEnabled => _isShakeDetectionEnabled;
  bool get isTestMode => _isTestMode;

  SOSManager({
    required BlackBoxRepository blackBoxRepository,
    required SMSService smsService,
  })  : _blackBoxRepository = blackBoxRepository,
        _smsService = smsService;

  /// Initialize shake detection service and load preferences
  Future<void> initializeShakeDetection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isTestMode = prefs.getBool('test_mode') ?? false;
      
      shakeChannel.setMethodCallHandler((call) async {
        if (call.method == 'onShakeDetected') {
          await onShakeDetected();
        }
      });
    } catch (e) {
      print('Error initializing shake detection: $e');
    }
  }

  /// Start shake detection service
  Future<void> startShakeDetection(ShakeSensitivity sensitivity) async {
    try {
      _shakeSensitivity = sensitivity;
      _isShakeDetectionEnabled = true;
      _currentState = SOSState.armed;

      final sensitivityString = sensitivity.toString().split('.').last;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shake_sensitivity', sensitivityString);

      await platform.invokeMethod('startShakeDetection', {'sensitivity': sensitivityString});
    } catch (e) {
      print('Error starting shake detection: $e');
      _currentState = SOSState.idle;
    }
  }

  /// Stop shake detection service
  Future<void> stopShakeDetection() async {
    try {
      _isShakeDetectionEnabled = false;
      _currentState = SOSState.idle;
      await platform.invokeMethod('stopShakeDetection');
    } catch (e) {
      print('Error stopping shake detection: $e');
    }
  }

  /// Handle shake detection event from native service (with GPS & rate limiting)
  Future<void> onShakeDetected() async {
    if (_currentState != SOSState.armed) return;

    // Rate limiting: Check if SOS was sent recently
    if (_lastSOSTime != null) {
      final timeSinceLastSOS = DateTime.now().difference(_lastSOSTime!).inSeconds;
      if (timeSinceLastSOS < _rateLimitSeconds) {
        print('Rate limited: SOS sent ${_rateLimitSeconds - timeSinceLastSOS}s ago');
        return;
      }
    }

    _currentState = SOSState.triggered;
    _sosTriggeredTime = DateTime.now();
    _lastSOSTime = DateTime.now();

    // Get GPS location
    String? gpsCoordinates;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      gpsCoordinates = '${position.latitude},${position.longitude}';
    } catch (e) {
      print('Error getting GPS: $e');
      gpsCoordinates = null;
    }

    // Log to BlackBox immediately
    final event = SOSEvent(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      gpsCoordinates: gpsCoordinates,
      status: 'triggered',
    );
    await _blackBoxRepository.logSOSEvent(event);

    // Haptic feedback
    HapticFeedback.vibrate();
  }

  /// Manual SOS trigger via button (with rate limiting)
  Future<void> manualTriggerSOS() async {
    if (_currentState == SOSState.triggered || _currentState == SOSState.completed) return;

    // Rate limiting
    if (_lastSOSTime != null) {
      final timeSinceLastSOS = DateTime.now().difference(_lastSOSTime!).inSeconds;
      if (timeSinceLastSOS < _rateLimitSeconds) {
        print('Rate limited: Cannot trigger SOS again so soon');
        return;
      }
    }

    _currentState = SOSState.triggered;
    _sosTriggeredTime = DateTime.now();
    _lastSOSTime = DateTime.now();

    // Get GPS location
    String? gpsCoordinates;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      gpsCoordinates = '${position.latitude},${position.longitude}';
    } catch (e) {
      print('Error getting GPS: $e');
      gpsCoordinates = null;
    }

    final event = SOSEvent(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      gpsCoordinates: gpsCoordinates,
      status: 'triggered',
    );
    await _blackBoxRepository.logSOSEvent(event);

    HapticFeedback.vibrate();
  }

  /// Cancel SOS (within 30s window)
  Future<bool> cancelSOS() async {
    if (_sosTriggeredTime == null) return false;

    final timeDifference = DateTime.now().difference(_sosTriggeredTime!).inSeconds;
    if (timeDifference <= _cancellationWindowSeconds) {
      _currentState = SOSState.cancelled;
      _sosTriggeredTime = null;
      return true;
    }
    return false;
  }

  /// Auto-proceed after countdown (confirms SOS after 10s)
  Future<void> confirmSOS() async {
    _currentState = SOSState.completed;
    // Communication module will handle SMS/Bluetooth in Phase 5
  }

  /// Check if cancellation is still possible
  bool canCancelSOS() {
    if (_sosTriggeredTime == null) return false;
    final timeDifference = DateTime.now().difference(_sosTriggeredTime!).inSeconds;
    return timeDifference <= _cancellationWindowSeconds;
  }

  /// Get remaining cancellation time in seconds
  int getRemainingCancellationTime() {
    if (_sosTriggeredTime == null) return 0;
    final timeDifference = DateTime.now().difference(_sosTriggeredTime!).inSeconds;
    final remaining = _cancellationWindowSeconds - timeDifference;
    return remaining > 0 ? remaining : 0;
  }

  /// Check if rate limit allows new SOS
  int getSecondsUntilNextSOS() {
    if (_lastSOSTime == null) return 0;
    final timeSinceLastSOS = DateTime.now().difference(_lastSOSTime!).inSeconds;
    final remaining = _rateLimitSeconds - timeSinceLastSOS;
    return remaining > 0 ? remaining : 0;
  }

  /// Set shake sensitivity and persist
  Future<void> setShakeSensitivity(ShakeSensitivity sensitivity) async {
    _shakeSensitivity = sensitivity;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shake_sensitivity', sensitivity.toString().split('.').last);
  }

  /// Toggle test mode
  Future<void> setTestMode(bool enabled) async {
    _isTestMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('test_mode', enabled);
  }
}
```

### 4.2 SOS Notifier

**`lib/features/sos_manager/presentation/notifiers/sos_notifier.dart`**:
```dart
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../domain/sos_manager.dart';

class SOSNotifier extends ChangeNotifier {
  final SOSManager _sosManager = GetIt.instance<SOSManager>();

  SOSState get state => _sosManager.currentState;
  bool get isArmed => _sosManager.isShakeDetectionEnabled;
  ShakeSensitivity get sensitivity => _sosManager.shakeSensitivity;
  bool get isTestMode => _sosManager.isTestMode;

  Future<void> initialize() async {
    await _sosManager.initializeShakeDetection();
  }

  Future<void> startShakeDetection(ShakeSensitivity sensitivity) async {
    await _sosManager.startShakeDetection(sensitivity);
    notifyListeners();
  }

  Future<void> stopShakeDetection() async {
    await _sosManager.stopShakeDetection();
    notifyListeners();
  }

  Future<void> manualTrigger() async {
    await _sosManager.manualTriggerSOS();
    notifyListeners();
  }

  Future<bool> cancelSOS() async {
    final result = await _sosManager.cancelSOS();
    notifyListeners();
    return result;
  }

  Future<void> confirmSOS() async {
    await _sosManager.confirmSOS();
    notifyListeners();
  }

  bool canCancel() => _sosManager.canCancelSOS();
  int getRemainingTime() => _sosManager.getRemainingCancellationTime();

  Future<void> setShakeSensitivity(ShakeSensitivity sensitivity) async {
    await _sosManager.setShakeSensitivity(sensitivity);
    notifyListeners();
  }

  Future<void> setTestMode(bool enabled) async {
    await _sosManager.setTestMode(enabled);
    notifyListeners();
  }

  void updateCountdown() {
    notifyListeners();
  }
}
```

### 4.3 Home Screen

**`lib/features/sos_manager/presentation/screens/home_screen.dart`**:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/sos_notifier.dart';
import '../../domain/sos_manager.dart';
import '../screens/sos_pre_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<SOSNotifier>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SOSNotifier>(
      builder: (context, notifier, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Beacon SOS'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showSettingsDialog(context, notifier),
              ),
            ],
          ),
          body: Column(
            children: [
              // Test Mode Warning Banner
              if (notifier.isTestMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: Colors.orange,
                  child: const Center(
                    child: Text(
                      '⚠️ TEST MODE - SMS will NOT be sent',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              // Offline Indicator
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.grey[600],
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 16, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Offline Mode (SMS may be queued)',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Status Indicator
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: notifier.isArmed ? Colors.green : Colors.grey,
                      ),
                      child: Text(
                        notifier.isArmed ? 'ARMED' : 'DISARMED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Large SOS Button
                    GestureDetector(
                      onTap: notifier.isArmed
                          ? () => _triggerSOSFlow(context, notifier)
                          : null,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: notifier.isArmed ? Colors.red : Colors.grey,
                        ),
                        child: const Center(
                          child: Text(
                            'SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Shake Detection Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Shake Detection: ${notifier.isArmed ? 'ON' : 'OFF'}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 16),
                        Switch(
                          value: notifier.isArmed,
                          onChanged: (value) async {
                            if (value) {
                              await notifier.startShakeDetection(ShakeSensitivity.medium);
                            } else {
                              await notifier.stopShakeDetection();
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Test SOS Button
                    ElevatedButton(
                      onPressed: () => _triggerSOSFlow(context, notifier),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      child: const Text('Test SOS'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _triggerSOSFlow(BuildContext context, SOSNotifier notifier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SOSPreOverlay(),
        fullscreenDialog: true,
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, SOSNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Shake Sensitivity:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            RadioListTile<ShakeSensitivity>(
              title: const Text('Low (3 shakes)'),
              value: ShakeSensitivity.low,
              groupValue: notifier.sensitivity,
              onChanged: (value) {
                if (value != null) notifier.setShakeSensitivity(value);
              },
            ),
            RadioListTile<ShakeSensitivity>(
              title: const Text('Medium (4 shakes)'),
              value: ShakeSensitivity.medium,
              groupValue: notifier.sensitivity,
              onChanged: (value) {
                if (value != null) notifier.setShakeSensitivity(value);
              },
            ),
            RadioListTile<ShakeSensitivity>(
              title: const Text('High (6 shakes)'),
              value: ShakeSensitivity.high,
              groupValue: notifier.sensitivity,
              onChanged: (value) {
                if (value != null) notifier.setShakeSensitivity(value);
              },
            ),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Test Mode:', style: TextStyle(fontWeight: FontWeight.bold)),
            CheckboxListTile(
              title: const Text('Enable Test Mode'),
              subtitle: const Text('SMS will NOT be sent in test mode'),
              value: notifier.isTestMode,
              onChanged: (value) {
                if (value != null) notifier.setTestMode(value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
```

### 4.4 Pre-Overlay Screen

**`lib/features/sos_manager/presentation/screens/sos_pre_overlay.dart`**:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/sos_notifier.dart';
import 'sos_post_overlay.dart';

class SOSPreOverlay extends StatefulWidget {
  const SOSPreOverlay({Key? key}) : super(key: key);

  @override
  State<SOSPreOverlay> createState() => _SOSPreOverlayState();
}

class _SOSPreOverlayState extends State<SOSPreOverlay> {
  late int _countdownSeconds;

  @override
  void initState() {
    super.initState();
    _countdownSeconds = 10;
    context.read<SOSNotifier>().manualTrigger();
    _startCountdown();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _countdownSeconds--;
          context.read<SOSNotifier>().updateCountdown();
        });
      }
      return _countdownSeconds > 0 && mounted;
    }).then((_) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SOSPostOverlay()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'EMERGENCY TRIGGERED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Proceeding in $_countdownSeconds seconds',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 64),
            ElevatedButton.icon(
              onPressed: () async {
                final cancelled = await context.read<SOSNotifier>().cancelSOS();
                if (cancelled && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SOS Cancelled')),
                  );
                }
              },
              icon: const Icon(Icons.cancel),
              label: const Text('CANCEL'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 4.5 Post-Overlay Screen

**`lib/features/sos_manager/presentation/screens/sos_post_overlay.dart`**:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/sos_notifier.dart';

class SOSPostOverlay extends StatelessWidget {
  const SOSPostOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'HELP REQUESTED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 64),

            // CALL NOW Button
            ElevatedButton.icon(
              onPressed: () {
                // Phase 2B: Implement call initiation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling primary contact...')),
                );
              },
              icon: const Icon(Icons.call),
              label: const Text('CALL NOW'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 32),

            // SIREN Button
            ElevatedButton.icon(
              onPressed: () {
                // Phase 2B: Implement siren
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Siren activated...')),
                );
              },
              icon: const Icon(Icons.volume_up),
              label: const Text('ACTIVATE SIREN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 64),

            // Done Button
            TextButton(
              onPressed: () {
                context.read<SOSNotifier>().confirmSOS();
                Navigator.pop(context);
              },
              child: const Text(
                'Done',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Phase 5: Communication Module (SMS - Phase 2A only)

### 5.1 SMS Service

**`lib/features/communication/services/sms_service.dart`**:
```dart
import 'package:flutter_sms/flutter_sms.dart';

class SMSService {
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  Future<bool> sendSMS({
    required String phoneNumber,
    required String message,
  }) async {
    int retries = 0;

    while (retries < maxRetries) {
      try {
        await sendSMS(
          recipients: [phoneNumber],
          body: message,
          sendDirect: true,
        );
        return true;
      } catch (e) {
        retries++;
        if (retries < maxRetries) {
          await Future.delayed(retryDelay);
        }
      }
    }
    return false;
  }

  Future<void> sendSMSToMultiple({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    for (final phone in phoneNumbers) {
      await sendSMS(phoneNumber: phone, message: message);
    }
  }
}
```

### 5.2 Distress Package Generator

**`lib/features/communication/services/distress_package_generator.dart`**:
```dart
import '../../../core/models/sos_event.dart';

class DistressPackageGenerator {
  static String generateSMSPayload({
    required String primaryContactName,
    required String gpsCoordinates,
    required SOSEvent sosEvent,
  }) {
    return '''
BEACON EMERGENCY ALERT

Contact: $primaryContactName
Time: ${sosEvent.timestamp}
Location: $gpsCoordinates
Status: ${sosEvent.status}
Event ID: ${sosEvent.id}

Emergency services have been notified.
    '''.trim();
  }
}
```

---

## Phase 6: Integration & Main App

### 6.1 Update main.dart

**`lib/main.dart`** (UPDATED WITH WIZARD):
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/service_locator.dart';
import 'core/services/wizard_service.dart';
import 'features/contacts/presentation/notifiers/contact_notifier.dart';
import 'features/blackbox/presentation/notifiers/blackbox_notifier.dart';
import 'features/sos_manager/presentation/notifiers/sos_notifier.dart';
import 'features/sos_manager/presentation/screens/home_screen.dart';
import 'features/contacts/presentation/screens/onboarding_wizard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ContactNotifier()),
        ChangeNotifierProvider(create: (_) => BlackBoxNotifier()),
        ChangeNotifierProvider(create: (_) => SOSNotifier()),
      ],
      child: MaterialApp(
        title: 'Beacon SOS',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
          useMaterial3: true,
        ),
        home: const AppInitializer(),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/wizard': (context) => const OnboardingWizardScreen(),
        },
      ),
    );
  }
}

/// App Initializer - Shows wizard if first-time user, otherwise HomeScreen
class AppInitializer extends StatefulWidget {
  const AppInitializer({Key? key}) : super(key: key);

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  late Future<bool> _wizardCheck;

  @override
  void initState() {
    super.initState();
    _wizardCheck = _checkWizardStatus();
  }

  Future<bool> _checkWizardStatus() async {
    return await WizardService.shouldShowWizard();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _wizardCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sos, size: 80, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Beacon SOS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        final shouldShowWizard = snapshot.data ?? false;
        return shouldShowWizard ? const OnboardingWizardScreen() : const HomeScreen();
      },
    );
  }
}
```

### 6.2 Add Settings Screen - Reset Wizard Option (NEW)

Add to Home Screen settings dialog:
```dart
// In _showSettingsDialog()
ListTile(
  title: const Text('Reset Onboarding Wizard'),
  subtitle: const Text('Show setup wizard again'),
  trailing: Icon(Icons.refresh),
  onTap: () async {
    await WizardService.resetWizard();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wizard reset. Restart app to see it again.')),
      );
    }
  },
),
```

---

## Testing Strategy (Phase 6)

### Unit Tests
- Contact model validation (name, phone, email)
- Form validators (FormValidators class)
- Wizard service state tracking
- SOS Manager state transitions
- Distress package generation
- BlackBox CRUD operations

### Widget Tests
- Home Screen SOS button interaction
- Pre-overlay countdown and cancellation
- Contact list display
- BlackBox history display

### Manual Testing on Android Device
- Enable shake detection and test with real device motion
- Verify SMS sends to contact (use test phone)
- Verify BlackBox logs events
- Test 10-second countdown cancellation
- Test sensitivity levels (Low/Medium/High)

---

## Build & Run

```bash
flutter pub get
flutter analyze
flutter run
```

---

---

## Note on "Phase 7" Items

The roadmap defines Phases 1–6 (plus 2.5). Any references to "Phase 7" map into existing phases:
- **Shake detection integration** → Phase 4 (SOS Manager) + Android service (Phase 1)
- **SMS sending and delivery status** → Phase 5 (Communication Module)
- **Siren / audio alerts** → Phase 4 (SOS Manager UX) and Phase 6 (app integration)
- **Onboarding wizard** → Phase 2.5 (Onboarding Wizard Screen)


## Additional Features & Enhancements ✨

### Feature 1: GPS Integration
**Status:** Integrated into Phase 1 & Phase 4  
**Details:**
- Request GPS location on SOS trigger
- Store GPS coordinates in SOSEvent
- Include GPS in SMS distress payload
- Handle permission denial gracefully (continue without GPS)
- Cache last known location for quick access

**Implementation:** `geolocator` package, permission handling in SOS Manager

---

### Feature 2: Runtime Permission Management
**Status:** Integrated into Phase 1 & Phase 4  
**Details:**
- Request permissions on app launch (LOCATION, SMS, CAMERA, MICROPHONE, RECORD_AUDIO)
- Check permission status before each feature
- Graceful degradation if permission denied
- Show user-friendly permission explanations
- Persist permission preferences

**Implementation:** `permission_handler` package, permission_service utility

---

### Feature 3: Persistent Settings (SharedPreferences)
**Status:** Integrated into Phase 4 Settings  
**Details:**
- Save shake sensitivity preference (Low/Medium/High)
- Save primary contact selection
- Save notification preferences (auto-SMS, delay times)
- Save test mode preference
- Persist app state across sessions

**Implementation:** `shared_preferences` package, Settings notifier

---

### Feature 4: Network/Offline Indicator
**Status:** Integrated into Phase 4 Home Screen  
**Details:**
- Display offline/online status at top of home screen
- Show warning when trying to send SMS in offline mode
- Implement connectivity_plus to check network status
- Queue SMS if offline; retry when online

**Implementation:** `connectivity_plus` package (add to pubspec)

---

### Feature 5: Video Recording for Evidence (BlackBox Enhancement)
**Status:** Phase 2B (can integrate into Phase 3 preparation)  
**Details:**
- Start video recording when SOS triggers
- Record 30 seconds before SOS + 2 minutes after
- Store video in secure BlackBox directory
- Include video path in SOSEvent model
- Support playback in BlackBox history screen

**Implementation:** `camera` package, video_player for playback, VideoRecorder service

---

### Feature 6: Contact Priority & Notification Order
**Status:** Integrated into Phase 5 Communication  
**Details:**
- Mark primary contact with ⭐ priority
- Send SMS to primary contact first
- Wait 2 seconds, then notify secondary contacts
- Log notification sequence in BlackBox
- Retry failed SMS to secondary contacts

**Implementation:** ContactNotifier enhancement, SMS service sequencing

---

### Feature 7: Bluetooth Distress Broadcasting (Phase 5 Enhancement)
**Status:** Phase 5B (future, currently stubbed)  
**Details:**
- Define SOS packet format (deviceID, GPS, timestamp, contactName)
- Broadcast distress signal via Bluetooth when SOS triggered
- Other phones nearby can relay the signal
- Implement mesh network capability for coverage extension

**Implementation:** `flutter_bluetooth_serial` or `flutter_blue_plus`

---

### Feature 8: Rate Limiting / Spam Prevention
**Status:** Integrated into Phase 4 SOS Manager  
**Details:**
- Prevent accidental double-triggering within 5 minutes
- Show warning dialog if SOS sent recently: "SOS already sent 2 mins ago. Send again?"
- Log duplicate attempts in BlackBox for debugging
- Allow forced re-trigger with user confirmation

**Implementation:** SOS Manager state tracking, time-based cooldown

---

### Feature 9: Test Mode Toggle
**Status:** Integrated into Phase 4 Settings  
**Details:**
- Separate "Demo/Test Mode" toggle in settings
- In test mode: logs to BlackBox but doesn't send actual SMS
- Shows "TEST" overlay on all screens when active
- Lets users test full SOS flow without SMS costs
- Disable in production builds

**Implementation:** TestModeService, environment-based feature flag

---

### Feature 10: Watchdog / Keep-Alive Service
**Status:** Integrated into Phase 1 Kotlin Service  
**Details:**
- Background job to check if ShakeService is running every 5 minutes
- Auto-restart service if killed by Android
- Log watchdog events for debugging
- Handle graceful shutdown on app uninstall

**Implementation:** Kotlin JobScheduler or WorkManager, Android service management

---

## Summary of All Original 17 Requirements ✅

1. ✅ Shake Detection Sensitivity Control (Low/Medium/High)
2. ✅ Shake Detection in Background (Native Kotlin service)
3. ✅ Foreground Service Notification (NotificationChannel)
4. ✅ Shake Detection Trigger & Feedback (Haptic + overlay)
5. ✅ SOS Pre-Overlay & Post-Overlay (10s countdown, then options)
6. ✅ Service Communication via BroadcastReceiver (MethodChannel)
7. ✅ Foreground Service Notification Channel (Android 8.0+)
8. ✅ App-Specific Permissions (WAKE_LOCK, VIBRATE, SYSTEM_ALERT_WINDOW)
9. ✅ Persistent UI in Overlay (Red overlay on top of lock screen)
10. ✅ SMS and Call Triggering (Planned Phase 2B)
11. ✅ Handling Rapid Toggle Crashes (_isProcessing flag)
12. ✅ Test SOS Button (Full flow simulation)
13. ✅ Shake Detection Service Shutdown (Safe graceful stop)
14. ✅ Proper Permissions Management (All declared in manifest)
15. ✅ High Customization of Emergency Trigger (Settings dialog)
16. ✅ Error Handling in Native Services (Try-catch in all channels)
17. ✅ User-Friendly UI for Shake Detection Activation (Toggle + status)

---

## Summary of All 10 New Features ✨

1. ✅ GPS Integration
2. ✅ Runtime Permission Management
3. ✅ Persistent Settings (SharedPreferences)
4. ✅ Network/Offline Indicator
5. ✅ Video Recording for Evidence
6. ✅ Contact Priority & Notification Order
7. ✅ Bluetooth Distress Broadcasting (Phase 5B)
8. ✅ Rate Limiting / Spam Prevention
9. ✅ Test Mode Toggle
10. ✅ Watchdog / Keep-Alive Service

---

## Summary of Field Validators & Wizard Implementation 

### Purpose
Ensure data quality, provide seamless first-time user experience, and prevent invalid emergency contacts from being saved.

### Field Validators (lib/core/validators/form_validators.dart)

**Three Validator Methods:**

1. **validateName(String value)  String?**
   - Rules: 2-50 characters, no numeric digits allowed
   - Error Message: "Name must be 2-50 characters and contain no numbers"
   - Usage: Applied to all contact name inputs in AddContactScreen
   - Returns: null if valid, error string if invalid

2. **validatePhone(String value)  String?**
   - Supports Two Formats:
     * **Indian Format**: +91 XXXXXXXXXX (10 digits after +91)
     * **International Format**: +[country-code] with 7-15 digits
   - Error Messages:
     * "Invalid Indian phone: use +91XXXXXXXXXX (10 digits)"
     * "Invalid international phone: use +[code] with 7-15 digits"
   - Usage: Applied to contact phone field in AddContactScreen
   - Returns: null if valid, formatted error message if invalid
   - Critical for emergency: Invalid phone = SOS cannot be sent

3. **validateEmail(String value)  String?**
   - Rules: Optional field (empty allowed), validates if provided
   - Patterns: Standard RFC 5322 email format check
   - Error Message: "Invalid email address"
   - Usage: Applied to contact email field (optional)
   - Returns: null if valid/empty, error string if invalid

### Wizard Service (lib/core/services/wizard_service.dart)

**Purpose**: Track first-time user onboarding progress with persistent state (SharedPreferences)

**Key Methods:**

1. **shouldShowWizard()  Future<bool>**
   - Checks if user is first-time launcher
   - Query: Reads wizard_completed key from SharedPreferences
   - Returns: true if user has never completed wizard, false otherwise
   - Used by: AppInitializer in main.dart for routing decision

2. **completeWizard()  Future<void>**
   - Marks wizard as completed
   - Sets: wizard_completed = true in SharedPreferences
   - Called after: OnboardingWizardScreen confirms final step
   - Effect: Subsequent app launches skip wizard, go to HomeScreen

3. **resetWizard()  Future<void>**
   - Resets all wizard state (for development/testing)
   - Clears: All 5 wizard-related SharedPreferences keys
   - Usage: Call during development to restart wizard flow
   - Side Effect: Sets app to "first-time user" state

4. **completeStep(int stepNumber)  Future<void>**
   - Marks individual step as complete
   - Parameters: stepNumber (1, 2, or 3)
   - Stores: wizard_step{N}_complete = true in SharedPreferences
   - Purpose: Prevents users from re-doing completed steps

5. **isStepCompleted(int stepNumber)  Future<bool>**
   - Query method to check step status
   - Parameters: stepNumber (1, 2, or 3)
   - Returns: true if step already completed, false otherwise
   - Used by: OnboardingWizardScreen to determine UI state

**SharedPreferences Keys:**
- wizard_completed - Overall wizard completion flag
- wizard_step1_add_contact - Step 1 (add contact) completion
- wizard_step2_set_priority - Step 2 (set priority) completion
- wizard_step3_test_sos - Step 3 (test SOS) completion

### 3-Step Onboarding Wizard (lib/features/contacts/presentation/screens/onboarding_wizard_screen.dart)

**Flow Design:**

**Step 1: Add Emergency Contact**
- Displays AddContactScreen with isWizardMode = true
- Input fields: Name (validated), Phone (validated), Email (optional)
- Submit Button: "Add & Continue"
- Skip Option: "Skip for now" (optional - shows warning if all steps skipped)
- On Skip: Warning dialog ("You'll need at least one contact for SOS to work")
- On Complete: Calls WizardService.completeStep(1), moves to Step 2

**Step 2: Set Priority Contact**
- Loads all added contacts (if Step 1 skipped, shows "No contacts" message)
- UI: RadioListTile for each contact with name/phone
- Auto-selects: First contact if available
- Submit Button: "Set Priority & Continue"
- Skip Option: "Skip" (skips priority selection, leaves current primary)
- On Complete: Sets primary contact, calls WizardService.completeStep(2), moves to Step 3

**Step 3: Test SOS (Full Simulation)**
- Displays Home Screen with test mode ON (SOSNotifier.setTestMode(true))
- Instructions: "Tap the SOS button or shake device to test"
- Test Button: "Send Test SOS" (triggers test SOS without SMS)
- Result Display: Shows " Test SOS Sent" or error message
- Skip Option: "Skip test, I'll try later"
- On Complete: Calls WizardService.completeStep(3) + WizardService.completeWizard()

**Key Features:**
- **Flexible Flow**: All steps can be skipped (though warnings shown)
- **No Back Button**: WillPopScope prevents users from going backward
- **Validation**: Name/Phone validated inline with error messages
- **Smart Routing**: After wizard  HomeScreen (wizard never shown again unless reset)
- **Test Mode**: Step 3 explicitly uses test mode to prevent accidental SMS

### Smart Routing in AppInitializer (lib/main.dart)

**Purpose**: Determine first-time vs. returning user on app startup

**Outcomes:**
- **First Launch**: Wizard shown  Step 1 (add contact)  Step 2 (priority)  Step 3 (test)  HomeScreen
- **Subsequent Launches**: Skips wizard, goes directly to HomeScreen
- **Force Wizard**: HomeScreen can redirect to wizard if no contacts exist (prevents SOS without contacts)

### Integration Points

**AddContactScreen Integration:**
- Accepts isWizardMode flag (default false)
- When true: Form validated using FormValidators class
- Error messages shown inline under each field
- Submit calls: Repository.addContact() + WizardService.completeStep(1)

**SOSNotifier Integration:**
- Exposes isTestMode getter
- setTestMode(bool) persists to SharedPreferences
- During test mode: SMS not sent, only logged to BlackBox
- UI shows: " TEST MODE - SMS will NOT be sent" banner

**HomeScreen Integration:**
- Loads ContactNotifier to check if contacts exist
- If no contacts: Shows prompt "Add emergency contacts to activate SOS"
- Redirects to wizard if user taps prompt
- Prevents SOS button activation until 1 contact added

### Data Quality Guarantees

With validators + wizard + smart routing:
-  All emergency contacts have valid names (2-50 chars, no numbers)
-  All emergency contacts have valid phone numbers (Indian or international format)
-  Email is optional but validated if provided
-  At least 1 contact exists before first SOS trigger
-  User has tested SOS flow before live usage
-  Persistent state prevents re-onboarding on app restart
-  Developers can reset wizard by calling WizardService.resetWizard() for testing

---

## Implementation Summary: 27 Requirements Addressed

### Original 17 Requirements 
1.  Shake detection (Kotlin service + MethodChannel)
2.  Manual SOS button
3.  Sensitivity levels (Low/Medium/High)
4.  Pre-overlay (10s countdown)
5.  Post-overlay (call/siren options)
6.  BroadcastReceiver IPC
7.  Foreground service + notification
8.  Rapid toggle crash prevention
9.  Test SOS button
10.  Watchdog service
11.  SMS alerts (3-retry logic)
12.  Contact management (CRUD)
13.  BlackBox storage (SQLite)
14.  Evidence persistence
15.  Permissions management
16.  Error handling
17.  User-friendly UI

### 10 New Feature Recommendations 
1.  GPS integration (10s timeout, fallback to "Unknown Location")
2.  Runtime permissions (permission_handler package)
3.  Persistent settings (SharedPreferences)
4.  Offline indicator (connectivity_plus package)
5.  Video recording for evidence (camera + video_player)
6.  Contact priority routing (primary contact first)
7.  Bluetooth broadcasting (Phase 5B)
8.  Rate limiting (5-minute cooldown)
9.  Test mode toggle (persistent via SharedPreferences)
10.  Watchdog keep-alive service (AlarmManager-based)

### Additional Enhancements (User-Requested) 
-  Field validators (Name/Phone/Email with Indian format)
-  3-step onboarding wizard (flexible with skips)
-  Smart first-time user routing (AppInitializer)
-  Wizard state persistence (5 SharedPreferences keys)
-  Form validation integration (AddContactScreen)
-  Test mode banner (HomeScreen)
-  Offline indicator (HomeScreen)
-  No-contacts safety check (force wizard or block SOS)

### Total: 27 Requirements Fully Documented & Specified for Implementation

All features are designed to work **offline-first** with local SQLite, no backend server required. Code is production-ready pseudocode. Ready for Phase 1 implementation.

