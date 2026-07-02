import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'supabase_config.dart';
import '../../data/app_data.dart';
import '../community/forum_service.dart';

/// Supabase Data Service for fetching products, posts, and articles
/// Replaces the local SQLite ProductDatabaseService
class SupabaseDataService {
  static final SupabaseDataService _instance = SupabaseDataService._internal();
  factory SupabaseDataService() => _instance;
  SupabaseDataService._internal();

  static const String _featuredFarmersCacheKey = 'cache_featured_farmers_v1';
  static const String _forumPostsCacheKey = 'cache_forum_posts_v1';
  static const String _articlesCacheKey = 'cache_articles_v1';
  static const int _reportContentTypePost = 1;
  static const int _reportContentTypeComment = 2;
  static const int _reportContentTypeProduct = 3;
  static const int _reportContentTypeArticle = 5;

  final _client = SupabaseConfig.client;

  // Global navigation and filtering state
  static final ValueNotifier<int> navigationTabNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<String?> marketplaceCategoryNotifier =
      ValueNotifier<String?>(null);

  // ══════════════════════════════════════════════════════════════════════════
  // PRODUCTS
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<ProductItem>> getPreOrderProducts() async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      String? currentFarmerId;
      if (currentUserId != null) {
        final farmerRes = await _client
            .from('farmers')
            .select('farmer_id')
            .eq('user_id', currentUserId)
            .maybeSingle();
        if (farmerRes != null) {
          currentFarmerId = farmerRes['farmer_id']?.toString();
        }
      }

      final response = await _client
          .from('v_products')
          .select()
          .eq('is_preorder', true)
          .order('created_at', ascending: false);

      final items = response as List;
      final List<Map<String, dynamic>> enrichedItems = [];

      for (final rawItem in items) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        final productId = item['product_id']?.toString();

        if (productId != null && productId.isNotEmpty) {
          final imagesResponse = await _client
              .from('product_images')
              .select('image_url')
              .eq('product_id', productId)
              .order('sort_order', ascending: true);

          final images = (imagesResponse as List)
              .map((img) => img['image_url'].toString())
              .toList();

          final inventoryResponse = await _client
              .from('product_inventory')
              .select('available_quantity, reserved_quantity')
              .eq('product_id', productId)
              .maybeSingle();

          final reserved = (inventoryResponse?['reserved_quantity'] as num?)
              ?.toDouble();
          final available = (inventoryResponse?['available_quantity'] as num?)
              ?.toDouble();

          item['image_urls'] = images;
          item['image_url'] = images.isNotEmpty
              ? images.first
              : (item['image_url'] ?? '');
          item['reserved_quantity'] = reserved;
          item['target_quantity'] = (reserved ?? 0) + (available ?? 0) > 0
              ? (reserved ?? 0) + (available ?? 0)
              : null;
        }

