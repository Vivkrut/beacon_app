import 'package:beacon/core/models/sos_event.dart';
import 'package:beacon/core/services/database_service.dart';
import 'package:sqflite/sqflite.dart';

class BlackBoxRepository {
  static const String tableName = 'sos_events';
  final DatabaseService _databaseService = DatabaseService();

  Future<Database> get database async {
    return _databaseService.database;
  }

  /// Add a new SOS event to the BlackBox
  Future<void> addEvent(SOSEvent event) async {
    final db = await database;
    try {
      print('[BlackBox Repository] Adding event: ${event.id}');
      print('[BlackBox Repository] Event data: ${event.toMap()}');
      await db.insert(tableName, {
        ...event.toMap(),
        'createdAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      print('[BlackBox Repository] Event inserted successfully');
    } catch (e) {
      print('[BlackBox Repository] Error adding event: $e');
      throw Exception('Failed to add SOS event: $e');
    }
  }

  /// Get all SOS events (sorted by timestamp, newest first)
  Future<List<SOSEvent>> getAllEvents() async {
    final db = await database;
    try {
      print('[BlackBox Repository] Querying all events from $tableName');
      final maps = await db.query(tableName, orderBy: 'timestamp DESC');
      print('[BlackBox Repository] Found ${maps.length} events');

      if (maps.isNotEmpty) {
        print('[BlackBox Repository] First event: ${maps.first}');
      }

      if (maps.isEmpty) return [];
      return maps.map((map) => SOSEvent.fromMap(map)).toList();
    } catch (e) {
      print('[BlackBox Repository] Error loading events: $e');
      throw Exception('Failed to load SOS events: $e');
    }
  }

  /// Get a specific SOS event by ID
  Future<SOSEvent?> getEvent(String id) async {
    final db = await database;
    try {
      final maps = await db.query(tableName, where: 'id = ?', whereArgs: [id]);

      if (maps.isEmpty) return null;
      return SOSEvent.fromMap(maps.first);
    } catch (e) {
      throw Exception('Failed to get SOS event: $e');
    }
  }

  /// Update an existing SOS event
  Future<void> updateEvent(SOSEvent event) async {
    final db = await database;
    try {
      await db.update(
        tableName,
        event.toMap(),
        where: 'id = ?',
        whereArgs: [event.id],
      );
    } catch (e) {
      throw Exception('Failed to update SOS event: $e');
    }
  }

  /// Delete a specific SOS event
  Future<void> deleteEvent(String id) async {
    final db = await database;
    try {
      await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Failed to delete SOS event: $e');
    }
  }

  /// Clear all SOS events (BlackBox purge)
  Future<void> clearAllEvents() async {
    final db = await database;
    try {
      await db.delete(tableName);
    } catch (e) {
      throw Exception('Failed to clear SOS events: $e');
    }
  }

  /// Get total count of SOS events
  Future<int> getEventCount() async {
    final db = await database;
    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName',
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      throw Exception('Failed to count SOS events: $e');
    }
  }

  /// Get events for a specific date
  Future<List<SOSEvent>> getEventsByDate(DateTime date) async {
    final db = await database;
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final maps = await db.query(
        tableName,
        where: 'timestamp >= ? AND timestamp < ?',
        whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
        orderBy: 'timestamp DESC',
      );

      if (maps.isEmpty) return [];
      return maps.map((map) => SOSEvent.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to get events by date: $e');
    }
  }

  /// Get recent events (last N events)
  Future<List<SOSEvent>> getRecentEvents(int limit) async {
    final db = await database;
    try {
      final maps = await db.query(
        tableName,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      if (maps.isEmpty) return [];
      return maps.map((map) => SOSEvent.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to get recent events: $e');
    }
  }
}
