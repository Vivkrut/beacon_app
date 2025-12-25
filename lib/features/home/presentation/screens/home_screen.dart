import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:beacon/core/models/sos_event.dart';
import 'package:beacon/core/models/contact.dart';
import 'package:beacon/features/blackbox/presentation/notifiers/blackbox_notifier.dart';
import 'package:beacon/features/settings/presentation/screens/settings_screen.dart';
import 'package:beacon/features/contacts/data/contact_repository.dart';
import 'package:beacon/features/sos_manager/domain/sos_manager.dart';
import 'package:beacon/features/sos_manager/presentation/screens/pre_sos_screen.dart';
import 'package:beacon/features/sos_manager/presentation/screens/post_sos_screen.dart';
import 'package:beacon/features/home/presentation/widgets/sos_status_bar.dart';
import 'package:beacon/features/communication/services/sms_service.dart';
import 'package:beacon/core/services/permission_service.dart';
import 'package:beacon/core/constants/app_constants.dart';
import 'package:vibration/vibration.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _ShakeConfig {
  final int level;
  final int requiredShakes;
  const _ShakeConfig({required this.level, required this.requiredShakes});
}

class _HomeScreenState extends State<HomeScreen> {
  static const MethodChannel _shakeServiceChannel = MethodChannel(
    'com.beacon/shake_service',
  );
  static const MethodChannel _shakeEventsChannel = MethodChannel(
    'com.beacon/shake_events',
  );

  bool _shakeDetectionEnabled = true;
  bool _isProcessing = false;
  bool _sosTriggered = false;
  String _shakeSensitivity = AppConstants.defaultShakeSensitivity;
  late Timer _statusUpdateTimer;
  final SOSManager _sosManager = SOSManager();
  final ContactRepository _contactRepository = ContactRepository();
  final SMSService _smsService = SMSService();
  _ShakeConfig? _cachedShakeConfig;

