import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../community/notification_service.dart';

class FollowService {
  FollowService._();

  static final FollowService _instance = FollowService._();

  factory FollowService() => _instance;

  final SupabaseClient _client = Supabase.instance.client;
  final NotificationService _notifications = NotificationService();

  String? get _currentUserId => _client.auth.currentUser?.id;

  Future<String?> getCurrentFarmerId() async {
    final userId = _currentUserId;
    if (userId == null || userId.trim().isEmpty) return null;

    try {
      final farmer = await _client
          .from('farmers')
          .select('farmer_id')
          .eq('user_id', userId)
          .maybeSingle();
      return farmer?['farmer_id']?.toString();
    } catch (e) {
      debugPrint('Error resolving current farmer id: $e');
      return null;
    }
  }

  Future<bool> isFollowingFarmer(String farmerId) async {
    final userId = _currentUserId;
    if (userId == null || farmerId.trim().isEmpty) return false;

    try {
      final row = await _client
          .from('farmer_follows')
          .select('farmer_id')
          .eq('follower_user_id', userId)
          .eq('farmer_id', farmerId)
          .maybeSingle();
      return row != null;
    } catch (e) {
      debugPrint('Error checking follow state: $e');
      return false;
    }
  }

  Future<int> getFollowerCount(String farmerId) async {
    if (farmerId.trim().isEmpty) return 0;

    try {
      final rows = await _client
          .from('farmer_follows')
          .select('follower_user_id')
          .eq('farmer_id', farmerId);
      return (rows as List).length;
    } catch (e) {
      debugPrint('Error loading follower count: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getFollowersForFarmer({
    String? farmerId,
  }) async {
    final targetFarmerId =
        (farmerId?.trim().isNotEmpty == true ? farmerId!.trim() : null) ??
        await getCurrentFarmerId();
    if (targetFarmerId == null || targetFarmerId.isEmpty) return [];

    try {
      final followRows = await _client
          .from('farmer_follows')
          .select('follower_user_id, created_at')
          .eq('farmer_id', targetFarmerId)
          .order('created_at', ascending: false);

      final followerRows = (followRows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
      if (followerRows.isEmpty) return [];

      final followerUserIds = followerRows
          .map((row) => row['follower_user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);

      final userRows = await _client
          .from('users')
          .select('user_id, name, email, avatar_url')
          .inFilter('user_id', followerUserIds);

      final usersById = {
        for (final row in (userRows as List))
          row['user_id'].toString(): Map<String, dynamic>.from(row as Map),
      };

      return followerRows
          .map((row) {
            final followerUserId = row['follower_user_id']?.toString() ?? '';
            final user = usersById[followerUserId] ?? <String, dynamic>{};
            return {
              'userId': followerUserId,
              'name': user['name']?.toString() ?? 'Customer',
              'email': user['email']?.toString() ?? '',
              'avatarUrl': user['avatar_url']?.toString() ?? '',
              'followedAt': DateTime.tryParse(
                row['created_at']?.toString() ?? '',
              ),
            };
          })
          .toList(growable: false);
    } catch (e) {
      debugPrint('Error loading followers for farmer: $e');
      return [];
    }
  }

  Future<int> getFollowingCount({String? userId}) async {
    final targetUserId = (userId ?? _currentUserId)?.trim() ?? '';
    if (targetUserId.isEmpty) return 0;

    try {
      final rows = await _client
          .from('farmer_follows')
          .select('farmer_id')
          .eq('follower_user_id', targetUserId);
      return (rows as List).length;
    } catch (e) {
      debugPrint('Error loading following count: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> getFollowState(String farmerId) async {
    final results = await Future.wait<dynamic>([
      getFollowerCount(farmerId),
      isFollowingFarmer(farmerId),
      getFollowingCount(),
    ]);

    return {
      'followers': results[0] as int,
      'isFollowing': results[1] as bool,
      'following': results[2] as int,
    };
  }

  Future<bool> toggleFollowFarmer({
    required String farmerId,
    String? farmerUserId,
    String? farmName,
  }) async {
    final userId = _currentUserId;
    if (userId == null || farmerId.trim().isEmpty) {
      throw Exception('Please sign in first.');
    }

    final isFollowing = await isFollowingFarmer(farmerId);
    if (isFollowing) {
      await _client
          .from('farmer_follows')
          .delete()
          .eq('follower_user_id', userId)
          .eq('farmer_id', farmerId);
      return false;
    }

    await _client.from('farmer_follows').insert({
      'follower_user_id': userId,
      'farmer_id': farmerId,
    });

    final targetFarmerUserId = farmerUserId?.trim() ?? '';
    if (targetFarmerUserId.isNotEmpty && targetFarmerUserId != userId) {
      await _notifications.insertNotification(
        userId: targetFarmerUserId,
        title: 'New follower',
        content:
            'A customer started following ${farmName?.trim().isNotEmpty == true ? farmName!.trim() : 'your farm'}.',
        type: 'system',
        linkType: 'home',
      );
    }

    return true;
  }

  Future<List<Map<String, dynamic>>> getFollowingUpdates({
    int limit = 8,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final followRows = await _client
          .from('farmer_follows')
          .select('farmer_id')
          .eq('follower_user_id', userId)
          .order('created_at', ascending: false);

      final farmerIds = (followRows as List)
          .map((row) => row['farmer_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (farmerIds.isEmpty) return [];

      final profilesResponse = await _client
          .from('v_farmer_profiles')
          .select('farmer_id, user_id, farm_name, image_url, avatar_url')
          .inFilter('farmer_id', farmerIds);

      final profilesByFarmerId = {
        for (final row in (profilesResponse as List))
          row['farmer_id'].toString(): Map<String, dynamic>.from(row as Map),
      };

      final farmerUserIds = profilesByFarmerId.values
          .map((row) => row['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final productRows = await _client
          .from('v_products')
          .select(
            'product_id, farmer_id, name, price, is_preorder, created_at, category_name',
          )
          .inFilter('farmer_id', farmerIds)
          .order('created_at', ascending: false)
          .limit(limit);

      final productIds = (productRows as List)
          .map((row) => row['product_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      final productImages = <String, String>{};
      if (productIds.isNotEmpty) {
        final imageRows = await _client
            .from('product_images')
            .select('product_id, image_url, sort_order')
            .inFilter('product_id', productIds)
            .order('sort_order', ascending: true);

        for (final row in (imageRows as List)) {
          final productId = row['product_id']?.toString() ?? '';
          if (productId.isEmpty || productImages.containsKey(productId)) {
            continue;
          }
          productImages[productId] = row['image_url']?.toString() ?? '';
        }
      }

      List<dynamic> postRows = [];
      if (farmerUserIds.isNotEmpty) {
        postRows = await _client
            .from('v_forum_posts')
            .select(
              'post_id, user_id, title, body, image_url, video_url, created_at, author_name, likes_count, comments_count',
            )
            .inFilter('user_id', farmerUserIds)
            .order('created_at', ascending: false)
            .limit(limit);
      }

      final updates = <Map<String, dynamic>>[];

      for (final raw in productRows) {
        final row = Map<String, dynamic>.from(raw as Map);
        final farmerId = row['farmer_id']?.toString() ?? '';
        final profile = profilesByFarmerId[farmerId];
        updates.add({
          'type': 'product',
          'productId': row['product_id']?.toString(),
          'farmerId': farmerId,
          'farmerUserId': profile?['user_id']?.toString(),
          'farmerName': profile?['farm_name']?.toString() ?? 'Farm',
          'title': row['name']?.toString() ?? 'New product',
          'subtitle':
              (row['category_name']?.toString().trim().isNotEmpty ?? false)
              ? row['category_name'].toString()
              : 'Fresh produce',
          'price': row['price'],
          'isPreorder': row['is_preorder'] == true,
          'imageUrl': productImages[row['product_id']?.toString() ?? ''] ?? '',
          'createdAt': DateTime.tryParse(row['created_at']?.toString() ?? ''),
        });
      }

      for (final raw in postRows) {
        final row = Map<String, dynamic>.from(raw as Map);
        final userIdForPost = row['user_id']?.toString() ?? '';
        Map<String, dynamic>? profile;
        for (final item in profilesByFarmerId.values) {
          if (item['user_id']?.toString() == userIdForPost) {
            profile = item;
            break;
          }
        }

        updates.add({
          'type': 'post',
          'postId': row['post_id']?.toString(),
          'farmerId': profile?['farmer_id']?.toString(),
          'farmerUserId': userIdForPost,
          'farmerName':
              profile?['farm_name']?.toString() ??
              row['author_name']?.toString() ??
              'Farmer',
          'title': row['title']?.toString() ?? '',
          'body': row['body']?.toString() ?? '',
          'imageUrl': row['image_url']?.toString() ?? '',
          'videoUrl': row['video_url']?.toString() ?? '',
          'likes': (row['likes_count'] as num?)?.toInt() ?? 0,
          'comments': (row['comments_count'] as num?)?.toInt() ?? 0,
          'createdAt': DateTime.tryParse(row['created_at']?.toString() ?? ''),
        });
      }

      updates.sort((a, b) {
        final aTime = a['createdAt'] as DateTime?;
        final bTime = b['createdAt'] as DateTime?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return updates.take(limit).toList(growable: false);
    } catch (e) {
      debugPrint('Error loading following updates: $e');
      return [];
    }
  }

  Future<void> notifyFollowersAboutNewProduct({
    required String farmerId,
    required String productId,
    required String productName,
    required String farmName,
  }) async {
    try {
      final rows = await _client
          .from('farmer_follows')
          .select('follower_user_id')
          .eq('farmer_id', farmerId);

      for (final row in (rows as List)) {
        final followerUserId = row['follower_user_id']?.toString() ?? '';
        if (followerUserId.isEmpty) continue;
        await _notifications.insertNotification(
          userId: followerUserId,
          title: 'New product from $farmName',
          content: '$productName is now available.',
          type: 'system',
          linkType: 'product',
          linkId: productId,
        );
      }
    } catch (e) {
      debugPrint('Error notifying followers about new product: $e');
    }
  }

  Future<void> notifyFollowersAboutNewPost({
    required String farmerId,
    required String postId,
    required String farmName,
    required String postTitle,
  }) async {
    try {
      final rows = await _client
          .from('farmer_follows')
          .select('follower_user_id')
          .eq('farmer_id', farmerId);

      final trimmedTitle = postTitle.trim();
      final message = trimmedTitle.isEmpty
          ? '$farmName shared a new community update.'
          : '$farmName posted: $trimmedTitle';

      for (final row in (rows as List)) {
        final followerUserId = row['follower_user_id']?.toString() ?? '';
        if (followerUserId.isEmpty) continue;
        await _notifications.insertNotification(
          userId: followerUserId,
          title: 'New post from $farmName',
          content: message,
          type: 'system',
          linkType: 'post',
          linkId: postId,
        );
      }
    } catch (e) {
      debugPrint('Error notifying followers about new post: $e');
    }
  }
}
