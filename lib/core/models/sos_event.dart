/// SOS Event model for BlackBox storage
class SOSEvent {
  final String id;
  final DateTime timestamp;
  final String? gpsCoordinates;
  final List<String> contactsNotified;
  final String status; // 'pending', 'sent', 'failed', 'cancelled'
  final String? videoPath;
  final String? audioPath;
  final String? note; // 'TEST SOS' or null for real emergencies

  SOSEvent({
    required this.id,
    required this.timestamp,
    this.gpsCoordinates,
    this.contactsNotified = const [],
    this.status = 'pending',
    this.videoPath,
    this.audioPath,
    this.note,
  });

  /// Convert SOSEvent to Map for SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'gpsCoordinates': gpsCoordinates,
      'contactsNotified': contactsNotified.join(','),
      'status': status,
      'videoPath': videoPath,
      'audioPath': audioPath,
      'note': note,
    };
  }

  /// Create SOSEvent from Map (from SQLite)
  factory SOSEvent.fromMap(Map<String, dynamic> map) {
    return SOSEvent(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      gpsCoordinates: map['gpsCoordinates'] as String?,
      contactsNotified: (map['contactsNotified'] as String?)?.split(',') ?? [],
      status: map['status'] as String,
      videoPath: map['videoPath'] as String?,
      audioPath: map['audioPath'] as String?,
      note: map['note'] as String?,
    );
  }

  /// Create a copy with modified fields
  SOSEvent copyWith({
    String? id,
    DateTime? timestamp,
    String? gpsCoordinates,
    List<String>? contactsNotified,
    String? status,
    String? videoPath,
    String? audioPath,
    String? note,
  }) {
    return SOSEvent(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      gpsCoordinates: gpsCoordinates ?? this.gpsCoordinates,
      contactsNotified: contactsNotified ?? this.contactsNotified,
      status: status ?? this.status,
      videoPath: videoPath ?? this.videoPath,
      audioPath: audioPath ?? this.audioPath,
      note: note ?? this.note,
    );
  }

  @override
  String toString() =>
      'SOSEvent(id: $id, timestamp: $timestamp, status: $status)';
}
