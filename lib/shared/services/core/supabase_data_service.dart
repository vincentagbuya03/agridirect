import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'supabase_config.dart';
import '../../data/app_data.dart';

/// Supabase Data Service for fetching products, posts, and articles
/// Replaces the local SQLite ProductDatabaseService
class SupabaseDataService {
  static final SupabaseDataService _instance = SupabaseDataService._internal();
  factory SupabaseDataService() => _instance;
  SupabaseDataService._internal();

  static const String _featuredFarmersCacheKey = 'cache_featured_farmers_v1';
  static const String _forumPostsCacheKey = 'cache_forum_posts_v1';

  final _client = SupabaseConfig.client;

  // ══════════════════════════════════════════════════════════════════════════
  // PRODUCTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get all pre-order products
  Future<List<ProductItem>> getPreOrderProducts() async {
    try {
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

      await _enrichProductItemsWithFarmerProfiles(enrichedItems);

      return enrichedItems.map((item) => _mapToProductItem(item)).toList();
    } catch (e) {
      debugPrint('Error fetching pre-order products: $e');
      return [];
    }
  }

  /// Get all nearby/available products (not pre-order)
  Future<List<ProductItem>> getNearbyProducts() async {
    try {
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
          'is_preorder': item['is_preorder'] ?? false,
          'status': status,
          'image': imageResponse?['image_url'] ?? '',
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
      final response = await _client
          .from('v_farmer_profiles')
          .select('farmer_id, farm_name, farmer_name, avatar_url, image_url')
          .inFilter('farmer_id', farmerIds);

      final profileByFarmerId = {
        for (final row in (response as List))
          (row['farmer_id']?.toString() ?? ''): Map<String, dynamic>.from(
            row as Map,
          ),
      };

      // Fallback: query farmers table directly for any IDs missing from the view.
      final missingFarmerIds = farmerIds
          .where((id) => !profileByFarmerId.containsKey(id))
          .toList();

      if (missingFarmerIds.isNotEmpty) {
        final fallbackResponse = await _client
            .from('farmers')
            .select('farmer_id, farm_name, image_url')
            .inFilter('farmer_id', missingFarmerIds);

        for (final row in (fallbackResponse as List)) {
          final fallback = Map<String, dynamic>.from(row as Map);
          final fallbackFarmerId = fallback['farmer_id']?.toString() ?? '';
          if (fallbackFarmerId.isEmpty) continue;

          profileByFarmerId[fallbackFarmerId] = {
            'farmer_id': fallbackFarmerId,
            'farm_name': fallback['farm_name'],
            'farmer_name': null,
            'avatar_url': null,
            'image_url': fallback['image_url'],
          };
        }
      }

      for (final item in items) {
        final farmerId = item['farmer_id']?.toString() ?? '';
        final profile = profileByFarmerId[farmerId];
        if (profile == null) continue;

        final avatarUrl = (profile['avatar_url']?.toString() ?? '').trim();
        final farmerImageUrl = (profile['image_url']?.toString() ?? '').trim();

        item['farmer_name'] = profile['farmer_name'];
        item['farmer_avatar_url'] = avatarUrl.isNotEmpty
            ? avatarUrl
            : farmerImageUrl;
        if ((item['farm_name']?.toString().trim().isEmpty ?? true)) {
          item['farm_name'] = profile['farm_name'];
        }
      }
    } catch (e) {
      // Keep product loading resilient when farmer profile enrichment fails.
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

  ProductItem _mapToProductItem(Map<String, dynamic> item) {
    return ProductItem(
      productId: item['product_id']?.toString(),
      farmerId: item['farmer_id']?.toString(),
      farmerName: item['farmer_name']?.toString(),
      farmerAvatarUrl: item['farmer_avatar_url']?.toString(),
      name: item['name'] ?? '',
      farm: item['farm_name'] ?? '',
      price: '₱${item['price']?.toString() ?? '0'}',
      unit: item['unit_abbr'] ?? item['unit_name'] ?? '',
      imageUrl: item['image_url'] ?? '',
      imageUrls:
          (item['image_urls'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      rating: item['average_rating']?.toString(),
      reviews: item['review_count']?.toString(),
      harvestDays: item['harvest_days']?.toString(),
      reservedQuantity: (item['reserved_quantity'] as num?)?.toDouble(),
      targetQuantity: (item['target_quantity'] as num?)?.toDouble(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FORUM POSTS
  // ══════════════════════════════════════════════════════════════════════════

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

      final posts = (response as List).map((item) {
        final postId = item['post_id'].toString();
        return _mapToForumPostItem(item, likedPostIds.contains(postId));
      }).toList();

      await _cacheMapList(
        _forumPostsCacheKey,
        posts
            .map(
              (post) => {
                'user_name': post.userName,
                'time': post.time,
                'title': post.title,
                'body': post.body,
                'image_url': post.imageUrl,
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
              userName: item['user_name']?.toString() ?? 'Anonymous',
              time: item['time']?.toString() ?? 'Recently',
              title: item['title']?.toString() ?? '',
              body: item['body']?.toString() ?? '',
              imageUrl: item['image_url']?.toString(),
              likes: _toInt(item['likes']),
              comments: _toInt(item['comments']),
              isLiked: item['is_liked'] == true,
            ),
          )
          .toList();
    }
  }

  /// Add a new forum post
  Future<void> addForumPost(ForumPostItem post) async {
    try {
      final userId = SupabaseConfig.currentUser?.id;

      await _client.from('forum_posts').insert({
        'user_id': userId,
        'title': post.title,
        'body': post.body,
        'image_url': post.imageUrl,
      });
    } catch (e) {
      debugPrint('Error adding forum post: $e');
      rethrow;
    }
  }

  /// Like/Unlike a post
  Future<void> togglePostLike(String postId) async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      if (userId == null) return;

      // Check if already liked
      final existing = await _client
          .from('forum_post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Unlike
        await _client
            .from('forum_post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      } else {
        // Like
        await _client.from('forum_post_likes').insert({
          'post_id': postId,
          'user_id': userId,
        });
      }
    } catch (e) {
      debugPrint('Error toggling post like: $e');
    }
  }

  ForumPostItem _mapToForumPostItem(Map<String, dynamic> item, bool isLiked) {
    final createdAt = DateTime.tryParse(item['created_at'] ?? '');
    final timeAgo = createdAt != null ? _formatTimeAgo(createdAt) : 'Recently';

    return ForumPostItem(
      userName: item['author_name'] ?? 'Anonymous',
      time: timeAgo,
      title: item['title'] ?? '',
      body: item['body'] ?? '',
      imageUrl: item['image_url'],
      likes: item['likes_count'] ?? 0,
      comments: item['comments_count'] ?? 0,
      isLiked: isLiked,
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ARTICLES
  // ══════════════════════════════════════════════════════════════════════════

  /// Get all published articles
  Future<List<ArticleItem>> getArticles() async {
    try {
      final response = await _client
          .from('v_articles')
          .select()
          .eq('published', true)
          .order('created_at', ascending: false);

      return (response as List).map((item) => _mapToArticleItem(item)).toList();
    } catch (e) {
      debugPrint('Error fetching articles: $e');
      return [];
    }
  }

  /// Add a new article
  Future<void> addArticle(ArticleItem article) async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      await _client.from('articles').insert({
        'title': article.title,
        'content': article.excerpt,
        'author_id': userId,
        'read_time': article.readTime,
        'image_url': article.imageUrl,
        'published': true,
      });
    } catch (e) {
      debugPrint('Error adding article: $e');
      rethrow;
    }
  }

  ArticleItem _mapToArticleItem(Map<String, dynamic> item) {
    return ArticleItem(
      title: item['title'] ?? '',
      excerpt: item['excerpt'] ?? '',
      imageUrl: item['image_url'],
      author: item['author_name'] ?? 'AgriDirect',
      readTime: item['read_time'],
    );
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

  /// Get farmer's orders
  Future<List<Map<String, dynamic>>> getFarmerOrders({String? status}) async {
    try {
      final userId = SupabaseConfig.currentUser?.id;
      if (userId == null) return [];

      var query = _client.from('v_orders').select().eq('farmer_id', userId);

      if (status != null && status != 'Active') {
        query = query.eq('status', status.toUpperCase());
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List).map((item) {
        return {
          'customerName': item['customer_name'] ?? 'Customer',
          'customerImage':
              item['customer_image'] ?? 'https://i.pravatar.cc/150?img=1',
          'orderId': item['order_number'] ?? 'AD-0000',
          'timeAgo': _formatTimeAgo(
            DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
          ),
          'items': item['items'] ?? '',
          'total': '₱${item['total']?.toString() ?? '0'}',
          'status': item['status'] ?? 'PENDING',
          'statusColor': Color(item['status_color'] ?? 0xFFFFA500),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching farmer orders: $e');
      return [];
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
      final response = await _client
          .from('v_farmer_profiles')
          .select()
          .eq('is_verified', true)
          .eq('is_active', true)
          .order('average_rating', ascending: false)
          .limit(5);

      final farmers = (response as List).map((item) {
        final rawImageUrl = item['image_url']?.toString();
        final imageUrl = _isValidAbsoluteUrl(rawImageUrl) ? rawImageUrl : '';

        return {
          'farmerId': item['farmer_id'],
          'farmerUserId': item['user_id'],
          'imageUrl': imageUrl,
          'name': item['farm_name'] ?? 'Farm',
          'distance': 'Nearby',
          'specialty': item['specialty'] ?? 'Fresh produce',
          'rating': item['average_rating']?.toString() ?? '0.0',
          'badge': item['badge'] ?? 'VERIFIED',
          'tags': <String>['Fresh'],
        };
      }).toList();

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

  bool _isValidAbsoluteUrl(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return false;
    final uri = Uri.tryParse(text);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}
