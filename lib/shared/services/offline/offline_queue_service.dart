import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../models/offline_product_queue.dart';

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  static const String boxName = 'offline_products';
  late Box<OfflineProductQueue> _box;
  bool _initialized = false;

  Future<void> init() async {
    if (!_initialized) {
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(OfflineProductQueueAdapter());
      }
      if (!Hive.isBoxOpen(boxName)) {
        _box = await Hive.openBox<OfflineProductQueue>(boxName);
      } else {
        _box = Hive.box<OfflineProductQueue>(boxName);
      }
      _initialized = true;
    }
  }

  Future<OfflineProductQueue> addProductToQueue({
    required String farmerId,
    required String name,
    required double price,
    required String description,
    required String categoryId,
    required String unitId,
    String? imageUrl,
    required int harvestDays,
    required bool isPreorder,
    required int availableQuantity,
    required List<String> localImagePaths,
  }) async {
    final product = OfflineProductQueue(
      id: const Uuid().v4(),
      farmerId: farmerId,
      name: name,
      price: price,
      description: description,
      categoryId: int.tryParse(categoryId) ?? 0,
      unitId: int.tryParse(unitId) ?? 0,
      categoryIdRef: categoryId,
      unitIdRef: unitId,
      imageUrl: imageUrl,
      harvestDays: harvestDays,
      isPreorder: isPreorder,
      availableQuantity: availableQuantity,
      localImagePaths: localImagePaths,
      createdAt: DateTime.now(),
      synced: false,
    );
    await _box.add(product);
    return product;
  }

  List<OfflineProductQueue> getPendingProducts() {
    return _box.values.where((p) => !p.synced).toList();
  }

  List<OfflineProductQueue> getAllProducts() {
    return _box.values.toList();
  }

  Future<void> markAsSynced(String productId) async {
    final index = _box.values.toList().indexWhere((p) => p.id == productId);
    if (index != -1) {
      final product = _box.getAt(index);
      if (product != null) {
        product.synced = true;
        product.syncError = null;
        await product.save();
      }
    }
  }

  Future<void> setSyncError(String productId, String? error) async {
    final index = _box.values.toList().indexWhere((p) => p.id == productId);
    if (index != -1) {
      final product = _box.getAt(index);
      if (product != null) {
        product.syncError = error;
        await product.save();
      }
    }
  }

  Future<bool> removeProduct(String productId) async {
    final cleanId = productId.trim();
    debugPrint('🗑️ Attempting to remove product from offline queue: "$cleanId"');
    
    try {
      final products = _box.values.toList();
      debugPrint('📦 Current items in queue: ${products.map((p) => p.id).toList()}');
      
      final product = _box.values.firstWhere(
        (p) => p.id.trim() == cleanId,
        orElse: () => throw Exception('Product not found in queue'),
      );
      
      await product.delete();
      debugPrint('✅ Successfully removed product from offline queue');
      return true;
    } catch (e) {
      debugPrint('❌ Error removing product from queue: $e');
      return false;
    }
  }

  Future<void> clearAllSyncedProducts() async {
    final List<int> toDelete = [];
    for (int i = 0; i < _box.length; i++) {
      final product = _box.getAt(i);
      if (product != null && product.synced) {
        toDelete.add(i);
      }
    }
    // Delete in reverse order to maintain indices
    for (final i in toDelete.reversed) {
      await _box.deleteAt(i);
    }
  }

  Future<void> close() async {
    await _box.close();
  }
}
