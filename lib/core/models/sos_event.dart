/// SOS Event model for BlackBox storage
class SOSEvent {
  final String id;
  final DateTime timestamp;
  final String? gpsCoordinates;
  final List<String> contactsNotified;
  final List<String> contactsPhones;
  final List<String> sentPhones;
  final List<String> failedPhones;
  final String status; // 'pending', 'sent', 'failed', 'cancelled'
  final String? videoPath;
  final String? audioPath;
  final String? evidencePath; // placeholder for future file/evidence bundle
  final String? note; // 'TEST SOS' or null for real emergencies

  SOSEvent({
    required this.id,
    required this.timestamp,
    this.gpsCoordinates,
    this.contactsNotified = const [],
    this.contactsPhones = const [],
    this.sentPhones = const [],
    this.failedPhones = const [],
    this.status = 'pending',
    this.videoPath,
    this.audioPath,
    this.evidencePath,
    this.note,
  });

  /// Convert SOSEvent to Map for SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'gpsCoordinates': gpsCoordinates,
      'contactsNotified': contactsNotified.join(','),
      'contactsPhones': contactsPhones.join(','),
      'sentPhones': sentPhones.join(','),
      'failedPhones': failedPhones.join(','),
      'status': status,
      'videoPath': videoPath,
      'audioPath': audioPath,
      'evidencePath': evidencePath,
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
      contactsPhones: (map['contactsPhones'] as String?)?.split(',') ?? [],
      sentPhones: (map['sentPhones'] as String?)?.split(',') ?? [],
      failedPhones: (map['failedPhones'] as String?)?.split(',') ?? [],
      status: map['status'] as String,
      videoPath: map['videoPath'] as String?,
      audioPath: map['audioPath'] as String?,
      evidencePath: map['evidencePath'] as String?,
      note: map['note'] as String?,
    );
  }

  /// Create a copy with modified fields
  SOSEvent copyWith({
    String? id,
    DateTime? timestamp,
    String? gpsCoordinates,
    List<String>? contactsNotified,
    List<String>? contactsPhones,
    List<String>? sentPhones,
    List<String>? failedPhones,
    String? status,
    String? videoPath,
    String? audioPath,
    String? evidencePath,
    String? note,
  }) {
    return SOSEvent(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      gpsCoordinates: gpsCoordinates ?? this.gpsCoordinates,
      contactsNotified: contactsNotified ?? this.contactsNotified,
      contactsPhones: contactsPhones ?? this.contactsPhones,
      sentPhones: sentPhones ?? this.sentPhones,
      failedPhones: failedPhones ?? this.failedPhones,
      status: status ?? this.status,
      videoPath: videoPath ?? this.videoPath,
      audioPath: audioPath ?? this.audioPath,
      evidencePath: evidencePath ?? this.evidencePath,
      note: note ?? this.note,
    );
  }

  @override
  String toString() =>
      'SOSEvent(id: $id, timestamp: $timestamp, status: $status)';
}
