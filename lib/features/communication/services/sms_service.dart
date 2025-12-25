import 'package:url_launcher/url_launcher.dart';

/// Lightweight SMS sender using platform SMS intents via url_launcher.
/// Opens the native SMS app prefilled; relies on user/device defaults.
class SMSService {
  /// Send a message to multiple recipients sequentially.
  Future<void> sendBulk({
    required List<String> recipients,
    required String body,
  }) async {
    if (recipients.isEmpty) return;

    for (final phone in recipients) {
      final sanitized = phone.trim();
      if (sanitized.isEmpty) continue;
      final uri = Uri(
        scheme: 'sms',
        path: sanitized,
        queryParameters: {'body': body},
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }
}
