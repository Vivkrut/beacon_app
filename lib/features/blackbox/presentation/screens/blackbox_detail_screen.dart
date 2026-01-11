import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/services.dart';
import 'package:beacon/core/models/sos_event.dart';
import 'package:beacon/features/blackbox/presentation/notifiers/blackbox_notifier.dart';

class BlackBoxDetailScreen extends StatelessWidget {
  final SOSEvent event;

  const BlackBoxDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormatter = DateFormat('h:mm:ss a');
    final formattedDate = dateFormatter.format(event.timestamp);
    final formattedTime = timeFormatter.format(event.timestamp);
    final statusLabel = BlackBoxNotifier.getStatusLabel(event.status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        centerTitle: true,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: _getStatusColor(event.status),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildStatusIcon(event.status, 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Event Status',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (event.note == 'TEST SOS')
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'TEST',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            statusLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Event ID Section
            Text(
              'Event Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Event ID', event.id, Icons.fingerprint),
            const Divider(height: 16),

            // Timestamp Section
            _buildDetailRow('Date', formattedDate, Icons.calendar_today),
            const SizedBox(height: 12),
            _buildDetailRow('Time', formattedTime, Icons.access_time),
            const SizedBox(height: 24),

            // GPS Section
            if (event.gpsCoordinates != null) ...[
              Text('Location', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GPS Coordinates',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              event.gpsCoordinates!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Contacts Notified Section
            Text(
              'Contacts Notified',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (event.contactsNotified.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'No contacts notified',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: event.contactsNotified.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final contact = event.contactsNotified[index];
                  final phone = index < event.contactsPhones.length
                      ? event.contactsPhones[index]
                      : null;
                  final status = _contactDeliveryStatus(event, phone);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: status.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              status.icon,
                              color: status.color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Contact ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: status.color.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        status.label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: status.color,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                SelectableText(
                                  contact,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                if (phone != null && phone.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  SelectableText(
                                    phone,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // Media Section
            if (event.videoPath != null ||
                event.audioPath != null ||
                (event.evidencePath?.isNotEmpty ?? false)) ...[
              Text('Evidence', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (event.videoPath != null)
                _buildMediaItem(
                  context,
                  'Video Recording',
                  event.videoPath!,
                  Icons.videocam,
                  Colors.blue,
                ),
              if (event.audioPath != null)
                _buildMediaItem(
                  context,
                  'Audio Recording',
                  event.audioPath!,
                  Icons.mic,
                  Colors.purple,
                ),
              if (event.evidencePath != null && event.evidencePath!.isNotEmpty)
                _buildMediaItem(
                  context,
                  'Evidence File',
                  event.evidencePath!,
                  Icons.attachment,
                  Colors.orange,
                ),
              const SizedBox(height: 24),
            ],

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy Event ID'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: event.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Event ID copied to clipboard'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share Event'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share feature coming soon')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openMedia(BuildContext context, String path) async {
    if (path.isEmpty) return;

    final file = File(path);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evidence file not found on device')),
      );
      return;
    }

    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open file: ${result.message}')),
      );
    }
  }

  Widget _buildMediaItem(
    BuildContext context,
    String label,
    String path,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 28),
        title: Text(label),
        subtitle: Text(
          path,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _openMedia(context, path),
      ),
    );
  }

  _ContactStatus _contactDeliveryStatus(SOSEvent event, String? phone) {
    if (phone != null && phone.isNotEmpty) {
      if (event.sentPhones.contains(phone)) {
        return _ContactStatus('Sent', Colors.green, Icons.check_circle);
      }
      if (event.failedPhones.contains(phone)) {
        return _ContactStatus('Failed', Colors.red, Icons.cancel);
      }
    }
    return _ContactStatus('Unknown', Colors.grey, Icons.help_outline);
  }

  Widget _buildStatusIcon(String status, double size) {
    IconData icon;
    Color color;

    switch (status.toLowerCase()) {
      case 'pending':
        icon = Icons.hourglass_top;
        color = Colors.orange;
        break;
      case 'sent':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'failed':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case 'cancelled':
        icon = Icons.block;
        color = Colors.grey;
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: size);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange.withOpacity(0.15);
      case 'sent':
        return Colors.green.withOpacity(0.15);
      case 'failed':
        return Colors.red.withOpacity(0.15);
      case 'cancelled':
        return Colors.grey.withOpacity(0.15);
      default:
        return Colors.grey.withOpacity(0.15);
    }
  }
}

class _ContactStatus {
  final String label;
  final Color color;
  final IconData icon;
  _ContactStatus(this.label, this.color, this.icon);
}