        enrichedItems.add(item);
      }

      if (currentFarmerId != null) {
        enrichedItems.removeWhere((item) => item['farmer_id']?.toString() == currentFarmerId);
      }

      await _enrichProductItemsWithFarmerProfiles(enrichedItems);

      return enrichedItems.map((item) => _mapToProductItem(item)).toList();
    } catch (e) {
      debugPrint('Error fetching pre-order products: $e');
      return [];
    }
  }

  /// Get a single product by ID
  Future<ProductItem?> getProductById(String productId) async {
    try {
      final response = await _client
          .from('v_products')
          .select()
          .eq('product_id', productId)
          .maybeSingle();

      if (response == null) return null;

      final item = Map<String, dynamic>.from(response as Map);

      // Enrich with images
      final imagesResponse = await _client
          .from('product_images')
          .select('image_url')
          .eq('product_id', productId)
          .order('sort_order', ascending: true);

      final images = (imagesResponse as List)
          .map((img) => img['image_url'].toString())
          .toList();

      item['image_urls'] = images;
      item['image_url'] = images.isNotEmpty
          ? images.first
          : (item['image_url'] ?? '');

      await _enrichProductItemsWithFarmerProfiles([item]);

      return _mapToProductItem(item);
    } catch (e) {
      debugPrint('Error fetching product by ID: $e');
      return null;
    }
  }

  /// Watch nearby products in real-time
  Stream<List<ProductItem>> watchNearbyProducts() async* {
    // Yield initial data
    yield await getNearbyProducts();

    // Listen for changes in products or product_inventory tables
    final productStream = _client
        .from('products')
        .stream(primaryKey: ['product_id']);

    await for (final _ in productStream) {
      yield await getNearbyProducts();
    }
  }

  /// Watch pre-order products in real-time
  Stream<List<ProductItem>> watchPreOrderProducts() async* {
    yield await getPreOrderProducts();

    final productStream = _client
        .from('products')
        .stream(primaryKey: ['product_id'])
        .eq('is_preorder', true);

    await for (final _ in productStream) {
      yield await getPreOrderProducts();
    }
  }

  Future<List<ProductItem>> getNearbyProducts() async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      String? currentFarmerId;
      if (currentUserId != null) {
        final farmerRes = await _client
            .from('farmers')
            .select('farmer_id')
            .eq('user_id', currentUserId)
            .maybeSingle();
        if (farmerRes != null) {
          currentFarmerId = farmerRes['farmer_id']?.toString();
        }
      }

      final response = await _client
          .from('v_products')
          .select()
          .eq('is_preorder', false)
          .order('created_at', ascending: false);
      final items = response as List;
      final List<Map<String, dynamic>> enrichedItems = [];

      for (final rawItem in items) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        final productId = item['product_id']?.toString();

        if (productId != null && productId.isNotEmpty) {
          final imagesResponse = await _client
              .from('product_images')
              .select('image_url')
              .eq('product_id', productId)
              .order('sort_order', ascending: true);

          final images = (imagesResponse as List)
              .map((img) => img['image_url'].toString())
              .toList();

          item['image_urls'] = images;
          item['image_url'] = images.isNotEmpty
              ? images.first
              : (item['image_url'] ?? '');
        }
        enrichedItems.add(item);
      }

      if (currentFarmerId != null) {
        enrichedItems.removeWhere((item) => item['farmer_id']?.toString() == currentFarmerId);
      }

      await _enrichProductItemsWithFarmerProfiles(enrichedItems);

      return enrichedItems.map((item) => _mapToProductItem(item)).toList();
    } catch (e) {
      debugPrint('Error fetching nearby products: $e');
      return [];
    }
  }

  Future<List<ProductItem>> getAllProducts() async {
    try {
      final response = await _client
          .from('v_products')
          .select()
          .order('created_at', ascending: false);

      final items = response as List;
      final List<Map<String, dynamic>> enrichedItems = [];

      for (final rawItem in items) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        final productId = item['product_id']?.toString();

        if (productId != null && productId.isNotEmpty) {
          final imagesResponse = await _client
              .from('product_images')
              .select('image_url')
              .eq('product_id', productId)
              .order('sort_order', ascending: true);

          final images = (imagesResponse as List)
              .map((img) => img['image_url'].toString())
              .toList();

          item['image_urls'] = images;
          item['image_url'] = images.isNotEmpty
              ? images.first
              : (item['image_url'] ?? '');
        }
        enrichedItems.add(item);
      }

      await _enrichProductItemsWithFarmerProfiles(enrichedItems);

      return enrichedItems.map((item) => _mapToProductItem(item)).toList();
    } catch (e) {
      debugPrint('Error fetching all products: $e');
      return [];
    }
  }

  /// Watch farmer's own products in real-time
  Stream<List<Map<String, dynamic>>> watchFarmerProducts() async* {
    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) {
      yield [];
      return;
    }

    // Get farmer_id first
    final farmerResponse = await _client
        .from('farmers')
        .select('farmer_id')
        .eq('user_id', userId)
        .maybeSingle();

    if (farmerResponse == null) {
      yield [];
      return;
    }

    final farmerId = farmerResponse['farmer_id'] as String;

    // Yield initial data
    yield await getFarmerProducts();

    // Listen for changes in products table
    final productStream = _client
        .from('products')
        .stream(primaryKey: ['product_id'])
        .eq('farmer_id', farmerId);

    await for (final _ in productStream) {
      yield await getFarmerProducts();
    }
  }

  /// Get farmer's own products (for inventory management)
  Future<List<Map<String, dynamic>>> getFarmerProducts() async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      if (userId == null) return [];

      // First, get the farmer_id for this user
      final farmerResponse = await _client
          .from('farmers')
          .select('farmer_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (farmerResponse == null) {
        debugPrint('No farmer profile found for user: $userId');
        return [];
      }

      final farmerId = farmerResponse['farmer_id'] as String;

      // Get products from v_products view with units joined
      final response = await _client
          .from('v_products')
          .select('''
            product_id,
            name,
            description,
            price,
            harvest_days,
            is_preorder,
            farmer_id,
            category_id,
            unit_id,
            units(abbreviation, name)
          ''')
          .eq('farmer_id', farmerId)
          .order('created_at', ascending: false);

      // Now get images and inventory for each product
      List<Map<String, dynamic>> productsWithImages = [];

      for (var item in response) {
        final productId = item['product_id'] as String;

        // Get first/primary image
        final imageResponse = await _client
            .from('product_images')
            .select('image_url')
            .eq('product_id', productId)
            .order('sort_order', ascending: true)
            .limit(1)
            .maybeSingle();

        // Get inventory information
        final inventoryResponse = await _client
            .from('product_inventory')
            .select('available_quantity')
            .eq('product_id', productId)
            .maybeSingle();

        final price = (item['price'] as num?)?.toDouble() ?? 0;
        final unitData = item['units'] as Map?;
        final unitAbbr = (unitData?['abbreviation'] as String?) ?? 'kg';
        final availableQuantity =
            (inventoryResponse?['available_quantity'] as num?)?.toDouble() ?? 0;

        String status = 'IN STOCK';

        productsWithImages.add({
          'id': productId,
          'name': item['name'] ?? '',
          'description': item['description'] ?? '',
          'price': price,
          'unit': unitAbbr,
          'available': availableQuantity,
          'available_quantity': availableQuantity,
          'harvest':
              (item['harvest_days'] != null &&
                  (item['harvest_days'] as num) > 0)
              ? 'In ${item['harvest_days']} days'
              : (item['is_preorder'] == true ? 'Pre-order' : 'Ready Now'),
          'harvest_days': item['harvest_days'] ?? 0,
          'is_preorder': item['is_preorder'] ?? false,
          'status': status,
          'image': imageResponse?['image_url'] ?? '',
          'category_id': item['category_id'],
          'unit_id': item['unit_id'],
        });
      }

      return productsWithImages;
    } catch (e) {
      debugPrint('Error fetching farmer products: $e');
      return [];
    }
  }

  /// Get products by category
  Future<List<ProductItem>> getProductsByCategory(String category) async {
    try {
      final response = await _client
          .from('v_products')
          .select()
          .ilike('category_name', category)
          .order('created_at', ascending: false);

      final items = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      await _enrichProductItemsWithFarmerProfiles(items);
      return items.map((item) => _mapToProductItem(item)).toList();
    } catch (e) {
      debugPrint('Error fetching products by category: $e');
      return [];
    }
  }

  /// Get distinct product categories currently used in marketplace products.
  Future<List<String>> getMarketplaceCategories() async {
    try {
      // Primary source: full active category catalog.
      final categoryResponse = await _client
          .from('categories')
          .select('name')
          .eq('is_active', true)
          .order('name', ascending: true);

      final categories = <String>[];
      final seen = <String>{};

      for (final row in (categoryResponse as List)) {
        final raw = row['name']?.toString().trim();
        if (raw == null || raw.isEmpty) continue;
        final key = raw.toLowerCase();
        if (seen.add(key)) {
          categories.add(raw);
        }
      }

      // Fallback/merge: categories seen on live non-preorder products.
      // This keeps chips resilient if some product rows carry labels not yet in catalog.
      final productCategoryResponse = await _client
          .from('v_products')
          .select('category_name')
          .eq('is_preorder', false)
          .order('category_name', ascending: true);

      for (final row in (productCategoryResponse as List)) {
        final raw = row['category_name']?.toString().trim();
        if (raw == null || raw.isEmpty) continue;
        final key = raw.toLowerCase();
        if (seen.add(key)) {
          categories.add(raw);
        }
      }

      return categories;
    } catch (e) {
      debugPrint('Error fetching marketplace categories: $e');
      return [];
    }
  }

  /// Get all categories from the database
  Future<List<CategoryItem>> getCategories() async {
    try {
      final response = await _client
          .from('categories')
          .select('name')
          .eq('is_active', true)
          .order('name');

      return (response as List).map((cat) {
        final name = cat['name']?.toString() ?? 'Other';

        return CategoryItem(
          name: name,
          iconCodePoint: _mapCategoryToIcon(name),
          bgColor: _getCategoryColor(name, isBackground: true),
          iconColor: _getCategoryColor(name, isBackground: false),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return [];
    }
  }

  int _mapCategoryToIcon(String categoryName) {
    // Mapping based on category name keywords
    final name = categoryName.toLowerCase();

    if (name.contains('veggie') || name.contains('vegetable')) {
      return Icons.eco_rounded.codePoint;
    }
    if (name.contains('fruit')) {
      return Icons.apple_rounded.codePoint;
    }
    if (name.contains('grain') ||
        name.contains('rice') ||
        name.contains('corn')) {
      return Icons.grass_rounded.codePoint;
    }
    if (name.contains('dairy') ||
        name.contains('milk') ||
        name.contains('egg') ||
        name.contains('cheese')) {
      return Icons.water_drop_rounded.codePoint;
    }
    if (name.contains('poultry') || name.contains('chicken')) {
      return Icons.egg_rounded.codePoint;
    }
    if (name.contains('livestock') || name.contains('meat')) {
      return Icons.bakery_dining_rounded.codePoint; // Placeholder for meat
    }
    if (name.contains('herb') || name.contains('spice')) {
      return Icons.spa_rounded.codePoint;
    }
    if (name.contains('root')) {
      return Icons.agriculture_rounded.codePoint;
    }

    return Icons.category_rounded.codePoint;
  }

  int _getCategoryColor(String categoryName, {required bool isBackground}) {
    final name = categoryName.toLowerCase();

    if (name.contains('veggie')) {
      return isBackground ? 0xFFDCFCE7 : 0xFF10B981; // Green
    }
    if (name.contains('fruit')) {
      return isBackground ? 0xFFFFEDD5 : 0xFFEA580C; // Orange
    }
    if (name.contains('grain')) {
      return isBackground ? 0xFFFEF3C7 : 0xFFD97706; // Amber
    }
    if (name.contains('dairy')) {
      return isBackground ? 0xFFDBEAFE : 0xFF2563EB; // Blue
    }
    if (name.contains('organic')) {
      return isBackground ? 0xFFD1FAE5 : 0xFF059669; // Emerald
    }

    // Default neutral colors
    return isBackground ? 0xFFF1F5F9 : 0xFF64748B;
  }

  Future<void> _enrichProductItemsWithFarmerProfiles(
    List<Map<String, dynamic>> items,
  ) async {
    final farmerIds = items
        .map((item) => item['farmer_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    if (farmerIds.isEmpty) return;

    try {
      dynamic response;
      try {
        // Try fetching with aliased names first (common in views)
        response = await _client
            .from('v_farmer_profiles')
            .select(
              'farmer_id, farm_name, farmer_name, avatar_url, image_url, latitude, longitude',
            )
            .inFilter('farmer_id', farmerIds);
      } catch (e) {
        // Fallback: try fetching with raw database column names
        try {
          response = await _client
              .from('v_farmer_profiles')
              .select(
                'farmer_id, farm_name, farmer_name, avatar_url, image_url, farm_latitude, farm_longitude',
              )
              .inFilter('farmer_id', farmerIds);

          // Map raw names back to expected ones for consistency
          for (final row in (response as List)) {
            if (row is Map) {
              row['latitude'] = row['farm_latitude'];
              row['longitude'] = row['farm_longitude'];
            }
          }
        } catch (innerE) {
          // Final fallback: fetch without location if both attempts fail
          response = await _client
              .from('v_farmer_profiles')
              .select(
                'farmer_id, farm_name, farmer_name, avatar_url, image_url',
              )
              .inFilter('farmer_id', farmerIds);
        }
      }

      final profileByFarmerId = {
        for (final row in (response as List))
          (row['farmer_id']?.toString() ?? ''): Map<String, dynamic>.from(
            row as Map,
          ),
      };

      // Apply profiles to items
      for (final item in items) {
        final fId = item['farmer_id']?.toString();
        if (fId == null || !profileByFarmerId.containsKey(fId)) continue;

        final profile = profileByFarmerId[fId]!;
        item['farmer_name'] = profile['farmer_name'] ?? profile['farm_name'];
        final avatarUrl = profile['avatar_url']?.toString();
        final farmerImageUrl = profile['image_url']?.toString();
        item['farmer_avatar_url'] = (avatarUrl != null && avatarUrl.isNotEmpty)
            ? avatarUrl
            : farmerImageUrl;
        item['farmer_image_url'] = farmerImageUrl;
        if ((item['farm_name']?.toString().trim().isEmpty ?? true)) {
          item['farm_name'] = profile['farm_name'];
        }
        item['latitude'] = profile['latitude'] ?? profile['farm_latitude'];
        item['longitude'] = profile['longitude'] ?? profile['farm_longitude'];
      }
    } catch (e) {
      debugPrint('Error enriching farmer profiles on products: $e');
    }
  }

  /// Add a new product
  Future<void> addProduct(
    ProductItem product, {
    bool isPreOrder = false,
  }) async {
    try {
      final userId = SupabaseConfig.currentUser?.id;

      // Look up category_id and unit_id
      final categoryResponse = await _client
          .from('categories')
          .select('category_id')
          .ilike('name', product.farm) // farm field used as category for now
          .maybeSingle();

      final unitResponse = await _client
          .from('units')
          .select('unit_id')
          .ilike('abbreviation', product.unit)
          .maybeSingle();

      await _client.from('products').insert({
        'name': product.name,
        'price':
            double.tryParse(product.price.replaceAll(RegExp(r'[^\d.]'), '')) ??
            0,
        'image_url': product.imageUrl,
        'harvest_days': int.tryParse(product.harvestDays ?? '0'),
        'is_preorder': isPreOrder,
        'farmer_id': userId,
        'category_id': categoryResponse?['category_id'],
        'unit_id': unitResponse?['unit_id'],
      });
    } catch (e) {
      debugPrint('Error adding product: $e');
      rethrow;
    }
  }

  /// Delete a product
  Future<bool> deleteProduct(String productId) async {
    try {
      // Delete from inventory first (due to foreign keys)
      await _client
          .from('product_inventory')
          .delete()
          .eq('product_id', productId);

      // Delete images
      await _client.from('product_images').delete().eq('product_id', productId);

      // Delete product itself
      await _client.from('products').delete().eq('product_id', productId);

      return true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  /// Report a product for community safety
  Future<void> reportProduct({
    required String productId,
    required String reason,
    String? description,
  }) async {
    await _submitContentReport(
      contentId: productId,
      contentTypeId: _reportContentTypeProduct,
      reason: reason,
      description: description,
    );
  }

  ProductItem _mapToProductItem(Map<String, dynamic> item) {
    final rawCreated = item['created_at']?.toString() ?? '';
    return ProductItem(
      productId: item['product_id']?.toString(),
      farmerId: item['farmer_id']?.toString(),
      farmerName: item['farmer_name']?.toString(),
      farmerAvatarUrl: item['farmer_avatar_url']?.toString(),
      farmerImageUrl: item['farmer_image_url']?.toString(),
      name: item['name'] ?? '',
      farm: item['farm_name'] ?? '',
      price: '₱${item['price']?.toString() ?? '0'}',
      unit: item['unit_abbr'] ?? item['unit_name'] ?? '',
      imageUrl: item['image_url'] ?? '',
      imageUrls:
          (item['image_urls'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      categoryName: item['category_name']?.toString(),
      rating: item['average_rating']?.toString(),
      reviews: item['review_count']?.toString(),
      harvestDays: item['harvest_days']?.toString(),
      description: item['description']?.toString(),
      reservedQuantity: (item['reserved_quantity'] as num?)?.toDouble(),
      targetQuantity: (item['target_quantity'] as num?)?.toDouble(),
      latitude: (item['latitude'] as num?)?.toDouble(),
      longitude: (item['longitude'] as num?)?.toDouble(),
      isFeatured: item['is_featured'] == true,
      createdAt: rawCreated.isNotEmpty ? DateTime.tryParse(rawCreated) : null,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRODUCTS BY FARMER (for public farmer profile)
  // ══════════════════════════════════════════════════════════════════════════

  /// Get all products by a specific farmer ID (public view)
  Future<List<ProductItem>> getProductsByFarmerId(String farmerId) async {
    try {
      final response = await _client
          .from('v_products')
          .select()
          .eq('farmer_id', farmerId)
          .order('created_at', ascending: false);

      final items = response as List;
      final List<Map<String, dynamic>> enrichedItems = [];

      for (final rawItem in items) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        final productId = item['product_id']?.toString();

        if (productId != null && productId.isNotEmpty) {
          final imagesResponse = await _client
              .from('product_images')
              .select('image_url')
              .eq('product_id', productId)
              .order('sort_order', ascending: true);

          final images = (imagesResponse as List)
              .map((img) => img['image_url'].toString())
              .toList();

          item['image_urls'] = images;
          item['image_url'] = images.isNotEmpty
              ? images.first
              : (item['image_url'] ?? '');
        }
        enrichedItems.add(item);
      }

      await _enrichProductItemsWithFarmerProfiles(enrichedItems);

      return enrichedItems.map((item) => _mapToProductItem(item)).toList();
    } catch (e) {
      debugPrint('Error fetching products by farmer ID: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FORUM POSTS BY USER (for public farmer profile)
  // ══════════════════════════════════════════════════════════════════════════

  /// Get all forum posts by a specific user ID
  Future<List<ForumPostItem>> getForumPostsByUserId(String userId) async {
    try {
      final response = await _client
          .from('v_forum_posts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final currentUserId = SupabaseConfig.currentUser?.id;
      List<String> likedPostIds = [];

      if (currentUserId != null) {
        final likes = await _client
            .from('forum_post_likes')
            .select('post_id')
            .eq('user_id', currentUserId);
        likedPostIds = (likes as List)
            .map((l) => l['post_id'].toString())
            .toList();
      }

      String? avatarUrl;
      if ((response as List).isNotEmpty) {
        final uId = response[0]['user_id']?.toString();
        if (uId != null) {
          try {
            final userResponse = await _client
                .from('users')
                .select('avatar_url')
                .eq('user_id', uId)
                .maybeSingle();
            avatarUrl = userResponse?['avatar_url']?.toString();
          } catch (e) {
            debugPrint('Error fetching user avatar: $e');
          }
        }
      }

      return (response).map((item) {
        final postId = item['post_id'].toString();
        return _mapToForumPostItem(item, likedPostIds.contains(postId), avatarUrl);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching forum posts by user: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FORUM POSTS
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<ForumPostItem>> watchForumPosts() {
    return _watchForumPostsInternal().asBroadcastStream();
  }

  Stream<List<ForumPostItem>> _watchForumPostsInternal() {
    late final List<StreamSubscription<dynamic>> subscriptions;
    final controller = StreamController<List<ForumPostItem>>();

    Future<void> emitLatest() async {
      try {
        if (!controller.isClosed) {
          controller.add(await getForumPosts());
        }
      } catch (e, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(e, stackTrace);
        }
      }
    }

    controller.onListen = () {
      emitLatest();
      subscriptions = [
        _client
            .from('forum_posts')
            .stream(primaryKey: ['post_id'])
            .listen((_) => emitLatest()),
        _client
            .from('forum_comments')
            .stream(primaryKey: ['comment_id'])
            .listen((_) => emitLatest()),
        _client
            .from('forum_post_likes')
            .stream(primaryKey: ['user_id', 'post_id'])
            .listen((_) => emitLatest()),
      ];
    };

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  /// Get all forum posts
  Future<List<ForumPostItem>> getForumPosts() async {
    try {
      final response = await _client
          .from('v_forum_posts')
          .select()
          .order('created_at', ascending: false);

      final userId = SupabaseConfig.currentUser?.id;
      List<String> likedPostIds = [];

      // Get user's liked posts if logged in
      if (userId != null) {
        final likes = await _client
            .from('forum_post_likes')
            .select('post_id')
            .eq('user_id', userId);
        likedPostIds = (likes as List)
            .map((l) => l['post_id'].toString())
            .toList();
      }

      // Fetch user avatars for enrichment
      final userIds = (response as List)
          .map((item) => item['user_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      final userAvatars = <String, String>{};
      if (userIds.isNotEmpty) {
        try {
          final usersResponse = await _client
              .from('users')
              .select('user_id, avatar_url')
              .inFilter('user_id', userIds);
          for (final row in (usersResponse as List)) {
            final uId = row['user_id']?.toString();
            final avatar = row['avatar_url']?.toString();
            if (uId != null && avatar != null && avatar.isNotEmpty) {
              userAvatars[uId] = avatar;
            }
          }
        } catch (e) {
          debugPrint('Error fetching user avatars for forum posts: $e');
        }
      }

      final posts = (response).map((item) {
        final postId = item['post_id'].toString();
        final uId = item['user_id']?.toString();
        final avatar = uId != null ? userAvatars[uId] : null;
        return _mapToForumPostItem(item, likedPostIds.contains(postId), avatar);
      }).toList();

      await _cacheMapList(
        _forumPostsCacheKey,
        posts
            .map(
              (post) => {
                'id': post.id,
                'user_id': post.userId,
                'user_name': post.userName,
                'time': post.time,
                'title': post.title,
                'body': post.body,
                'image_url': post.imageUrl,
                'video_url': post.videoUrl,
                'likes': post.likes,
                'comments': post.comments,
                'is_liked': post.isLiked,
              },
            )
            .toList(),
      );

      return posts;
    } catch (e) {
      debugPrint('Error fetching forum posts: $e');
      final cached = await _readCachedMapList(_forumPostsCacheKey);
      return cached
          .map(
            (item) => ForumPostItem(
              id: item['id']?.toString() ?? '',
              userId: item['user_id']?.toString(),
              userName: item['user_name']?.toString() ?? 'Anonymous',
              time: item['time']?.toString() ?? 'Recently',
              title: item['title']?.toString() ?? '',
              body: item['body']?.toString() ?? '',
              imageUrl: item['image_url']?.toString(),
              videoUrl: item['video_url']?.toString(),
              likes: _toInt(item['likes']),
              comments: _toInt(item['comments']),
              isLiked: item['is_liked'] == true,
            ),
          )
          .toList();
    }
  }

  /// Get a single forum post
  Future<ForumPostItem?> getForumPostById(String postId) async {
    try {
      final response = await _client
          .from('v_forum_posts')
          .select()
          .eq('post_id', postId)
          .maybeSingle();

      if (response == null) return null;

      final userId = SupabaseConfig.currentUser?.id;
      var isLiked = false;

      if (userId != null) {
        final like = await _client
            .from('forum_post_likes')
            .select('post_id')
            .eq('post_id', postId)
            .eq('user_id', userId)
            .maybeSingle();
        isLiked = like != null;
      }

      String? avatarUrl;
      final uId = response['user_id']?.toString();
      if (uId != null) {
        try {
          final userResponse = await _client
              .from('users')
              .select('avatar_url')
              .eq('user_id', uId)
              .maybeSingle();
          avatarUrl = userResponse?['avatar_url']?.toString();
        } catch (e) {
          debugPrint('Error fetching user avatar: $e');
        }
      }

      return _mapToForumPostItem(response, isLiked, avatarUrl);
    } catch (e) {
      debugPrint('Error fetching forum post $postId: $e');
      return null;
    }
  }

  /// Add a new forum post
  Future<void> addForumPost(ForumPostItem post) async {
    try {
      await ForumService().createPost(
        title: post.title,
        body: post.body,
        imageUrl: post.imageUrl,
        videoUrl: post.videoUrl,
      );
    } catch (e) {
      debugPrint('Error adding forum post: $e');
      rethrow;
    }
  }

  /// Like/Unlike a post
  Future<void> togglePostLike(String postId) async {
    try {
      final forumService = ForumService();
      final isLiked = await forumService.hasUserLikedPost(postId);

      if (isLiked) {
        await forumService.unlikePost(postId);
      } else {
        await forumService.likePost(postId);
      }
    } catch (e) {
      debugPrint('Error toggling post like: $e');
      rethrow;
    }
  }

  Future<void> reportForumPost({
    required String postId,
    required String reason,
    String? description,
  }) async {
    await _submitContentReport(
      contentId: postId,
      contentTypeId: _reportContentTypePost,
      reason: reason,
      description: description,
    );
  }

  Future<void> reportForumComment({
    required String commentId,
    required String reason,
    String? description,
  }) async {
    await _submitContentReport(
      contentId: commentId,
      contentTypeId: _reportContentTypeComment,
      reason: reason,
      description: description,
    );
  }

  /// Upload a forum post image
  Future<String?> uploadForumImage({
    String? localPath,
    Uint8List? bytes,
  }) async {
    if (localPath == null && bytes == null) return null;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'forum/$fileName';

    final result = await SupabaseDatabase.uploadImage(
      bucket: 'uploads',
      path: path,
      localPath: localPath,
      bytes: bytes,
    );

    if (result != null) {
      // Get the full public URL
      return _client.storage.from('uploads').getPublicUrl(path);
    }
    return null;
  }

  /// Upload a forum post video
  Future<String?> uploadForumVideo({
    String? localPath,
    Uint8List? bytes,
  }) async {
    if (localPath == null && bytes == null) return null;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
    final path = 'forum/$fileName';

    final result = await SupabaseDatabase.uploadImage(
      bucket: 'uploads',
      path: path,
      localPath: localPath,
      bytes: bytes,
    );

    if (result != null) {
      return _client.storage.from('uploads').getPublicUrl(path);
    }
    return null;
  }

  /// Get trending topics (most engaged posts)
  Future<List<Map<String, dynamic>>> getTrendingTopics() async {
    try {
      final response = await _client
          .from('v_forum_posts')
          .select('title, likes_count')
          .order('likes_count', ascending: false)
          .limit(4);

      return (response as List)
          .map(
            (item) => {
              'title': item['title'] ?? 'Untitled',
              'engagement': item['likes_count'] ?? 0,
            },
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get popular tags (extracted from post bodies)
  Future<List<String>> getPopularTags() async {
    try {
      final response = await _client
          .from('forum_posts')
          .select('body')
          .limit(50);

      final bodies = (response as List)
          .map((item) => item['body']?.toString() ?? '')
          .toList();
      final tagRegExp = RegExp(r'#\w+');
      final tags = <String>{};

      for (var body in bodies) {
        final matches = tagRegExp.allMatches(body);
        for (var match in matches) {
          tags.add(match.group(0)!);
        }
      }

      if (tags.isEmpty) return ['#farming', '#agri', '#community', '#help'];
      return tags.take(8).toList();
    } catch (e) {
      return ['#farming', '#agri', '#community', '#help'];
    }
  }

  /// Get top contributors
  Future<List<Map<String, dynamic>>> getTopContributors() async {
    try {
      // Group by author_id and count posts
      final response = await _client
          .from('v_forum_posts')
          .select('author_name');

      final authors = (response as List)
          .map((item) => item['author_name']?.toString() ?? 'Anonymous')
          .toList();
      final counts = <String, int>{};
      for (var author in authors) {
        counts[author] = (counts[author] ?? 0) + 1;
      }

      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted
          .take(3)
          .map((e) => {'name': e.key, 'posts': '${e.value} posts'})
          .toList();
    } catch (e) {
      return [];
    }
  }

  ForumPostItem _mapToForumPostItem(Map<String, dynamic> item, bool isLiked, [String? authorAvatarUrl]) {
    final createdAt = DateTime.tryParse(item['created_at'] ?? '');
    final timeAgo = createdAt != null ? _formatTimeAgo(createdAt) : 'Recently';

    return ForumPostItem(
      id: item['post_id']?.toString() ?? '',
      userId: item['user_id']?.toString(),
      userName: item['author_name'] ?? 'Anonymous',
      time: timeAgo,
      title: item['title'] ?? '',
      body: item['body'] ?? '',
      imageUrl: item['image_url'],
      videoUrl: item['video_url'],
      likes: item['likes_count'] ?? 0,
      comments: item['comments_count'] ?? 0,
      isLiked: isLiked,
      isPinned: item['is_pinned'] ?? false,
      authorAvatarUrl: authorAvatarUrl,
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} mins ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ARTICLES
  // ══════════════════════════════════════════════════════════════════════════

  /// Get all published articles
  Future<List<ArticleItem>> getArticles() async {
    try {
      var query = _client.from('v_articles').select().eq('published', true);

      // Determine user role and filter audience
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        final isFarmer = await SupabaseDatabase.hasRole(
          userId: userId,
          roleName: 'seller',
        );
        if (isFarmer) {
          query = query.inFilter('audience', ['ALL', 'FARMER']);
        } else {
          query = query.inFilter('audience', ['ALL', 'CUSTOMER']);
        }
      } else {
        query = query.inFilter('audience', ['ALL', 'CUSTOMER']);
      }

      final response = await query.order('created_at', ascending: false);

      final articles = (response as List)
          .map((item) => _mapToArticleItem(item))
          .toList();

      await _cacheMapList(
        _articlesCacheKey,
        articles
            .map(
              (article) => {
                'id': article.id,
                'title': article.title,
                'excerpt': article.excerpt,
                'content': article.content,
                'author': article.author,
                'read_time': article.readTime,
                'time': article.time,
                'image_url': article.imageUrl,
              },
            )
            .toList(),
      );

      return articles;
    } catch (e) {
      debugPrint('Error fetching articles: $e');
      final cached = await _readCachedMapList(_articlesCacheKey);
      return cached
          .map(
            (item) => ArticleItem(
              id: item['id']?.toString(),
              title: item['title']?.toString() ?? '',
              excerpt: item['excerpt']?.toString() ?? '',
              author: item['author']?.toString() ?? 'AgriDirect',
              readTime: item['read_time']?.toString() ?? '4 min read',
              time: item['time']?.toString() ?? 'Recently',
              imageUrl: item['image_url']?.toString(),
            ),
          )
          .where((article) => article.title.isNotEmpty)
          .toList();
    }
  }

  Future<void> reportArticle({
    required String articleId,
    required String reason,
    String? description,
  }) async {
    await _submitContentReport(
      contentId: articleId,
      contentTypeId: _reportContentTypeArticle,
      reason: reason,
      description: description,
    );
  }

  /// Add a new article
  Future<void> addArticle(ArticleItem article) async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      if (userId == null) return;

      final adminResponse = await _client
          .from('admins')
          .select('admin_id')
          .eq('user_id', userId)
          .maybeSingle();
      final adminId = adminResponse?['admin_id'];

      await _client.from('admin_articles').insert({
        'title': article.title,
        'summary': article.excerpt,
        'body': article
            .excerpt, // Using excerpt as body if body is missing in model
        'admin_id': adminId,
        'read_time': article.readTime,
        'cover_image_url': article.imageUrl,
        'is_published': true,
        'published_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error adding article: $e');
      rethrow;
    }
  }

  ArticleItem _mapToArticleItem(Map<String, dynamic> item) {
    final createdAt = DateTime.tryParse(item['created_at'] ?? '');
    final timeAgo = createdAt != null ? _formatTimeAgo(createdAt) : 'Recently';

    // Use read_time from DB if available, otherwise calculate it
    String readTimeStr = item['read_time']?.toString() ?? '';
    if (readTimeStr.isEmpty) {
      final textContent =
          '${item['title'] ?? ''} ${item['summary'] ?? item['excerpt'] ?? item['body'] ?? item['content'] ?? ''}';
      final wordCount = textContent
          .trim()
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .length;
      final minutes = (wordCount / 200).ceil();
      readTimeStr = minutes > 0 ? '$minutes min read' : '1 min read';
    }

    return ArticleItem(
      id: item['article_id']?.toString(),
      title: item['title'] ?? '',
      excerpt: item['summary'] ?? item['excerpt'] ?? '',
      content: item['body'] ?? item['content'],
      imageUrl: item['cover_image_url'] ?? item['image_url'],
      author: item['author_name'] ?? 'AgriDirect',
      readTime: readTimeStr,
      time: timeAgo,
      audience: item['audience'],
    );
  }

  Future<void> _submitContentReport({
    required String contentId,
    required int contentTypeId,
    required String reason,
    String? description,
  }) async {
    final reporterId = _client.auth.currentUser?.id;
    if (reporterId == null || reporterId.isEmpty) {
      throw Exception('User not authenticated');
    }

    final existing = await _client
        .from('reported_content')
        .select('report_id')
        .eq('content_id', contentId)
        .eq('content_type_id', contentTypeId)
        .eq('reporter_id', reporterId)
        .inFilter('status', ['pending', 'reviewing'])
        .maybeSingle();

    if (existing != null) {
      throw Exception('You already reported this content.');
    }

    await _client.from('reported_content').insert({
      'content_id': contentId,
      'content_type_id': contentTypeId,
      'reason': reason,
      'description': description?.trim().isEmpty ?? true
          ? null
          : description!.trim(),
      'status': 'pending',
      'reporter_id': reporterId,
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DASHBOARD METRICS (for farmers)
  // ══════════════════════════════════════════════════════════════════════════

  /// Get dashboard metrics for the current farmer
  Future<List<DashboardMetric>> getDashboardMetrics() async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      if (userId == null) return _getDefaultMetrics();

      // Get farmer's product stats
      final products = await _client
          .from('products')
          .select('price, is_preorder')
          .eq('farmer_id', userId);

      final productList = products as List;
      final totalProducts = productList.length;
      final preOrders = productList
          .where((p) => p['is_preorder'] == true)
          .length;

      // Calculate estimated revenue
      double totalRevenue = 0;
      for (var p in productList) {
        final price = (p['price'] as num?)?.toDouble() ?? 0;
        totalRevenue += price * 10; // Assume 10 units sold each
      }

      return [
        DashboardMetric(
          label: 'Total Revenue',
          value: '₱${totalRevenue.toStringAsFixed(0)}',
          subtitle: 'This month',
          iconCodePoint: 0xe25e, // Icons.attach_money
          color: 0xFF13EC5B,
        ),
        DashboardMetric(
          label: 'Active Products',
          value: totalProducts.toString(),
          subtitle: 'In marketplace',
          iconCodePoint: 0xe5d2, // Icons.inventory
          color: 0xFF3B82F6,
        ),
        DashboardMetric(
          label: 'Pre-Orders',
          value: preOrders.toString(),
          subtitle: 'Pending',
          iconCodePoint: 0xe8f6, // Icons.schedule
          color: 0xFFF59E0B,
        ),
        DashboardMetric(
          label: 'Rating',
          value: '4.8',
          subtitle: 'Average',
          iconCodePoint: 0xe838, // Icons.star
          color: 0xFFEF4444,
        ),
      ];
    } catch (e) {
      debugPrint('Error fetching dashboard metrics: $e');
      return _getDefaultMetrics();
    }
  }

  List<DashboardMetric> _getDefaultMetrics() {
    return [
      const DashboardMetric(
        label: 'Total Revenue',
        value: '₱0',
        subtitle: 'This month',
        iconCodePoint: 0xe25e,
        color: 0xFF13EC5B,
      ),
      const DashboardMetric(
        label: 'Active Products',
        value: '0',
        subtitle: 'In marketplace',
        iconCodePoint: 0xe5d2,
        color: 0xFF3B82F6,
      ),
      const DashboardMetric(
        label: 'Pre-Orders',
        value: '0',
        subtitle: 'Pending',
        iconCodePoint: 0xe8f6,
        color: 0xFFF59E0B,
      ),
      const DashboardMetric(
        label: 'Rating',
        value: '-',
        subtitle: 'No reviews',
        iconCodePoint: 0xe838,
        color: 0xFFEF4444,
      ),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ORDERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Watch farmer orders in real-time
  Stream<List<Map<String, dynamic>>> watchFarmerOrders() async* {
    yield await getFarmerOrders();

    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) return;

    // Listen for changes in orders table
    final orderStream = _client.from('orders').stream(primaryKey: ['order_id']);

    await for (final _ in orderStream) {
      yield await getFarmerOrders();
    }
  }

  /// Get farmer's orders
  Future<List<Map<String, dynamic>>> getFarmerOrders({String? status}) async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      if (userId == null) return [];

      // Get the actual farmer_id for this user
      final farmerResponse = await _client
          .from('farmers')
          .select('farmer_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (farmerResponse == null) return [];
      final farmerId = farmerResponse['farmer_id'] as String;

      List<dynamic> response;
      try {
        var query = _client.from('v_orders').select().eq('farmer_id', farmerId);

        if (status != null) {
          if (status == 'Active') {
            query = query.inFilter('status_code', [
              'pending',
              'confirmed',
              'shipped',
              'processing',
              'PENDING',
              'CONFIRMED',
              'SHIPPED',
              'PROCESSING',
            ]);
          } else if (status == 'Completed') {
            query = query.inFilter('status_code', ['delivered', 'DELIVERED']);
          } else if (status == 'Refunds') {
            query = query.inFilter('status_code', [
              'cancelled',
              'refunded',
              'CANCELLED',
              'REFUNDED',
            ]);
          }
        }
        response = await query.order('created_at', ascending: false);
      } catch (e) {
        debugPrint(
          'v_orders view failed, falling back to direct table join: $e',
        );
        var query = _client
            .from('orders')
            .select('''
          *,
          order_statuses(code, description),
          customers:customer_id(
            users:user_id(
              name,
              avatar_url,
              image_url
            )
          )
        ''')
            .eq('farmer_id', farmerId);

        if (status != null) {
          if (status == 'Active') {
            query = query.inFilter('order_statuses.code', [
              'pending',
              'confirmed',
              'shipped',
              'processing',
              'PENDING',
              'CONFIRMED',
              'SHIPPED',
              'PROCESSING',
            ]);
          } else if (status == 'Completed') {
            query = query.inFilter('order_statuses.code', [
              'delivered',
              'DELIVERED',
            ]);
          } else if (status == 'Refunds') {
            query = query.inFilter('order_statuses.code', [
              'cancelled',
              'refunded',
              'CANCELLED',
              'REFUNDED',
            ]);
          }
        }
        response = await query.order('created_at', ascending: false);
      }

      String firstNonEmpty(List<dynamic> values) {
        for (final value in values) {
          final text = value?.toString().trim() ?? '';
          if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
        }
        return '';
      }

      final mappedOrders = <Map<String, dynamic>>[];

      for (final raw in response) {
        final item = (raw is Map<String, dynamic>)
            ? raw
            : Map<String, dynamic>.from(raw as Map);

        final createdAt =
            DateTime.tryParse(item['created_at']?.toString() ?? '') ??
            DateTime.now();
        final rawTotal =
            (item['total_amount'] as num?)?.toDouble() ??
            (item['total'] as num?)?.toDouble() ??
            (item['subtotal'] as num?)?.toDouble() ??
            0.0;

        // Handle flattened status from view or nested status from orders
        final statusCode =
            (item['status_code'] ?? item['status'])?.toString().toUpperCase() ??
            (item['order_statuses']?['code'])?.toString().toUpperCase() ??
            'PENDING';

        // Handle customer data from v_orders (flattened) or orders (nested)
        String customerName = firstNonEmpty([
          item['customer_name'],
          item['name'],
        ]);
        String customerAvatar = firstNonEmpty([
          item['customer_image'],
          item['customer_avatar_url'],
          item['avatar_url'],
        ]);

        if (item['customers'] != null) {
          final customerRaw = item['customers'];
          final customerData = customerRaw is List
              ? (customerRaw.isNotEmpty ? customerRaw.first : null)
              : customerRaw;
          final userRaw = customerData?['users'];
          final userData = userRaw is List
              ? (userRaw.isNotEmpty ? userRaw.first : null)
              : userRaw;

          customerName = firstNonEmpty([customerName, userData?['name']]);
          customerAvatar = firstNonEmpty([
            customerAvatar,
            userData?['avatar_url'],
            userData?['image_url'],
            userData?['profile_image_url'],
          ]);
        }

        final safeCustomerAvatar = customerAvatar.isNotEmpty
            ? await SupabaseDatabase.getSafeUrl(
                customerAvatar,
                defaultBucket: 'uploads',
              )
            : '';

        final itemsSummary =
            item['items']?.toString() ?? '${item['item_count'] ?? 1} item(s)';

        mappedOrders.add({
          'customerName': customerName.isNotEmpty ? customerName : 'Customer',
          'customerImage': safeCustomerAvatar.isNotEmpty
              ? safeCustomerAvatar
              : '',
          'orderId':
              item['order_number'] ?? item['order_id']?.toString() ?? 'AD-0000',
          'rawOrderId': item['order_id'] ?? item['order_number'],
          'customerId': item['customer_id']?.toString() ?? '',
          'deliveryAddressId': item['delivery_address_id']?.toString(),
          'paymentMethod': item['payment_method']?.toString(),
          'subtotal': (item['subtotal'] as num?)?.toDouble() ?? rawTotal,
          'deliveryFee': (item['delivery_fee'] as num?)?.toDouble() ?? 0.0,
          'timeAgo': _formatTimeAgo(createdAt),
          'items': itemsSummary,
          'total': '₱${rawTotal.toStringAsFixed(2)}',
          'rawTotal': rawTotal,
          'createdAt': createdAt,
          'status': statusCode,
          'statusColor': _getStatusColor(statusCode),
          'specialInstructions': item['special_instructions']?.toString(),
        });
        debugPrint(
          '📦 Mapped Order: ${mappedOrders.last['orderId']} - AddressID: ${mappedOrders.last['deliveryAddressId']} - Method: ${mappedOrders.last['paymentMethod']}',
        );
      }

      return mappedOrders;
    } catch (e) {
      debugPrint('Error fetching farmer orders: $e');
      return [];
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
      case 'PROCESSING':
      case 'SHIPPED':
        return Colors.blue;
      case 'DELIVERED':
        return Colors.green;
      case 'CANCELLED':
      case 'REFUNDED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get farmer profile data for a specific user ID
  Future<Map<String, dynamic>?> getFarmerProfile(String userId) async {
    try {
      final response = await _client
          .from('v_farmer_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error fetching farmer profile: $e');
      return null;
    }
  }

  /// Get farmer profile data for a specific farmer ID
  Future<Map<String, dynamic>?> getFarmerProfileByFarmerId(
    String farmerId,
  ) async {
    try {
      final response = await _client
          .from('v_farmer_profiles')
          .select()
          .eq('farmer_id', farmerId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error fetching farmer profile by farmer id: $e');
      return null;
    }
  }

  /// Get customer's orders
  Future<List<Map<String, dynamic>>> getCustomerOrders() async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('v_orders')
          .select()
          .eq('customer_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map(
            (item) => {
              'orderId': item['order_number'] ?? 'AD-0000',
              'items': item['items'] ?? '',
              'total': '₱${item['total']?.toString() ?? '0'}',
              'status': item['status'] ?? 'PENDING',
              'createdAt': item['created_at'],
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error fetching customer orders: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FARMERS (for consumer home screen)
  // ══════════════════════════════════════════════════════════════════════════

  /// Get featured farmers
  Future<List<Map<String, dynamic>>> getFeaturedFarmers() async {
    try {
      dynamic response;
      try {
        response = await _client
            .from('v_farmer_profiles')
            .select()
            .eq('is_verified', true)
            .eq('is_active', true)
            .order('average_rating', ascending: false)
            .limit(5);
      } on PostgrestException catch (e) {
        final isMissingAverageRatingColumn =
            e.code == '42703' && e.message.contains('average_rating');

        if (!isMissingAverageRatingColumn) rethrow;

        debugPrint(
          'Featured farmers query fallback: average_rating column is missing on v_farmer_profiles.',
        );

        response = await _client
            .from('v_farmer_profiles')
            .select()
            .eq('is_verified', true)
            .eq('is_active', true)
            .limit(5);
      }

      final rows = (response as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final farmers = await Future.wait(
        rows.map((item) async {
          final rawImagePath = item['image_url']?.toString();
          final imageUrl = await SupabaseDatabase.getSafeUrl(
            rawImagePath,
            defaultBucket: 'uploads',
          );

          return {
            'farmerId': item['farmer_id'],
            'farmerUserId': item['user_id'],
            'imageUrl': imageUrl,
            'name': item['farm_name'] ?? 'Farm',
            'distance': 'Nearby',
            'latitude': item['farm_latitude'],
            'longitude': item['farm_longitude'],
            'specialty': item['specialty'] ?? 'Fresh produce',
            'rating': item['average_rating']?.toString() ?? '0.0',
            'badge': item['badge'] ?? 'VERIFIED',
            'tags': <String>['Fresh'],
          };
        }).toList(),
      );

      await _cacheMapList(_featuredFarmersCacheKey, farmers);
      return farmers;
    } catch (e) {
      debugPrint('Error fetching featured farmers: $e');
      return _readCachedMapList(_featuredFarmersCacheKey);
    }
  }

  Future<void> _cacheMapList(
    String key,
    List<Map<String, dynamic>> value,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(value));
    } catch (e) {
      debugPrint('Error writing cache for $key: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _readCachedMapList(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      debugPrint('Error reading cache for $key: $e');
      return [];
    }
  }


  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  /// Look up a farmer_id from a user_id.
  /// Returns null if the user is not a farmer.
  Future<String?> getFarmerIdByUserId(String userId) async {
    try {
      final response = await _client
          .from('farmers')
          .select('farmer_id')
          .eq('user_id', userId)
          .maybeSingle();
      return response?['farmer_id']?.toString();
    } catch (e) {
      debugPrint('Error looking up farmer_id by user_id: $e');
      return null;
    }
  }
}
