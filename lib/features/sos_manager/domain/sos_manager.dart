import 'package:geolocator/geolocator.dart';
import 'package:beacon/core/models/sos_event.dart';
import 'package:beacon/core/models/contact.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SOSManager {
  static final SOSManager _instance = SOSManager._internal();

  DateTime? _lastSOSTime;
  static const int _sosCountdownSeconds = 10;
  static const int _sosRateLimitMinutes = 2;
  static const String _lastSOSTimeKey = 'last_sos_time';

  factory SOSManager() {
    return _instance;
  }

  SOSManager._internal() {
    _loadLastSOSTime();
  }

  /// Load last SOS time from SharedPreferences on initialization
  Future<void> _loadLastSOSTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTimeStr = prefs.getString(_lastSOSTimeKey);
      if (lastTimeStr != null) {
        _lastSOSTime = DateTime.parse(lastTimeStr);
      }
    } catch (e) {
      print('Error loading last SOS time: $e');
    }
  }

  // Check if enough time has passed since last SOS
  bool canTriggerSOS() {
    if (_lastSOSTime == null) return true;

    final now = DateTime.now();
    final diff = now.difference(_lastSOSTime!).inMinutes;
    return diff >= _sosRateLimitMinutes;
  }

  // Get seconds until next SOS is allowed
  int getSecondsUntilNextSOS() {
    if (_lastSOSTime == null) return 0;

    final now = DateTime.now();
    final nextAllowed = _lastSOSTime!.add(
      Duration(minutes: _sosRateLimitMinutes),
    );

    if (now.isAfter(nextAllowed)) return 0;

    return nextAllowed.difference(now).inSeconds;
  }

  // Record SOS trigger time for rate limiting (persist to SharedPreferences)
  Future<void> recordSOSTime() async {
    _lastSOSTime = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSOSTimeKey, _lastSOSTime!.toIso8601String());
    } catch (e) {
      print('Error saving SOS time: $e');
    }
  }

  // Get current GPS location
  Future<String?> getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final newPermission = await Geolocator.requestPermission();
        if (newPermission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final position =
          await Geolocator.getCurrentPosition(
            timeLimit: const Duration(seconds: 10),
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => Future.error('GPS timeout'),
          );

      return '${position.latitude.toStringAsFixed(4)}°, ${position.longitude.toStringAsFixed(4)}°';
    } catch (e) {
      return null; // GPS unavailable
    }
  }

  // Generate SOS event with all data
  Future<SOSEvent> generateSOSEvent({
    required List<Contact> contacts,
    bool isTestMode = false,
  }) async {
    final gpsLocation = await getCurrentLocation();

    final contactNames = contacts.map((c) => c.name).toList();

    return SOSEvent(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      gpsCoordinates: gpsLocation ?? 'Unable to get GPS',
      contactsNotified: contactNames,
      status: 'triggered',
      note: isTestMode ? 'TEST SOS' : 'ACTUAL SOS',
    );
  }

  // Get countdown seconds
  int get countdownSeconds => _sosCountdownSeconds;
}
