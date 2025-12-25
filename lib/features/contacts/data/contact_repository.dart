import 'package:beacon/core/models/contact.dart';
import 'package:beacon/core/services/database_service.dart';
import 'package:sqflite/sqflite.dart';

class ContactRepository {
  static const String tableName = 'contacts';
  final DatabaseService _databaseService = DatabaseService();

  Future<Database> get database async {
    return _databaseService.database;
  }

  Future<void> addContact(Contact contact) async {
    final db = await database;
    try {
      await db.insert(
        tableName,
        contact.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw Exception('Failed to add contact: $e');
    }
  }

  Future<Contact?> getContact(String id) async {
    final db = await database;
    final maps = await db.query(tableName, where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return Contact.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Contact>> getAllContacts() async {
    final db = await database;
    try {
      print('[ContactRepository] Querying all contacts from $tableName');
      final maps = await db.query(
        tableName,
        orderBy: 'isPrimary DESC, createdAt DESC',
      );
      print('[ContactRepository] Found ${maps.length} contacts');
      return maps.map((map) => Contact.fromMap(map)).toList();
    } catch (e) {
      print('[ContactRepository] Error loading contacts: $e');
      throw Exception('Failed to load contacts: $e');
    }
  }

  Future<Contact?> getPrimaryContact() async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'isPrimary = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Contact.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateContact(Contact contact) async {
    final db = await database;
    try {
      await db.update(
        tableName,
        contact.toMap(),
        where: 'id = ?',
        whereArgs: [contact.id],
      );
    } catch (e) {
      throw Exception('Failed to update contact: $e');
    }
  }

  Future<void> deleteContact(String id) async {
    final db = await database;
    try {
      await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Failed to delete contact: $e');
    }
  }

  Future<void> setPrimaryContact(String id) async {
    final db = await database;
    try {
      // Reset all primary flags
      await db.update(tableName, {'isPrimary': 0});
      // Set new primary
      await db.update(
        tableName,
        {'isPrimary': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Failed to set primary contact: $e');
    }
  }

  Future<int> getContactCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearAllContacts() async {
    final db = await database;
    try {
      await db.delete(tableName);
    } catch (e) {
      throw Exception('Failed to clear contacts: $e');
    }
  }
}
