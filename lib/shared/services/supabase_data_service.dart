import 'package:flutter/material.dart';
import 'config/supabase_config.dart';
import '../data/app_data.dart';

/// Supabase Data Service for fetching products, posts, and articles
/// Replaces the local SQLite ProductDatabaseService
class SupabaseDataService {
  static final SupabaseDataService _instance = SupabaseDataService._internal();
  factory SupabaseDataService() => _instance;
  SupabaseDataService._internal();

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

      return (response as List).map((item) => _mapToProductItem(item)).toList();
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

      return (response as List).map((item) => _mapToProductItem(item)).toList();
    } catch (e) {
      debugPrint('Error fetching nearby products: $e');
      return [];
    }
  }

  /// Get all products
  Future<List<ProductItem>> getAllProducts() async {
    try {
      final response = await _client
          .from('v_products')
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((item) => _mapToProductItem(item)).toList();
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

      final response = await _client
          .from('v_products')
          .select()
          .eq('farmer_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((item) {
        final price = (item['price'] as num?)?.toDouble() ?? 0;
        final reviewCount = item['review_count'] ?? 0;
        String status = 'IN STOCK';
        if (reviewCount == 0) {
          status = 'NEW';
        }

        return {
          'id': item['product_id'],
          'name': item['name'] ?? '',
          'price': price,
          'unit': item['unit_abbr'] ?? item['unit_name'] ?? 'kg',
          'available': reviewCount,
          'harvest': item['harvest_days'] != null 
              ? 'In ${item['harvest_days']} days'
              : 'Ready',
          'status': status,
          'image': item['image_url'] ?? '',
        };
      }).toList();
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

      return (response as List).map((item) => _mapToProductItem(item)).toList();
    } catch (e) {
      debugPrint('Error fetching products by category: $e');
      return [];
    }
  }

  /// Add a new product
  Future<void> addProduct(ProductItem product, {bool isPreOrder = false}) async {
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
        'price': double.tryParse(product.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0,
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

  ProductItem _mapToProductItem(Map<String, dynamic> item) {
    return ProductItem(
      name: item['name'] ?? '',
      farm: item['farm_name'] ?? '',
      price: '₱${item['price']?.toString() ?? '0'}',
      unit: item['unit_abbr'] ?? item['unit_name'] ?? '',
      imageUrl: item['image_url'] ?? '',
      rating: item['average_rating']?.toString(),
      reviews: item['review_count']?.toString(),
      harvestDays: item['harvest_days']?.toString(),
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
            .from('post_likes')
            .select('post_id')
            .eq('user_id', userId);
        likedPostIds = (likes as List).map((l) => l['post_id'].toString()).toList();
      }

      return (response as List).map((item) {
        final postId = item['post_id'].toString();
        return _mapToForumPostItem(item, likedPostIds.contains(postId));
      }).toList();
    } catch (e) {
      debugPrint('Error fetching forum posts: $e');
      return [];
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
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Unlike
        await _client
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      } else {
        // Like
        await _client.from('post_likes').insert({
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
      final preOrders = productList.where((p) => p['is_preorder'] == true).length;
      
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

      var query = _client
          .from('v_orders')
          .select()
          .eq('farmer_id', userId);

      if (status != null && status != 'Active') {
        query = query.eq('status', status.toUpperCase());
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List).map((item) {
        return {
          'customerName': item['customer_name'] ?? 'Customer',
          'customerImage': item['customer_image'] ?? 'https://i.pravatar.cc/150?img=1',
          'orderId': item['order_number'] ?? 'AD-0000',
          'timeAgo': _formatTimeAgo(DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now()),
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

      return (response as List).map((item) => {
        'orderId': item['order_number'] ?? 'AD-0000',
        'items': item['items'] ?? '',
        'total': '₱${item['total']?.toString() ?? '0'}',
        'status': item['status'] ?? 'PENDING',
        'createdAt': item['created_at'],
      }).toList();
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
          .order('average_rating', ascending: false)
          .limit(5);

      return (response as List).map((item) => {
        'imageUrl': item['image_url'] ?? 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=600',
        'name': item['farm_name'] ?? 'Farm',
        'distance': 'Nearby',
        'specialty': item['specialty'] ?? 'Fresh produce',
        'rating': item['average_rating']?.toString() ?? '4.5',
        'badge': item['badge'] ?? 'VERIFIED',
        'tags': <String>['Fresh'],
      }).toList();
    } catch (e) {
      debugPrint('Error fetching featured farmers: $e');
      // Return default farmers if Supabase fails
      return [
        {
          'imageUrl': 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=600',
          'name': 'Green Valley Organic',
          'distance': '2.4 miles away',
          'specialty': 'Specializes in root veggies',
          'rating': '4.9',
          'badge': 'TOP RATED',
          'tags': ['Carrots', 'Potatoes', 'Kale'],
        },
        {
          'imageUrl': 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=600',
          'name': 'Sunny Orchards',
          'distance': '5.1 miles away',
          'specialty': 'Fresh seasonal fruits',
          'rating': '4.7',
          'badge': 'ORGANIC',
          'tags': ['Strawberries', 'Apples'],
        },
        {
          'imageUrl': 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=600',
          'name': 'Valley Harvest',
          'distance': '3.8 miles away',
          'specialty': 'Mixed seasonal produce',
          'rating': '4.6',
          'badge': 'LOCAL PICK',
          'tags': ['Tomatoes', 'Peppers', 'Herbs'],
        },
      ];
    }
  }
}
