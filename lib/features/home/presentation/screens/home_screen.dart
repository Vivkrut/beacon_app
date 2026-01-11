import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:beacon/core/models/sos_event.dart';
import 'package:beacon/core/models/contact.dart';
import 'package:beacon/features/blackbox/presentation/notifiers/blackbox_notifier.dart';
import 'package:beacon/features/blackbox/services/video_evidence_service.dart';
import 'package:beacon/features/settings/presentation/screens/settings_screen.dart';
import 'package:beacon/features/contacts/data/contact_repository.dart';
import 'package:beacon/features/sos_manager/domain/sos_manager.dart';
import 'package:beacon/core/services/sms_role_service.dart';
import 'package:beacon/features/sos_manager/presentation/screens/pre_sos_screen.dart';
import 'package:beacon/features/sos_manager/presentation/screens/post_sos_screen.dart';
import 'package:beacon/features/home/presentation/widgets/sos_status_bar.dart';
import 'package:beacon/features/communication/services/sms_service.dart';
import 'package:beacon/core/services/permission_service.dart';
import 'package:beacon/core/constants/app_constants.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

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
  String _userName = '';
  late Timer _statusUpdateTimer;
  final SOSManager _sosManager = SOSManager();
  final ContactRepository _contactRepository = ContactRepository();
  final SMSService _smsService = SMSService();
  TwilioService? _twilioService;
  final VideoEvidenceService _videoEvidenceService = VideoEvidenceService();
  _ShakeConfig? _cachedShakeConfig;

  @override
  void initState() {
    super.initState();
    _setupShakeListener();
    _loadPreferences();
    _twilioService = _buildTwilioService();
    _promptDefaultSmsRole();
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
      _userName = prefs.getString('user_name') ?? '';
    });

    if (_shakeDetectionEnabled) {
      await _startShakeService();
    }
  }

  Future<void> _promptDefaultSmsRole() async {
    // Option 1 baseline: no default SMS requirement; do nothing.
    return;
  }

  @override
  void dispose() {
    if (_shakeDetectionEnabled) {
      _stopShakeService();
    }
    _videoEvidenceService.dispose();
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

  TwilioService? _buildTwilioService() {
    const sid = AppConstants.twilioAccountSid;
    const token = AppConstants.twilioAuthToken;
    const from = AppConstants.twilioFromNumber;

    final configured =
        sid.isNotEmpty &&
        token.isNotEmpty &&
        from.isNotEmpty &&
        !sid.startsWith('<') &&
        !token.startsWith('<') &&
        !from.startsWith('<');

    if (!configured) {
      print('[Twilio] Missing credentials; skipping Twilio wiring.');
      return null;
    }

    print('[Twilio] Twilio configured, wiring service.');
    return TwilioService(accountSid: sid, authToken: token, fromNumber: from);
  }

  String _formatDate(DateTime ts) => ts.toIso8601String().split('T').first;

  String _formatTime(DateTime ts) =>
      '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

  String _buildLocationWithLink(String gps) {
    final regex = RegExp(r'([-0-9.]+)\D+([-0-9.]+)');
    final match = regex.firstMatch(gps);
    if (match != null) {
      final lat = match.group(1);
      final lng = match.group(2);
      return 'https://maps.google.com/?q=$lat,$lng';
    }
    return gps;
  }

  String _buildAlertMessage({required SOSEvent event, bool isTest = false}) {
    final headingName = _userName.trim().isEmpty ? '' : ' ${_userName.trim()}';
    final heading = 'BEACON SOS ALERT$headingName${isTest ? ' [TEST]' : ''}';
    final dateStr = _formatDate(event.timestamp);
    final timeStr = _formatTime(event.timestamp);
    final gps = event.gpsCoordinates ?? AppConstants.unknownLocationPlaceholder;
    final location = _buildLocationWithLink(gps);

    return '$heading\n'
        'Date: $dateStr Time: $timeStr\n'
        'Location: $location\n'
        'Emergency: I need help. Please call or reach me immediately.';
  }

  Future<String?> _getGPSLocation() async {
    try {
      final alreadyGranted =
          await PermissionService.isLocationPermissionGranted();
      final hasPermission = alreadyGranted
          ? true
          : await PermissionService.requestLocationPermission();
      if (!hasPermission) {
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

      // Ensure all critical permissions are granted once before parallel work
      final permsOk = await PermissionService.requestAllPermissions();
      if (!permsOk) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permissions missing: enable SMS/Camera/Mic/Location/Call',
              ),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _sosTriggered = false);
        }
        return;
      }

      // Fetch contacts (all) with primary prioritized
      print('[SOS Trigger] Fetching contacts');
      final allContacts = await _contactRepository.getAllContacts();
      allContacts.sort((a, b) => (b.isPrimary ? 1 : 0) - (a.isPrimary ? 1 : 0));
      final primaryContact = allContacts.isNotEmpty ? allContacts.first : null;
      final contactsForAlert = allContacts; // send to all saved contacts
      print('[SOS Trigger] Primary contact: ${primaryContact?.name}');

      // Kick off GPS lookup and evidence capture concurrently
      print('[SOS Trigger] Fetching GPS location & starting evidence capture');
      final gpsFuture = _getGPSLocation();
      final evidenceFuture = _collectEvidencePath();

      final gpsLocation = await gpsFuture ?? 'Unknown Location';
      print('[SOS Trigger] GPS location: $gpsLocation');

      // Create SOS event with available data (evidence path will update asynchronously)
      print('[SOS Trigger] Creating SOS event');
      var sosEvent = SOSEvent(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        gpsCoordinates: gpsLocation,
        contactsNotified: contactsForAlert.map((c) => c.name).toList(),
        contactsPhones: contactsForAlert.map((c) => c.phone).toList(),
        status: 'pending',
        evidencePath: null,
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

      // Fire off SMS sending without blocking UI; update status when done
      final smsFuture = _sendSmsAlerts(sosEvent, contactsForAlert);
      smsFuture.then((result) async {
        final didSend = result.sent.isNotEmpty;
        sosEvent = sosEvent.copyWith(
          status: didSend ? 'sent' : 'failed',
          sentPhones: result.sent,
          failedPhones: result.failed,
        );
        if (mounted) {
          await context.read<BlackBoxNotifier>().updateEvent(sosEvent);
        }
      });

      // Attach evidence when recording finishes
      evidenceFuture.then((path) async {
        if (path == null || path.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Evidence capture failed'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        sosEvent = sosEvent.copyWith(evidencePath: path);
        if (mounted) {
          await context.read<BlackBoxNotifier>().updateEvent(sosEvent);
        }
      });

      print('[SOS Trigger] Navigating to Post-SOS screen');
      // Show Post-SOS Screen immediately while background tasks run
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

  Future<SMSResult> _sendSmsAlerts(
    SOSEvent event,
    List<Contact> contacts,
  ) async {
    if (contacts.isEmpty) return const SMSResult(sent: [], failed: []);

    final allowed =
        await PermissionService.isSmsPermissionGranted() ||
        await PermissionService.requestSmsPermission();
    if (!allowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS permission denied. Alerts not sent.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return const SMSResult(sent: [], failed: []);
    }

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity != ConnectivityResult.none;
    final twilioReady = isOnline && _twilioService != null;
    print(
      '[SMS] Connectivity=$connectivity, online=$isOnline, twilioReady=$twilioReady',
    );

    final priorityContact = contacts.firstWhere(
      (c) => c.isPrimary,
      orElse: () => contacts.first,
    );

    final offlineRecipients = [
      priorityContact.phone,
    ].where((p) => p.isNotEmpty).toList();
    final onlineRecipients = contacts
        .map((c) => c.phone)
        .where((p) => p.isNotEmpty)
        .toList();
    final recipients = isOnline ? onlineRecipients : offlineRecipients;
    if (recipients.isEmpty) return const SMSResult(sent: [], failed: []);

    final isTest = (event.note ?? '').toUpperCase().contains('TEST');
    final body = _buildAlertMessage(event: event, isTest: isTest);

    try {
      SMSResult result;

      if (twilioReady) {
        print(
          '[SMS] Attempting Twilio send to ${recipients.length} recipient(s)',
        );
        result = await _twilioService!.sendBulk(
          recipients: recipients,
          body: body,
          openComposerOnFail: true,
        );
      } else {
        print(
          '[SMS] Using device SMS path (telephony + composer) for ${recipients.length} recipient(s)',
        );
        result = await _smsService.sendBulk(
          recipients: recipients,
          body: body,
          openComposerOnFail: true,
          composerOnly: !isOnline,
        );
      }

      print(
        '[SMS] Send result: sent=${result.sent.length}, failed=${result.failed.length}',
      );

      if (mounted) {
        if (result.failed.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('SMS sent to ${result.sent.length} contact(s)'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          final sentCount = result.sent.length;
          final failedCount = result.failed.length;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Auto-SMS sent to $sentCount; composer opened for $failedCount',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      return result;
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
      return const SMSResult(sent: [], failed: []);
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
      final allowed = await PermissionService.requestPhonePermission();
      if (!allowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Call permission denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final success = await FlutterPhoneDirectCaller.callNumber(phoneNumber);
      if (success != true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Cannot make call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Capture a short video clip for evidence; returns local file path or null.
  Future<String?> _collectEvidencePath() async {
    final cameraAllowed =
        await PermissionService.isCameraPermissionGranted() ||
        await PermissionService.requestCameraPermission();
    final micAllowed =
        await PermissionService.isMicrophonePermissionGranted() ||
        await PermissionService.requestMicrophonePermission();

    if (!cameraAllowed || !micAllowed) {
      print('[Evidence] Camera/mic permission denied');
      return null;
    }

    final path = await _videoEvidenceService.recordShortVideo(
      duration: const Duration(seconds: 10),
    );

    if (path == null || path.isEmpty) {
      print('[Evidence] Recording failed');
    } else {
      print('[Evidence] Recorded to $path');
    }
    return path;
  }

  Future<void> _triggerTestSOS() async {
    // Quick SMS-only test: reuse contact book, skip recording/cooldown.
    final contacts = await _contactRepository.getAllContacts();
    if (contacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No contacts saved. Add contacts to test SMS.'),
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

    final testEvent = SOSEvent(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      gpsCoordinates: null,
      contactsNotified: contacts.map((c) => c.name).toList(),
      contactsPhones: recipients,
      status: 'pending',
      evidencePath: null,
      note: 'TEST SOS',
    );

    final result = await _sendSmsAlerts(testEvent, contacts);
    final savedEvent = testEvent.copyWith(
      status: result.sent.isNotEmpty ? 'sent' : 'failed',
      sentPhones: result.sent,
      failedPhones: result.failed,
    );

    if (mounted) {
      await context.read<BlackBoxNotifier>().addEvent(savedEvent);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.sent.isNotEmpty
                ? 'Test alert sent; composer may open if auto-send blocked.'
                : 'Test alert failed; composer opened for manual send.',
          ),
          backgroundColor: result.sent.isNotEmpty
              ? Colors.green
              : Colors.orange,
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
