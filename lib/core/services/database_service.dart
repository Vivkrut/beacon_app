import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Singleton database service to manage a single shared database instance
/// This ensures both BlackBoxRepository and ContactRepository use the same connection
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      print('[DatabaseService] Database is open, returning cached instance');
      return _database!;
    }

    print('[DatabaseService] Database is closed or null, reinitializing');
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String dbPath = join(await getDatabasesPath(), 'beacon.db');
    print('[DatabaseService] _initDatabase starting, database path: $dbPath');

    // Pre-check: detect old database and delete explicitly
    try {
      final testDb = await openDatabase(dbPath);
      final version = await testDb.getVersion();
      print('[DatabaseService] Existing database version: $version');

      if (version < 2) {
        print('[DatabaseService] Old version detected, deleting old database');
        await testDb.close(); // Close before deleting
        await deleteDatabase(dbPath);
        print('[DatabaseService] Old database deleted');
      } else {
        await testDb.close(); // Close test db
      }
    } catch (e) {
      print('[DatabaseService] Could not check version (new db): $e');
    }

    return openDatabase(
      dbPath,
      version: 4,
      onCreate: (db, version) async {
        print('[DatabaseService] onCreate called with version: $version');
        try {
          // Create SOS Events table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sos_events (
              id TEXT PRIMARY KEY,
              timestamp TEXT NOT NULL,
              gpsCoordinates TEXT,
              contactsNotified TEXT NOT NULL,
              contactsPhones TEXT,
              sentPhones TEXT,
              failedPhones TEXT,
              status TEXT NOT NULL,
              videoPath TEXT,
              audioPath TEXT,
              evidencePath TEXT,
              note TEXT,
              createdAt TEXT NOT NULL
            )
          ''');
          print('[DatabaseService] sos_events table created successfully');

          // Create Contacts table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS contacts (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              phone TEXT NOT NULL UNIQUE,
              email TEXT,
              isPrimary INTEGER NOT NULL DEFAULT 0,
              createdAt TEXT NOT NULL
            )
          ''');
          print('[DatabaseService] contacts table created successfully');

          print(
            '[DatabaseService] All tables created successfully in onCreate',
          );
        } catch (e) {
          print('[DatabaseService] Error creating tables in onCreate: $e');
          rethrow;
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print(
          '[DatabaseService] onUpgrade called: oldVersion=$oldVersion, newVersion=$newVersion',
        );
        try {
          // Ensure both tables exist
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sos_events (
              id TEXT PRIMARY KEY,
              timestamp TEXT NOT NULL,
              gpsCoordinates TEXT,
              contactsNotified TEXT NOT NULL,
              contactsPhones TEXT,
              sentPhones TEXT,
              failedPhones TEXT,
              status TEXT NOT NULL,
              videoPath TEXT,
              audioPath TEXT,
              evidencePath TEXT,
              note TEXT,
              createdAt TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS contacts (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              phone TEXT NOT NULL UNIQUE,
              email TEXT,
              isPrimary INTEGER NOT NULL DEFAULT 0,
              createdAt TEXT NOT NULL
            )
          ''');

          print('[DatabaseService] All tables created/verified in onUpgrade');
        } catch (e) {
          print('[DatabaseService] Error in onUpgrade: $e');
          rethrow;
        }
      },
      onOpen: (db) async {
        print('[DatabaseService] onOpen called');
        try {
          // Verify both tables exist
          final sosResult = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='sos_events'",
          );
          final contactsResult = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='contacts'",
          );

          if (sosResult.isEmpty) {
            print('[DatabaseService] sos_events table missing, creating it');
            await db.execute('''
              CREATE TABLE sos_events (
                id TEXT PRIMARY KEY,
                timestamp TEXT NOT NULL,
                gpsCoordinates TEXT,
                contactsNotified TEXT NOT NULL,
                contactsPhones TEXT,
                status TEXT NOT NULL,
                videoPath TEXT,
                audioPath TEXT,
                evidencePath TEXT,
                note TEXT,
                createdAt TEXT NOT NULL
              )
            ''');
          } else {
            print('[DatabaseService] sos_events table verified to exist');
            // Ensure new columns exist (best-effort, avoid duplicate warnings)
            final columns = await db.rawQuery(
              "PRAGMA table_info('sos_events')",
            );
            final columnNames = columns
                .map((row) => (row['name'] as String).toLowerCase())
                .toSet();

            if (!columnNames.contains('evidencepath')) {
              await db.execute(
                'ALTER TABLE sos_events ADD COLUMN evidencePath TEXT',
              );
            }
            if (!columnNames.contains('contactsphones')) {
              await db.execute(
                'ALTER TABLE sos_events ADD COLUMN contactsPhones TEXT',
              );
            }
            if (!columnNames.contains('sentphones')) {
              await db.execute(
                'ALTER TABLE sos_events ADD COLUMN sentPhones TEXT',
              );
            }
            if (!columnNames.contains('failedphones')) {
              await db.execute(
                'ALTER TABLE sos_events ADD COLUMN failedPhones TEXT',
              );
            }
          }

          if (contactsResult.isEmpty) {
            print('[DatabaseService] contacts table missing, creating it');
            await db.execute('''
              CREATE TABLE contacts (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                phone TEXT NOT NULL UNIQUE,
                email TEXT,
                isPrimary INTEGER NOT NULL DEFAULT 0,
                createdAt TEXT NOT NULL
              )
            ''');
          } else {
            print('[DatabaseService] contacts table verified to exist');
          }
        } catch (e) {
          print('[DatabaseService] Error checking tables in onOpen: $e');
        }
      },
    );
  }

  /// Check if database is open
  bool get isOpen => _database?.isOpen ?? false;

  /// Close the database
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('[DatabaseService] Database closed');
    }
  }
}
