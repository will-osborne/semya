import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:semya/config/constants.dart';
import 'package:semya/data/datasources/local/secure_storage_service.dart';

class DatabaseHelper {
  DatabaseHelper({required SecureStorageService secureStorageService})
    : _secureStorageService = secureStorageService;

  final SecureStorageService _secureStorageService;

  Database? _database;

  /// Returns the singleton encrypted database instance, opening it on first
  /// call.
  Future<Database> getDatabase() async {
    if (_database != null) {
      return _database!;
    }

    final password = await _secureStorageService.getDbPassword();
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, AppConstants.dbName);

    _database = await openDatabase(
      path,
      password: password,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        type TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages (conversation_id, timestamp)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Drop all Signal Protocol tables and the decrypted_messages cache.
      for (final table in [
        'identity_keys',
        'pre_keys',
        'signed_pre_keys',
        'sessions',
        'sender_keys',
        'decrypted_messages',
        'messages',
      ]) {
        await db.execute('DROP TABLE IF EXISTS $table');
      }
      await db.execute('DROP INDEX IF EXISTS idx_messages_conversation');

      // Recreate the messages table with the new schema.
      await _onCreate(db, newVersion);
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
