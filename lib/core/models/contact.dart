/// Contact model for emergency contacts
class Contact {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final bool isPrimary;
  final DateTime createdAt;

  Contact({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.isPrimary = false,
    required this.createdAt,
  });

  /// Convert Contact to Map for SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'isPrimary': isPrimary ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create Contact from Map (from SQLite)
  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String?,
      isPrimary: (map['isPrimary'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// Create a copy with modified fields
  Contact copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    bool? isPrimary,
    DateTime? createdAt,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Contact(id: $id, name: $name, phone: $phone, isPrimary: $isPrimary)';
}
