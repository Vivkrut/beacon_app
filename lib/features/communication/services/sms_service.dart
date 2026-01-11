import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// SMS sending helper that attempts background send first, then falls back
/// to opening the native composer for any failed numbers (e.g., OEM blocks).
class SMSService {
  final Telephony _telephony = Telephony.instance;

  Future<SMSResult> sendBulk({
    required List<String> recipients,
    required String body,
    bool openComposerOnFail = true,
    bool composerOnly = false,
  }) async {
    // Deduplicate and skip empties to avoid redundant sends
    final uniqueRecipients = recipients
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList();

    if (uniqueRecipients.isEmpty) {
      return const SMSResult(sent: [], failed: []);
    }

    final sent = <String>[];
    final failed = <String>[];

    if (!composerOnly) {
      for (final number in uniqueRecipients) {
        try {
          await _telephony.sendSms(
            to: number,
            message: body,
            statusListener: null,
          );
          // Telephony sendSms may not return a status; treat as requested.
          sent.add(number);
        } catch (_) {
          failed.add(number);
        }
      }
    }

    // On devices blocking background SMS, force composer to ensure user can send.
    if (openComposerOnFail) {
      // If nothing auto-sent, offer composer to all; else only to failed.
      final fallbackList = sent.isEmpty ? uniqueRecipients : failed;
      final recips = fallbackList.join(',');
      // Try smsto first; fall back to sms: if OEM quirks strip recipients.
      final smsto = 'smsto:$recips?body=${Uri.encodeComponent(body)}';
      final sms = 'sms:$recips?body=${Uri.encodeComponent(body)}';

      if (await canLaunchUrlString(smsto)) {
        await launchUrlString(smsto, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrlString(sms)) {
        await launchUrlString(sms, mode: LaunchMode.externalApplication);
      }
    }

    return SMSResult(sent: sent, failed: failed);
  }
}

class SMSResult {
  final List<String> sent;
  final List<String> failed;
  const SMSResult({required this.sent, required this.failed});
}

/// Twilio sender using direct REST API calls. Falls back to composer for any failures.
class TwilioService {
  TwilioService({
    required this.accountSid,
    required this.authToken,
    required this.fromNumber,
  });

  final String accountSid;
  final String authToken;
  final String fromNumber;

  Future<SMSResult> sendBulk({
    required List<String> recipients,
    required String body,
    bool openComposerOnFail = true,
  }) async {
    final uniqueRecipients = recipients
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList();

    if (uniqueRecipients.isEmpty) {
      return const SMSResult(sent: [], failed: []);
    }

    final sent = <String>[];
    final failed = <String>[];

    final uri = Uri.parse(
      'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json',
    );
    final authHeader =
        'Basic ' + base64Encode(utf8.encode('$accountSid:$authToken'));

    for (final to in uniqueRecipients) {
      try {
        // Twilio REST send with per-recipient logging for diagnostics
        // (kept lightweight; avoid printing body).
        print('[Twilio] Sending to $to from $fromNumber');
        final response = await http.post(
          uri,
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {'To': to, 'From': fromNumber, 'Body': body},
        );

        if (response.statusCode == 201) {
          print('[Twilio] Success $to status=${response.statusCode}');
          sent.add(to);
        } else {
          print(
            '[Twilio] Failed $to status=${response.statusCode} body=${response.body}',
          );
          failed.add(to);
        }
      } catch (e) {
        print('[Twilio] Exception sending to $to: $e');
        failed.add(to);
      }
    }

    if (openComposerOnFail) {
      final fallbackList = sent.isEmpty ? uniqueRecipients : failed;
      if (fallbackList.isNotEmpty) {
        final recips = fallbackList.join(',');
        final smsto = 'smsto:$recips?body=${Uri.encodeComponent(body)}';
        final sms = 'sms:$recips?body=${Uri.encodeComponent(body)}';

        if (await canLaunchUrlString(smsto)) {
          await launchUrlString(smsto, mode: LaunchMode.externalApplication);
        } else if (await canLaunchUrlString(sms)) {
          await launchUrlString(sms, mode: LaunchMode.externalApplication);
        }
      }
    }

    return SMSResult(sent: sent, failed: failed);
  }
}
