import 'package:flutter/services.dart';

class SmsRoleService {
  static const MethodChannel _channel = MethodChannel('com.beacon/sms_role');

  static Future<bool> isDefaultSmsApp() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDefaultSmsApp');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestDefaultRole() async {
    try {
      await _channel.invokeMethod('requestDefaultSmsApp');
    } catch (_) {
      // swallow; UI prompt follows on Android side
    }
  }
}
