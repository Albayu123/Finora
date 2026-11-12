import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/transaction_model.dart';

/// Pengelola basis data SQLite lokal sebagai sumber data utama aplikasi.
class DatabaseHelper {
  DatabaseHelper({this._factoryOverride, this._dbPathOverride});

  static final DatabaseHelper instance = DatabaseHelper();
  static const String _dbName = 'finora_transactions.db';
  static const String tableName = 'transactions';

  final DatabaseFactory? _factoryOverride;
  final String? _dbPathOverride;
  Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final factory = _resolveFactory();
    final dbPath = await _resolvePath(factory);

    return factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $tableName (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              amount REAL NOT NULL,
              type TEXT NOT NULL,
              category TEXT NOT NULL,
              note TEXT NOT NULL,
              created_at TEXT NOT NULL,
              is_synced INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
      ),
    );
  }

  DatabaseFactory _resolveFactory() {
    if (_factoryOverride != null) {
      return _factoryOverride;
    }
    if (kIsWeb) {
      return databaseFactoryFfiWeb;
    }
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  Future<String> _resolvePath(DatabaseFactory factory) async {
    if (_dbPathOverride != null) {
      return _dbPathOverride;
    }
    if (kIsWeb) {
      return _dbName;
    }
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final supportDir = await getApplicationSupportDirectory();
      return p.join(supportDir.path, _dbName);
    }
    final dbDir = await factory.getDatabasesPath();
    return p.join(dbDir, _dbName);
  }

  Future<void> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    await db.insert(
      tableName,
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TransactionModel>> getTransactions() async {
    final db = await database;
    final rows = await db.query(tableName, orderBy: 'created_at DESC');
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<List<TransactionModel>> getUnsyncedTransactions() async {
    final db = await database;
    final rows = await db.query(
      tableName,
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    final db = await database;
    await db.update(
      tableName,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> markAsSynced(String id) async {
    final db = await database;
    await db.update(
      tableName,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
