import 'package:permission_handler/permission_handler.dart';

/// Service for managing runtime permissions
class PermissionService {
  /// Request location permission
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Request SMS permission
  static Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Request camera permission
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request phone/call permission
  static Future<bool> requestPhonePermission() async {
    final status = await Permission.phone.request();
    return status.isGranted;
  }

  /// Request contacts permission
  static Future<bool> requestContactsPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  /// Check if location permission is granted
  static Future<bool> isLocationPermissionGranted() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Check if SMS permission is granted
  static Future<bool> isSmsPermissionGranted() async {
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  /// Check if camera permission is granted
  static Future<bool> isCameraPermissionGranted() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Check if microphone permission is granted
  static Future<bool> isMicrophonePermissionGranted() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Check if phone permission is granted
  static Future<bool> isPhonePermissionGranted() async {
    final status = await Permission.phone.status;
    return status.isGranted;
  }

  /// Request all critical permissions
  static Future<bool> requestAllPermissions() async {
    final location = await requestLocationPermission();
    final sms = await requestSmsPermission();
    final camera = await requestCameraPermission();
    final microphone = await requestMicrophonePermission();
    final phone = await requestPhonePermission();

    return location && sms && camera && microphone && phone;
  }
}