  @override
  void initState() {
    super.initState();
    _setupShakeListener();
    _loadPreferences();
    // Timer to update status bar every second
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          // Rebuild to get updated seconds from SOSManager
        });
      }
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shakeDetectionEnabled = prefs.getBool('shakeEnabled') ?? true;
      _shakeSensitivity =
          prefs.getString(AppConstants.prefKeyShakeSensitivity) ??
          AppConstants.defaultShakeSensitivity;
      _cachedShakeConfig = _mapSensitivity(_shakeSensitivity);
    });

    if (_shakeDetectionEnabled) {
      await _startShakeService();
    }
  }

  @override
  void dispose() {
    if (_shakeDetectionEnabled) {
      _stopShakeService();
    }
    _statusUpdateTimer.cancel();
    super.dispose();
  }

  Future<void> _toggleShakeDetection(bool value) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          value ? 'Enable Shake Detection?' : 'Disable Shake Detection?',
        ),
        content: Text(
          value
              ? 'Shake detection will be active and will trigger SOS on device shake.'
              : 'Shake detection will be disabled. You can still trigger SOS manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('shakeEnabled', value);

      if (mounted) {
        setState(() {
          _shakeDetectionEnabled = value;
          _isProcessing = false;
        });

        if (value) {
          await _startShakeService();
        } else {
          await _stopShakeService();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? 'Shake detection enabled' : 'Shake detection disabled',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _setupShakeListener() async {
    _shakeEventsChannel.setMethodCallHandler((call) async {
      if (call.method == 'shakeDetected') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shake detected! Triggering SOS...')),
          );
        }
        await _triggerSOS(isManual: false);
      }
    });
  }

  Future<void> _startShakeService() async {
    try {
      final config = _cachedShakeConfig ?? _mapSensitivity(_shakeSensitivity);
      await _shakeServiceChannel.invokeMethod('startShakeDetection', {
        'sensitivity': config.level,
        'requiredShakes': config.requiredShakes,
      });
    } catch (e) {
      print('[Shake] Failed to start shake detection: $e');
    }
  }

  Future<void> _stopShakeService() async {
    try {
      await _shakeServiceChannel.invokeMethod('stopShakeDetection');
    } catch (e) {
      print('[Shake] Failed to stop shake detection: $e');
    }
  }

  _ShakeConfig _mapSensitivity(String value) {
    switch (value.toUpperCase()) {
      case 'LOW':
        return const _ShakeConfig(
          level: 1,
          requiredShakes: AppConstants.shakeLowSensitivity,
        );
      case 'HIGH':
        return const _ShakeConfig(
          level: 3,
          requiredShakes: AppConstants.shakeHighSensitivity,
        );
      case 'MEDIUM':
      default:
        return const _ShakeConfig(
          level: 2,
          requiredShakes: AppConstants.shakeMediumSensitivity,
        );
    }
  }

  /// Request location permission and get GPS coordinates
  Future<String?> _getGPSLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return null;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Location permission denied'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return null;
      }

      final Position position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 10),
      );
      return '${position.latitude.toStringAsFixed(4)}°, ${position.longitude.toStringAsFixed(4)}°';
    } catch (e) {
      print('GPS Error: $e');
    }
    return null;
  }

  Future<void> _vibrateOnSOS() async {
    try {
      final canVibrate = await Vibration.hasVibrator() ?? false;
      if (!canVibrate) return;

      final hasCustom = await Vibration.hasCustomVibrationsSupport() ?? false;
      if (hasCustom) {
        await Vibration.vibrate(pattern: [0, 400, 120, 400, 120, 400]);
      } else {
        await Vibration.vibrate(duration: 800);
      }
    } catch (e) {
      print('[Vibration] Error triggering vibration: $e');
    }
  }

  Future<void> _vibrateOnCountdownStart() async {
    try {
      final canVibrate = await Vibration.hasVibrator() ?? false;
      if (!canVibrate) return;

      final hasCustom = await Vibration.hasCustomVibrationsSupport() ?? false;
      if (hasCustom) {
        await Vibration.vibrate(pattern: [0, 220, 120, 220]);
      } else {
        await Vibration.vibrate(duration: 220);
      }
    } catch (e) {
      print('[Vibration] Error triggering countdown vibration: $e');
    }
  }

  Future<void> _triggerSOS({required bool isManual}) async {
    print('[SOS Trigger] Starting SOS trigger, isManual=$isManual');

    if (_sosTriggered) {
      print('[SOS Trigger] Already in progress, ignoring duplicate trigger');
      return;
    }

    // Check rate limiting
    if (!_sosManager.canTriggerSOS()) {
      final secondsLeft = _sosManager.getSecondsUntilNextSOS();
      print('[SOS Trigger] Rate limited: $secondsLeft seconds remaining');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⏱️ Wait ${secondsLeft}s before next SOS (2 min cooldown)',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        setState(() {});
      }
      return;
    }

    print('[SOS Trigger] Rate limit check passed');

    if (mounted) {
      setState(() => _sosTriggered = true);
    }

    // Show Pre-SOS Countdown
    if (!mounted) return;
    print('[SOS Trigger] Showing pre-SOS countdown dialog');

    // Haptic alert so user can cancel quickly if accidental trigger
    await _vibrateOnCountdownStart();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PreSOSScreen(
        onConfirm: (_) {},
        onCancel: (_) {},
        countdownSeconds: _sosManager.countdownSeconds,
      ),
    );

    print('[SOS Trigger] Dialog returned: confirmed=$confirmed');

    if (confirmed == null || !confirmed) {
      print('[SOS Trigger] SOS was cancelled or dialog closed');
      if (mounted) {
        setState(() => _sosTriggered = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ SOS Cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    print('[SOS Trigger] SOS confirmed, proceeding...');

    // Provide immediate haptic feedback after confirmation
    await _vibrateOnSOS();

    try {
      // Record SOS time for rate limiting (persist)
      print('[SOS Trigger] Recording SOS time');
      await _sosManager.recordSOSTime();

      // Fetch GPS location
      print('[SOS Trigger] Fetching GPS location');
      final gpsLocation = await _getGPSLocation() ?? 'Unknown Location';
      print('[SOS Trigger] GPS location: $gpsLocation');

      // Fetch primary contact
      print('[SOS Trigger] Fetching primary contact');
      final allContacts = await _contactRepository.getAllContacts();
      allContacts.sort((a, b) => (b.isPrimary ? 1 : 0) - (a.isPrimary ? 1 : 0));
      final primaryContact = allContacts.isNotEmpty ? allContacts.first : null;
      final contactsForAlert = allContacts.take(3).toList();
      print('[SOS Trigger] Primary contact: ${primaryContact?.name}');

      // Create SOS event with GPS location
      print('[SOS Trigger] Creating SOS event');
      final sosEvent = SOSEvent(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        gpsCoordinates: gpsLocation,
        contactsNotified: contactsForAlert.map((c) => c.name).toList(),
        status: 'triggered',
        note: isManual ? 'MANUAL SOS' : 'SHAKE TRIGGERED SOS',
      );
      print('[SOS Trigger] SOS event created: ${sosEvent.id}');

      // Log to BlackBox
      if (mounted) {
        print('[SOS Trigger] Adding to BlackBox');
        print(
          '[BlackBox] Logging SOS Event: ID=${sosEvent.id}, GPS=$gpsLocation',
        );
        try {
          await context.read<BlackBoxNotifier>().addEvent(sosEvent);
          print('[BlackBox] Event logged successfully');
          setState(() => _sosTriggered = true);
        } catch (e) {
          print('[BlackBox] Error logging event: $e');
          setState(() => _sosTriggered = true);
        }
      }

      // Send SMS alerts to contacts
      await _sendSmsAlerts(sosEvent, contactsForAlert);

      print('[SOS Trigger] Navigating to Post-SOS screen');
      // Show Post-SOS Screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostSOSScreen(
              primaryContact: primaryContact,
              onCallNow: () {
                _makeCall(primaryContact?.phone ?? '');
              },
              onSirenToggle: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🔊 Siren feature coming soon')),
                );
              },
            ),
          ),
        ).then((_) {
          print('[SOS Trigger] Returned from Post-SOS screen');
          if (mounted) {
            setState(() => _sosTriggered = false);
          }
        });
      }
    } catch (e) {
      print('[SOS Trigger] ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _sosTriggered = false);
      }
    }
  }

  Future<void> _sendSmsAlerts(SOSEvent event, List<Contact> contacts) async {
    if (contacts.isEmpty) return;

    final allowed = await PermissionService.requestSmsPermission();
    if (!allowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS permission denied. Alerts not sent.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final recipients = contacts
        .map((c) => c.phone)
        .where((p) => p.isNotEmpty)
        .toList();
    if (recipients.isEmpty) return;

    final body =
        '''BEACON SOS ALERT
Time: ${event.timestamp.toIso8601String()}
Location: ${event.gpsCoordinates ?? 'Unknown'}
Event ID: ${event.id}
Status: ${event.status}''';

    try {
      await _smsService.sendBulk(recipients: recipients, body: body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS alerts sent to contacts'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('[SMS] Failed to send alerts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SMS send failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ No phone number available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Cannot make call'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _triggerTestSOS() async {
    // Fetch all valid emergency contacts
    final prefs = await SharedPreferences.getInstance();
    final phone1 = prefs.getString('contact_1_phone') ?? '';
    final phone2 = prefs.getString('contact_2_phone') ?? '';
    final phone3 = prefs.getString('contact_3_phone') ?? '';

    final contactsNotified = <String>[
      if (phone1.isNotEmpty) phone1,
      if (phone2.isNotEmpty) phone2,
      if (phone3.isNotEmpty) phone3,
    ];

    // Get GPS location for test
    final gpsLocation = await _getGPSLocation() ?? '0.0, 0.0';

    // Create a new SOS event with "Test SOS" marker
    final event = SOSEvent(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      gpsCoordinates: gpsLocation,
      contactsNotified: contactsNotified,
      status: 'sent',
      note: 'TEST SOS',
    );

    // Add event to BlackBox
    if (mounted) {
      await context.read<BlackBoxNotifier>().addEvent(event);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🚨 Test SOS logged - GPS: $gpsLocation'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _navigateToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    _loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beacon'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          SOSStatusBar(
            shakeDetectionActive: _shakeDetectionEnabled,
            secondsUntilNextSOS: _sosManager.getSecondsUntilNextSOS(),
            sosTriggered: _sosTriggered,
          ),
          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Main Title
                  const SizedBox(height: 40),
                  const Text(
                    'Beacon — SOS Emergency',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),

                  // Shake Detection Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Shake Detection',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Switch(
                          value: _shakeDetectionEnabled,
                          onChanged: _toggleShakeDetection,
                          activeThumbColor: Colors.red,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Manual SOS Button
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _triggerSOS(isManual: true),
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _triggerSOS(isManual: true),
                              customBorder: const CircleBorder(),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.emergency,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'SOS',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'TAP FOR HELP',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Test Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _triggerTestSOS,
                        icon: const Icon(Icons.bug_report),
                        label: const Text('Test SOS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
