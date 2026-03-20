// ============================================================================
// lib/shared/services/product/product_service.dart
// Product CRUD operations with Supabase
// ============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../models/product/product_model.dart';
import '../../models/product/category_model.dart';
import '../../models/product/unit_model.dart';
import '../../models/product/tag_model.dart';
import '../../models/product/product_review_model.dart';
import '../../models/product/offline_product_model.dart';
import '../offline/local_database_service.dart';
import '../offline/offline_sync_service.dart';

class ProductService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _localDb = LocalDatabaseService();
  final _syncService = OfflineSyncService();
  static const _uuid = Uuid();

  // ============================================================================
  // PRODUCTS OPERATIONS
  // ============================================================================

  /// Get all products with view data (ratings, farm info, etc)
  Future<List<Product>> getProducts({int limit = 20, int offset = 0}) async {
    try {
      final response = await _supabase
          .from('v_products')
          .select()
          .range(offset, offset + limit - 1)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }

  /// Get products by category
  Future<List<Product>> getProductsByCategory(
    String categoryId, {
    int limit = 20,
  }) async {
    try {
      final response = await _supabase
          .from('v_products')
          .select()
          .eq('category_id', categoryId)
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch products by category: $e');
    }
  }

  /// Get farmer's products
  Future<List<Product>> getFarmerProducts(String farmerId) async {
    try {
      final response = await _supabase
          .from('v_products')
          .select()
          .eq('farmer_id', farmerId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch farmer products: $e');
    }
  }

  /// Get single product by ID
  Future<Product?> getProductById(String productId) async {
    try {
      final response = await _supabase
          .from('v_products')
          .select()
          .eq('product_id', productId)
          .single();

      return Product.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Create new product
  Future<Product> createProduct({
    required String name,
    required double price,
    required String categoryId,
    required String unitId,
    required double quantity,
    String? description,
    String? imageUrl,
    int? harvestDays,
    bool isPreorder = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('products')
          .insert({
            'name': name,
            'price': price,
            'description': description,
            'image_url': imageUrl,
            'harvest_days': harvestDays,
            'is_preorder': isPreorder,
            'quantity': quantity,
            'farmer_id': userId,
            'category_id': categoryId,
            'unit_id': unitId,
          })
          .select()
          .single();

      return Product.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create product: $e');
    }
  }

  /// Update product
  Future<Product> updateProduct(
    String productId, {
    String? name,
    double? price,
    double? quantity,
    String? description,
    String? imageUrl,
    int? harvestDays,
    bool? isPreorder,
  }) async {
    try {
      final response = await _supabase
          .from('products')
          .update({
            'name': ?name,
            'price': ?price,
            'quantity': ?quantity,
            'description': ?description,
            'image_url': ?imageUrl,
            'harvest_days': ?harvestDays,
            'is_preorder': ?isPreorder,
          })
          .eq('product_id', productId)
          .select()
          .single();

      return Product.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  /// Delete product
  Future<void> deleteProduct(String productId) async {
    try {
      await _supabase.from('products').delete().eq('product_id', productId);
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  // ============================================================================
  // CATEGORIES OPERATIONS
  // ============================================================================

  /// Get all categories
  Future<List<Category>> getCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .order('name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Category.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  // ============================================================================
  // TAGS OPERATIONS
  // ============================================================================

  /// Get all available tags
  Future<List<Tag>> getTags() async {
    try {
      final response = await _supabase
          .from('product_tags')
          .select()
          .order('name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Tag.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch tags: $e');
    }
  }

  /// Get tags for a specific product
  Future<List<Tag>> getProductTags(String productId) async {
    try {
      final response = await _supabase
          .from('product_tag_mappings')
          .select('product_tags(tag_id, name, created_at)')
          .eq('product_id', productId);

      return (response as List<dynamic>).map((item) {
        final tag = item['product_tags'] as Map<String, dynamic>;
        return Tag.fromJson(tag);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch product tags: $e');
    }
  }

  /// Create a new tag
  Future<Tag> createTag(String name) async {
    try {
      final response = await _supabase
          .from('product_tags')
          .insert({'name': name.toLowerCase().trim()})
          .select()
          .single();

      return Tag.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create tag: $e');
    }
  }

  // ============================================================================
  // UNITS OPERATIONS
  // ============================================================================

  /// Get all units
  Future<List<Unit>> getUnits() async {
    try {
      final response = await _supabase
          .from('units')
          .select()
          .order('name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => Unit.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch units: $e');
    }
  }

  // ============================================================================
  // REVIEWS OPERATIONS
  // ============================================================================

  /// Get product reviews
  Future<List<ProductReview>> getProductReviews(
    String productId, {
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('product_reviews')
          .select()
          .eq('product_id', productId)
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => ProductReview.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch reviews: $e');
    }
  }

  /// Create product review
  Future<ProductReview> createReview({
    required String productId,
    required double rating,
    String? reviewText,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('product_reviews')
          .insert({
            'product_id': productId,
            'user_id': userId,
            'rating': rating,
            'review_text': reviewText,
          })
          .select()
          .single();

      return ProductReview.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create review: $e');
    }
  }

  /// Update review
  Future<ProductReview> updateReview(
    String reviewId, {
    double? rating,
    String? reviewText,
  }) async {
    try {
      final response = await _supabase
          .from('product_reviews')
          .update({'rating': ?rating, 'review_text': ?reviewText})
          .eq('review_id', reviewId)
          .select()
          .single();

      return ProductReview.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update review: $e');
    }
  }

  /// Delete review
  Future<void> deleteReview(String reviewId) async {
    try {
      await _supabase
          .from('product_reviews')
          .delete()
          .eq('review_id', reviewId);
    } catch (e) {
      throw Exception('Failed to delete review: $e');
    }
  }

  /// Search products
  Future<List<Product>> searchProducts(String query) async {
    try {
      final response = await _supabase
          .from('v_products')
          .select()
          .ilike('name', '%$query%')
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to search products: $e');
    }
  }

  // ============================================================================
  // OFFLINE-FIRST OPERATIONS
  // ============================================================================

  /// Create product with offline support
  /// If online: syncs immediately
  /// If offline: saves locally and syncs when connection returns
  Future<OfflineProduct> createProductOfflineFirst({
    required String name,
    required double price,
    required String categoryId,
    required String unitId,
    required double quantity,
    String? description,
    String? imageUrl,
    String? imageBase64,
    int? harvestDays,
    bool isPreorder = false,
    List<String> tagIds = const [],
  }) async {
    final farmerId = _supabase.auth.currentUser?.id;
    if (farmerId == null) throw Exception('User not authenticated');

    final localId = _uuid.v4();
    final now = DateTime.now();

    final offlineProduct = OfflineProduct(
      localId: localId,
      name: name,
      price: price,
      categoryId: categoryId,
      unitId: unitId,
      quantity: quantity,
      farmerId: farmerId,
      description: description,
      imageUrl: imageUrl,
      imageBase64: imageBase64,
      harvestDays: harvestDays,
      isPreorder: isPreorder,
      tagIds: tagIds,
      createdAt: now,
      updatedAt: now,
    );

    // Save to local database
    await _localDb.insertOfflineProduct(offlineProduct);

    // Try to sync if online
    final isOnline = await _syncService.hasInternetConnection();
    if (isOnline) {
      try {
        await _syncService.syncPendingProducts();
        print('✅ Product synced to server immediately');
      } catch (e) {
        // Sync failed, but product is saved locally
        print('⚠️  Sync failed, will retry later. Error: $e');
      }
    } else {
      print('📱 Offline mode: Product saved locally, will sync when online');
    }

    return offlineProduct;
  }

  /// Get all farmer's products (online + offline)
  Future<List<dynamic>> getFarmerProductsWithOffline(String farmerId) async {
    final results = <dynamic>[];

    // Get online products
    try {
      final onlineProducts = await getFarmerProducts(farmerId);
      results.addAll(onlineProducts);
    } catch (e) {
      print('Failed to fetch online products: $e');
    }

    // Get offline products
    try {
      final offlineProducts = await _localDb.getFarmerOfflineProducts(farmerId);
      results.addAll(
        offlineProducts.where((p) => p.syncStatus != SyncStatus.synced),
      );
    } catch (e) {
      print('Failed to fetch offline products: $e');
    }

    return results;
  }

  /// Get pending products count
  Future<int> getPendingProductsCount() async {
    return _syncService.getPendingProductCount();
  }

  /// Get sync statistics
  Future<Map<String, int>> getSyncStats() async {
    return _syncService.getSyncStats();
  }

  /// Manually trigger sync
  Future<void> syncPendingProducts() async {
    await _syncService.syncPendingProducts();
  }

  /// Delete offline product
  Future<void> deleteOfflineProduct(String localId) async {
    await _localDb.deleteOfflineProduct(localId);
  }

  /// Update offline product
  Future<void> updateOfflineProduct(OfflineProduct product) async {
    await _localDb.updateOfflineProduct(product);
  }

  /// Retry failed syncs
  Future<void> retryFailedSyncs() async {
    await _syncService.retryFailedSyncs();
  }

  /// Get connectivity stream for UI updates
  Stream<bool> get connectivityStream => _syncService.connectivityStream;
}
