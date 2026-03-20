// ============================================================================
// lib/shared/services/offline/local_database_service.dart
// Local SQLite database for offline product storage
// ============================================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/product/offline_product_model.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  static Database? _database;

  factory LocalDatabaseService() {
    return _instance;
  }

  LocalDatabaseService._internal();

  /// Get or initialize the database
  Future<Database> get database async {
    _database ??= await _initializeDatabase();
    return _database!;
  }

  /// Initialize the database and create tables
  Future<Database> _initializeDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'agridirect_local.db');

    return openDatabase(path, version: 1, onCreate: _createTables);
  }

  /// Create all necessary tables
  Future<void> _createTables(Database db, int version) async {
    // Offline Products Table
    await db.execute('''
      CREATE TABLE offline_products (
        local_id TEXT PRIMARY KEY,
        product_id TEXT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        description TEXT,
        image_url TEXT,
        image_base64 TEXT,
        harvest_days INTEGER,
        is_preorder INTEGER DEFAULT 0,
        quantity REAL NOT NULL,
        farmer_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        unit_id TEXT NOT NULL,
        tag_ids TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        sync_error TEXT,
        sync_attempts INTEGER DEFAULT 0
      )
    ''');

    // Index for faster queries
    await db.execute('''
      CREATE INDEX idx_farmer_id ON offline_products(farmer_id)
    ''');
    await db.execute('''
      CREATE INDEX idx_sync_status ON offline_products(sync_status)
    ''');
  }

  // ============================================================================
  // OFFLINE PRODUCT OPERATIONS
  // ============================================================================

  /// Insert a new offline product
  Future<int> insertOfflineProduct(OfflineProduct product) async {
    final db = await database;
    return db.insert(
      'offline_products',
      product.toDBJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all offline products for a farmer
  Future<List<OfflineProduct>> getFarmerOfflineProducts(String farmerId) async {
    final db = await database;
    final results = await db.query(
      'offline_products',
      where: 'farmer_id = ?',
      whereArgs: [farmerId],
      orderBy: 'created_at DESC',
    );

    return results.map((json) => OfflineProduct.fromDBJson(json)).toList();
  }

  /// Get pending products (not synced)
  Future<List<OfflineProduct>> getPendingProducts() async {
    final db = await database;
    final results = await db.query(
      'offline_products',
      where: 'sync_status IN (?, ?)',
      whereArgs: ['pending', 'failed'],
      orderBy: 'created_at ASC',
    );

    return results.map((json) => OfflineProduct.fromDBJson(json)).toList();
  }

  /// Get single offline product
  Future<OfflineProduct?> getOfflineProductById(String localId) async {
    final db = await database;
    final results = await db.query(
      'offline_products',
      where: 'local_id = ?',
      whereArgs: [localId],
    );

    if (results.isEmpty) return null;
    return OfflineProduct.fromDBJson(results.first);
  }

  /// Update offline product
  Future<int> updateOfflineProduct(OfflineProduct product) async {
    final db = await database;
    return db.update(
      'offline_products',
      product.toDBJson(),
      where: 'local_id = ?',
      whereArgs: [product.localId],
    );
  }

  /// Update sync status
  Future<int> updateSyncStatus(
    String localId, {
    required SyncStatus status,
    String? productId,
    String? error,
  }) async {
    final db = await database;
    final update = {
      'sync_status': status.name,
      'updated_at': DateTime.now().toIso8601String(),
      if (error != null) 'sync_error': error,
      if (productId != null) 'product_id': productId,
      if (status == SyncStatus.synced || status == SyncStatus.failed)
        'sync_attempts':
            (await getOfflineProductById(localId))!.syncAttempts + 1,
    };

    return db.update(
      'offline_products',
      update,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Delete offline product
  Future<int> deleteOfflineProduct(String localId) async {
    final db = await database;
    return db.delete(
      'offline_products',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Delete all synced products (cleanup)
  Future<int> deleteSyncedProducts() async {
    final db = await database;
    return db.delete(
      'offline_products',
      where: 'sync_status = ?',
      whereArgs: ['synced'],
    );
  }

  /// Get sync statistics
  Future<Map<String, int>> getSyncStats() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT sync_status, COUNT(*) as count
      FROM offline_products
      GROUP BY sync_status
    ''');

    final stats = <String, int>{};
    for (final row in results) {
      stats[row['sync_status'] as String] = row['count'] as int;
    }

    return stats;
  }

  /// Close database connection
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
