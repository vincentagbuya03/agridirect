import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../models/cached_product.dart';

/// Service for managing offline product cache (auto-cached and manually saved products)
class OfflineCacheService {
  static const String _boxName = 'cached_products';
  static const int _maxAutoCache = 20; // Auto-cache max 20 products
  late Box<CachedProduct> _box;

  // Singleton instance
  static OfflineCacheService? _instance;

  // Private constructor
  OfflineCacheService._();

  // Factory constructor - returns singleton instance
  factory OfflineCacheService() {
    _instance ??= OfflineCacheService._();
    return _instance!;
  }

  bool get isInitialized {
    try {
      return _box.isOpen;
    } catch (_) {
      return false;
    }
  }

  Future<void> _warmImageCache(String? imageUrl) async {
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty) return;

    try {
      await DefaultCacheManager().downloadFile(url, key: url, force: false);
    } catch (e) {
      debugPrint('⚠️ Unable to pre-cache product image: $e');
    }
  }

  /// Initialize the cache box and register adapter
  Future<void> init() async {
    try {
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(CachedProductAdapter());
      }
      _box = await Hive.openBox<CachedProduct>(_boxName);
      debugPrint('✅ Offline cache service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing offline cache: $e');
      rethrow;
    }
  }

  /// Auto-cache a newly loaded product (keeps last 20)
  Future<void> autoCacheProduct(CachedProduct product) async {
    try {
      await _warmImageCache(product.imageUrl);

      final existing = _box.values.firstWhere(
        (p) => p.id == product.id,
        orElse: () => CachedProduct(id: '', farmerId: '', name: '', price: 0),
      );

      if (existing.id.isEmpty) {
        // New product - add it
        await _box.add(product);

        // Clean up old auto-cached products if exceeding limit
        await _cleanupExcessAutoCache();
      } else if (!existing.isManuallySaved) {
        // Update existing auto-cached product
        final index = _box.values.toList().indexWhere(
          (p) => p.id == existing.id,
        );
        if (index != -1) {
          product.isManuallySaved = false;
          await _box.putAt(index, product);
        }
      }
      // If manually saved, don't update (keep user's saved version)
    } catch (e) {
      debugPrint('❌ Error auto-caching product: $e');
    }
  }

  /// Manually save a product for offline viewing (won't be auto-removed)
  Future<void> manualSaveProduct(CachedProduct product) async {
    try {
      await _warmImageCache(product.imageUrl);

      product.isManuallySaved = true;
      product.cachedAt = DateTime.now();

      final existing = _box.values.firstWhere(
        (p) => p.id == product.id,
        orElse: () => CachedProduct(id: '', farmerId: '', name: '', price: 0),
      );

      if (existing.id.isEmpty) {
        await _box.add(product);
      } else {
        final index = _box.values.toList().indexWhere(
          (p) => p.id == existing.id,
        );
        if (index != -1) {
          await _box.putAt(index, product);
        }
      }
      debugPrint('✅ Product manually saved for offline: ${product.name}');
    } catch (e) {
      debugPrint('❌ Error manually saving product: $e');
    }
  }

  /// Get all cached products (both auto and manually saved)
  List<CachedProduct> getAllCachedProducts() {
    try {
      return _box.values.toList();
    } catch (e) {
      debugPrint('❌ Error getting cached products: $e');
      return [];
    }
  }

  /// Get only manually saved products
  List<CachedProduct> getManuallySavedProducts() {
    try {
      return _box.values.where((p) => p.isManuallySaved).toList();
    } catch (e) {
      debugPrint('❌ Error getting saved products: $e');
      return [];
    }
  }

  /// Get only auto-cached products
  List<CachedProduct> getAutoCachedProducts() {
    try {
      return _box.values.where((p) => !p.isManuallySaved).toList();
    } catch (e) {
      debugPrint('❌ Error getting auto-cached products: $e');
      return [];
    }
  }

  /// Check if a specific product is cached
  bool isProductCached(String productId) {
    try {
      return _box.values.any((p) => p.id == productId);
    } catch (e) {
      debugPrint('❌ Error checking cached status: $e');
      return false;
    }
  }

  /// Check if a product is manually saved
  bool isProductManuallySaved(String productId) {
    try {
      return _box.values.any((p) => p.id == productId && p.isManuallySaved);
    } catch (e) {
      debugPrint('❌ Error checking save status: $e');
      return false;
    }
  }

  /// Remove a cached product
  Future<void> removeCachedProduct(String productId) async {
    try {
      final index = _box.values.toList().indexWhere((p) => p.id == productId);
      if (index != -1) {
        await _box.deleteAt(index);
        debugPrint('✅ Cached product removed: $productId');
      }
    } catch (e) {
      debugPrint('❌ Error removing cached product: $e');
    }
  }

  /// Clear all auto-cached products (keep manually saved ones)
  Future<void> clearAutoCachedProducts() async {
    try {
      final toDelete = <int>[];
      for (int i = 0; i < _box.length; i++) {
        if (!_box.getAt(i)!.isManuallySaved) {
          toDelete.add(i);
        }
      }
      for (final i in toDelete.reversed) {
        await _box.deleteAt(i);
      }
      debugPrint('✅ Auto-cached products cleared');
    } catch (e) {
      debugPrint('❌ Error clearing auto-cached products: $e');
    }
  }

  /// Clear all cached products including manually saved
  Future<void> clearAllCachedProducts() async {
    try {
      await _box.clear();
      debugPrint('✅ All cached products cleared');
    } catch (e) {
      debugPrint('❌ Error clearing all cached products: $e');
    }
  }

  /// Get cache info (size, count, oldest/newest)
  Map<String, dynamic> getCacheInfo() {
    try {
      final allProducts = _box.values.toList();
      final savedProducts = allProducts
          .where((p) => p.isManuallySaved)
          .toList();
      final autoCached = allProducts.where((p) => !p.isManuallySaved).toList();

      return {
        'totalCount': allProducts.length,
        'savedCount': savedProducts.length,
        'autoCachedCount': autoCached.length,
        'oldestCached': allProducts.isEmpty
            ? null
            : allProducts
                  .reduce((a, b) => a.cachedAt.isBefore(b.cachedAt) ? a : b)
                  .cachedAt,
        'newestCached': allProducts.isEmpty
            ? null
            : allProducts
                  .reduce((a, b) => a.cachedAt.isAfter(b.cachedAt) ? a : b)
                  .cachedAt,
      };
    } catch (e) {
      debugPrint('❌ Error getting cache info: $e');
      return {'error': e.toString()};
    }
  }

  /// Internal: Remove oldest auto-cached products when exceeding limit
  Future<void> _cleanupExcessAutoCache() async {
    try {
      final autoCached = _box.values.where((p) => !p.isManuallySaved).toList()
        ..sort((a, b) => a.cachedAt.compareTo(b.cachedAt));

      if (autoCached.length > _maxAutoCache) {
        final toRemove = autoCached.length - _maxAutoCache;
        for (int i = 0; i < toRemove; i++) {
          final productId = autoCached[i].id;
          final index = _box.values.toList().indexWhere(
            (p) => p.id == productId,
          );
          if (index != -1) {
            await _box.deleteAt(index);
          }
        }
        debugPrint('✅ Cleaned up $toRemove old auto-cached products');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up cache: $e');
    }
  }
}
