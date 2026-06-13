import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/supabase_config.dart';

/// Admin Service - Handles all admin operations
class AdminService extends ChangeNotifier {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal() {
    _initializeAdmin();
  }

  void _initializeAdmin() {
    final currentUserId = _client.auth.currentUser?.id;
    debugPrint('🔵 AdminService initialized for user: $currentUserId');
  }

  final _client = SupabaseConfig.client;

  bool _isLoading = false;
  String? _errorMessage;
  String? _currentAdminId;

  final ValueNotifier<int> _dataVersion = ValueNotifier<int>(0);
  ValueListenable<int> get dataVersionListenable => _dataVersion;

  void _notifyDataChanged() {
    _dataVersion.value++;
    notifyListeners();
  }

  Future<String?> _resolveCurrentAdminId() async {
    if (_currentAdminId != null && _currentAdminId!.trim().isNotEmpty) {
      return _currentAdminId;
    }

    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      return null;
    }

    try {
      final adminRecord = await _client
          .from('admins')
          .select('admin_id')
          .eq('user_id', currentUserId)
          .maybeSingle();

      final adminId = adminRecord?['admin_id']?.toString();
      if (adminId != null && adminId.isNotEmpty) {
        _currentAdminId = adminId;
        return adminId;
      }
    } catch (e) {
      debugPrint('Failed to resolve current admin_id: $e');
    }

    return null;
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<String?> getCurrentAdminId() => _resolveCurrentAdminId();

  String _formatContentTypeLabel(String code) {
    switch (code) {
      case 'post':
        return 'Post';
      case 'comment':
        return 'Comment';
      case 'product':
        return 'Product';
      case 'review':
        return 'Review';
      case 'article':
        return 'Article';
      default:
        return 'Content';
    }
  }

  Future<Map<int, Map<String, dynamic>>> _getContentTypeMap() async {
    final response = await _client
        .from('content_types')
        .select('content_type_id, code, description');

    return {
      for (final row in (response as List))
        (row['content_type_id'] as int): Map<String, dynamic>.from(row as Map),
    };
  }

  Future<Map<String, String>> _getUserNamesById(List<String> userIds) async {
    if (userIds.isEmpty) return {};

    final response = await _client
        .from('users')
        .select('user_id, name')
        .inFilter('user_id', userIds);

    return {
      for (final row in (response as List))
        row['user_id']?.toString() ?? '':
            row['name']?.toString() ?? 'Unknown user',
    };
  }

  Future<Map<String, Map<String, dynamic>>> _getForumPostsById(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return {};

    final response = await _client
        .from('v_forum_posts')
        .select('post_id, user_id, author_name, title, body')
        .inFilter('post_id', postIds);

    return {
      for (final row in (response as List))
        row['post_id']?.toString() ?? '': Map<String, dynamic>.from(row as Map),
    };
  }

  Future<Map<String, Map<String, dynamic>>> _getForumCommentsById(
    List<String> commentIds,
  ) async {
    if (commentIds.isEmpty) return {};

    final response = await _client
        .from('forum_comments')
        .select('comment_id, body, user_id, post_id')
        .inFilter('comment_id', commentIds);

    return {
      for (final row in (response as List))
        row['comment_id']?.toString() ?? '': Map<String, dynamic>.from(
          row as Map,
        ),
    };
  }

  Future<Map<String, Map<String, dynamic>>> _getProductsById(
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) return {};

    final response = await _client
        .from('v_products')
        .select(
          'product_id, name, description, farmer_name, farmer_id, farm_name',
        )
        .inFilter('product_id', productIds);

    return {
      for (final row in (response as List))
        row['product_id']?.toString() ?? '': Map<String, dynamic>.from(
          row as Map,
        ),
    };
  }

  Future<Map<String, Map<String, dynamic>>> _getReviewsById(
    List<String> reviewIds,
  ) async {
    if (reviewIds.isEmpty) return {};

    final response = await _client
        .from('product_reviews')
        .select('review_id, review_text, rating, product_id, customer_id')
        .inFilter('review_id', reviewIds);

    final rows = (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    final customerIds = rows
        .map((row) => row['customer_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    final customerResponse = customerIds.isEmpty
        ? <dynamic>[]
        : await _client
              .from('customers')
              .select('customer_id, user_id')
              .inFilter('customer_id', customerIds);

    final customerToUserId = <String, String>{};
    for (final row in customerResponse) {
      final customerId = row['customer_id']?.toString();
      final userId = row['user_id']?.toString();
      if (customerId != null && userId != null) {
        customerToUserId[customerId] = userId;
      }
    }

    final userNames = await _getUserNamesById(
      customerToUserId.values.toSet().toList(),
    );
    final productsById = await _getProductsById(
      rows
          .map((row) => row['product_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList(),
    );

    final result = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final customerId = row['customer_id']?.toString();
      final userId = customerId == null ? null : customerToUserId[customerId];
      final productId = row['product_id']?.toString();
      final product = productId == null ? null : productsById[productId];

      row['user_id'] = userId;
      row['reviewer_name'] = userId == null
          ? 'Customer'
          : (userNames[userId] ?? 'Customer');
      row['product_name'] = product?['name'] ?? 'Product';
      result[row['review_id']?.toString() ?? ''] = row;
    }

    return result;
  }

  Future<Map<String, Map<String, dynamic>>> _getArticlesById(
    List<String> articleIds,
  ) async {
    if (articleIds.isEmpty) return {};

    final response = await _client
        .from('admin_articles')
        .select('article_id, title, summary, body, admin_id')
        .inFilter('article_id', articleIds);

    final rows = (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final adminIds = rows
        .map((row) => row['admin_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    final adminToUserId = <String, String>{};
    if (adminIds.isNotEmpty) {
      final adminResponse = await _client
          .from('admins')
          .select('admin_id, user_id')
          .inFilter('admin_id', adminIds);

      for (final row in (adminResponse as List)) {
        final adminId = row['admin_id']?.toString();
        final userId = row['user_id']?.toString();
        if (adminId != null &&
            adminId.isNotEmpty &&
            userId != null &&
            userId.isNotEmpty) {
          adminToUserId[adminId] = userId;
        }
      }
    }

    final userNames = await _getUserNamesById(
      adminToUserId.values.toSet().toList(),
    );
    final result = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final adminId = row['admin_id']?.toString();
      final userId = adminId == null ? null : adminToUserId[adminId];
      row['user_id'] = userId;
      row['author_name'] = userId == null
          ? 'AgriDirect'
          : (userNames[userId] ?? 'AgriDirect');
      result[row['article_id']?.toString() ?? ''] = row;
    }

    return result;
  }

  Map<String, dynamic>? _normalizeUserRelation(dynamic rawUsers) {
    if (rawUsers is Map<String, dynamic>) {
      return rawUsers;
    }
    if (rawUsers is List && rawUsers.isNotEmpty) {
      final first = rawUsers.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
    }
    return null;
  }

  String _buildApplicantName({
    dynamic name,
    dynamic email,
    dynamic farmName,
    dynamic userId,
  }) {
    final cleanName = (name ?? '').toString().trim();
    if (cleanName.isNotEmpty) return cleanName;

    final cleanEmail = (email ?? '').toString().trim();
    if (cleanEmail.contains('@')) {
      final base = cleanEmail.split('@').first;
      final words = base
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ')
          .trim()
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .map((e) => e[0].toUpperCase() + e.substring(1))
          .join(' ');
      if (words.isNotEmpty) return words;
    }

    final cleanFarmName = (farmName ?? '').toString().trim();
    if (cleanFarmName.isNotEmpty) return cleanFarmName;

    final cleanUserId = (userId ?? '').toString().trim();
    if (cleanUserId.isNotEmpty) {
      final suffix = cleanUserId.length >= 6
          ? cleanUserId.substring(cleanUserId.length - 6)
          : cleanUserId;
      return 'Applicant $suffix';
    }

    return 'Farmer Applicant';
  }

  String _normalizeRegistrationStatus(dynamic rawStatus) {
    final status = (rawStatus ?? '').toString().trim().toLowerCase();
    if (status == 'approved' || status == 'rejected' || status == 'pending') {
      return status;
    }
    return 'pending';
  }

  Future<List<Map<String, dynamic>>> _hydrateWithUserProfiles(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return rows;

    final userIds = rows
        .map((r) => (r['user_id'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (userIds.isEmpty) return rows;

    try {
      final usersById = <String, Map<String, dynamic>>{};

      try {
        final usersResponse = await _client
            .from('users')
            .select('user_id, name, email, phone, avatar_url')
            .inFilter('user_id', userIds);

        for (final raw in (usersResponse as List)) {
          if (raw is Map<String, dynamic>) {
            final id = (raw['user_id'] ?? '').toString().trim();
            if (id.isNotEmpty) usersById[id] = raw;
          }
        }
      } catch (e) {
        debugPrint('Bulk users lookup failed, trying role-aware view: $e');
      }

      final missingUserIds = userIds
          .where((id) => !usersById.containsKey(id))
          .toList();
      if (missingUserIds.isNotEmpty) {
        try {
          final fallbackResponse = await _client
              .from('v_users_with_roles')
              .select('user_id, name, email, phone, avatar_url')
              .inFilter('user_id', missingUserIds);

          for (final raw in (fallbackResponse as List)) {
            if (raw is Map<String, dynamic>) {
              final id = (raw['user_id'] ?? '').toString().trim();
              if (id.isNotEmpty) {
                usersById[id] = {
                  'user_id': raw['user_id'],
                  'name': raw['name'],
                  'email': raw['email'],
                  'phone': raw['phone'],
                  'avatar_url': raw['avatar_url'],
                };
              }
            }
          }
        } catch (e) {
          debugPrint('Bulk fallback user lookup failed: $e');
        }
      }

      return rows.map((row) {
        final userId = (row['user_id'] ?? '').toString().trim();
        final linkedUser =
            usersById[userId] ?? _normalizeUserRelation(row['users']);

        final resolvedEmail =
            row['email'] ?? row['farmer_email'] ?? linkedUser?['email'];
        final resolvedPhone =
            row['phone'] ?? row['farmer_phone'] ?? linkedUser?['phone'];
        final resolvedAvatar = row['avatar_url'] ?? linkedUser?['avatar_url'];

        final resolvedName = _buildApplicantName(
          name:
              linkedUser?['name'] ??
              row['name'] ??
              row['farmer_name'] ??
              row['applicant_name'],
          email: resolvedEmail,
          farmName: row['farm_name'],
          userId: userId,
        );

        return {
          ...row,
          'users': linkedUser,
          'name': resolvedName,
          'applicant_name': resolvedName,
          'farmer_name': resolvedName,
          'email': resolvedEmail,
          'farmer_email': resolvedEmail,
          'phone': resolvedPhone,
          'farmer_phone': resolvedPhone,
          'avatar_url': resolvedAvatar,
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to hydrate farmer user profiles: $e');
      return rows;
    }
  }

  /// Check if current user is admin
  Future<bool> isUserAdmin(String userId) async {
    try {
      return await SupabaseDatabase.hasRole(userId: userId, roleName: 'admin');
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  /// Get dashboard statistics
  Future<Map<String, dynamic>?> getDashboardStats() async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _client.rpc('get_admin_stats');

      _isLoading = false;
      notifyListeners();
      return response as Map<String, dynamic>;
    } catch (e) {
      _errorMessage = 'Failed to load dashboard stats: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Get all users with pagination
  Future<List<Map<String, dynamic>>> getAllUsers({
    int page = 0,
    int pageSize = 20,
    String? searchQuery,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Query the role-aware view so admin pages receive the same user rows
      // even when row-level security limits direct access to users.
      var query = _client
          .from('v_users_with_roles')
          .select('*')
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      final response = await query;

      _isLoading = false;
      notifyListeners();

      // Filter locally if search query provided
      List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(
        response,
      );

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        results = results.where((user) {
          final name = (user['name'] ?? '').toString().toLowerCase();
          final email = (user['email'] ?? '').toString().toLowerCase();
          return name.contains(query) || email.contains(query);
        }).toList();
      }

      // Normalize the role name used by the UI.
      for (final user in results) {
        final roleName = (user['role_name'] ?? '').toString().toLowerCase();
        if (roleName == 'admin') {
          user['role'] = 'admin';
        } else if (roleName == 'customer') {
          user['role'] = 'customer';
        } else if (roleName.isNotEmpty) {
          user['role'] = roleName;
        } else {
          user['role'] = 'customer';
        }
      }

      return results;
    } catch (e) {
      _errorMessage = 'Failed to load users. Please try again later.';
      _isLoading = false;
      notifyListeners();
      debugPrint('Get users error: $e');
      return [];
    }
  }

  /// Delete user by ID
  Future<bool> deleteUser(String userId) async {
    try {
      // Soft delete - mark user as inactive instead of hard delete
      await _client
          .from('users')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      await _logAdminAction('delete_user', 'User marked as inactive', userId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete user. Please try again.';
      debugPrint('Delete user error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Update user role (promote/demote)
  Future<bool> updateUserRole({
    required String userId,
    required String newRole,
  }) async {
    try {
      if (newRole == 'admin') {
        await SupabaseDatabase.addUserRole(userId: userId, roleName: 'admin');
      } else if (newRole == 'consumer') {
        await SupabaseDatabase.removeUserRole(
          userId: userId,
          roleName: 'admin',
        );
      }

      await _logAdminAction(
        'update_user_role',
        'User role changed to $newRole',
        userId,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update user role. Please try again.';
      debugPrint('Update role error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Deactivate user
  Future<bool> deactivateUser(String userId) async {
    try {
      await _client
          .from('users')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      await _logAdminAction(
        'deactivate_user',
        'User account deactivated',
        userId,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to deactivate user.';
      debugPrint('Deactivate user error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Reactivate user
  Future<bool> reactivateUser(String userId) async {
    try {
      await _client
          .from('users')
          .update({
            'is_active': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      await _logAdminAction(
        'reactivate_user',
        'User account reactivated',
        userId,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to reactivate user.';
      debugPrint('Reactivate user error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Get all products with pagination
  Future<List<Map<String, dynamic>>> getAllProducts({
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _client
          .from('v_products')
          .select(
            'product_id, name, farm_name, price, average_rating, review_count, is_preorder, farmer_id, created_at, is_active, is_featured, category_name, stock_quantity, image_url, unit_abbr',
          )
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      _isLoading = false;
      notifyListeners();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _errorMessage = 'Failed to load products: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Get all orders with pagination
  Future<List<Map<String, dynamic>>> getAllOrders({
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _client
          .from('v_orders')
          .select(
            'order_id, order_number, total:total_amount, status:status_code, created_at, customer_name',
          )
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      _isLoading = false;
      notifyListeners();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _errorMessage = 'Failed to load orders: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Get forum posts with pagination
  Future<List<Map<String, dynamic>>> getForumPosts({
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _client
          .from('v_forum_posts')
          .select(
            'post_id, author_name, title, likes_count, comments_count, created_at',
          )
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      _isLoading = false;
      notifyListeners();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _errorMessage = 'Failed to load forum posts: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Get reported content
  Future<List<Map<String, dynamic>>> getReportedContent({
    String status = 'pending',
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _client
          .from('reported_content')
          .select(
            'report_id, content_id, content_type_id, reporter_id, reason, description, status, resolution_notes, created_at, resolved_at',
          )
          .eq('status', status)
          .order('created_at', ascending: false);

      final reports = List<Map<String, dynamic>>.from(response);
      final contentTypes = await _getContentTypeMap();
      final reporterNames = await _getUserNamesById(
        reports
            .map((report) => report['reporter_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList(),
      );

      final postIds = <String>[];
      final commentIds = <String>[];
      final productIds = <String>[];
      final reviewIds = <String>[];
      final articleIds = <String>[];

      for (final report in reports) {
        final contentId = report['content_id']?.toString();
        final contentTypeId = (report['content_type_id'] as num?)?.toInt();
        final typeCode = contentTypes[contentTypeId]?['code'];

        if (contentId == null || contentId.isEmpty) continue;
        if (typeCode == 'post') postIds.add(contentId);
        if (typeCode == 'comment') commentIds.add(contentId);
        if (typeCode == 'product') productIds.add(contentId);
        if (typeCode == 'review') reviewIds.add(contentId);
        if (typeCode == 'article') articleIds.add(contentId);
      }

      final postsById = await _getForumPostsById(postIds);
      final commentsById = await _getForumCommentsById(commentIds);
      final productsById = await _getProductsById(productIds);
      final reviewsById = await _getReviewsById(reviewIds);
      final articlesById = await _getArticlesById(articleIds);
      final commentOwnerNames = await _getUserNamesById(
        commentsById.values
            .map((comment) => comment['user_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList(),
      );

      _isLoading = false;
      notifyListeners();
      return reports.map((report) {
        final enriched = Map<String, dynamic>.from(report);
        final contentTypeId = (report['content_type_id'] as num?)?.toInt();
        final type = contentTypes[contentTypeId];
        final typeCode = type?['code']?.toString() ?? 'unknown';
        final contentId = report['content_id']?.toString() ?? '';
        final reporterId = report['reporter_id']?.toString() ?? '';

        enriched['content_type_code'] = typeCode;
        enriched['content_type_label'] = _formatContentTypeLabel(typeCode);
        enriched['reporter_name'] = reporterNames[reporterId] ?? 'Unknown user';

        if (typeCode == 'post') {
          final post = postsById[contentId];
          enriched['content_title'] = post?['title'] ?? 'Forum post';
          enriched['content_preview'] = post?['body'] ?? '';
          enriched['content_owner_name'] = post?['author_name'] ?? 'Unknown';
          enriched['content_owner_user_id'] = post?['user_id']?.toString();
        } else if (typeCode == 'comment') {
          final comment = commentsById[contentId];
          enriched['content_title'] = 'Comment';
          enriched['content_preview'] = comment?['body'] ?? '';
          enriched['content_owner_name'] =
              comment?['user_id']?.toString() == null
              ? 'Unknown'
              : (commentOwnerNames[comment!['user_id']?.toString() ?? ''] ??
                    'Unknown');
          enriched['content_owner_user_id'] = comment?['user_id']?.toString();
        } else if (typeCode == 'product') {
          final product = productsById[contentId];
          enriched['content_title'] = product?['name'] ?? 'Product';
          enriched['content_preview'] = product?['description'] ?? '';
          enriched['content_owner_name'] =
              product?['farmer_name'] ?? product?['farm_name'] ?? 'Unknown';
          enriched['content_owner_user_id'] = product?['farmer_id']?.toString();
        } else if (typeCode == 'review') {
          final review = reviewsById[contentId];
          final rating = (review?['rating'] as num?)?.toDouble();
          final reviewText = review?['review_text']?.toString() ?? '';
          enriched['content_title'] =
              'Review for ${review?['product_name'] ?? 'Product'}';
          enriched['content_preview'] = reviewText.isNotEmpty
              ? reviewText
              : (rating == null ? '' : 'Rating: ${rating.toStringAsFixed(1)}');
          enriched['content_owner_name'] =
              review?['reviewer_name'] ?? 'Customer';
          enriched['content_owner_user_id'] = review?['user_id']?.toString();
        } else if (typeCode == 'article') {
          final article = articlesById[contentId];
          enriched['content_title'] = article?['title'] ?? 'Article';
          enriched['content_preview'] =
              article?['summary'] ?? article?['body'] ?? '';
          enriched['content_owner_name'] =
              article?['author_name'] ?? 'AgriDirect';
          enriched['content_owner_user_id'] = article?['user_id']?.toString();
        } else {
          enriched['content_title'] = 'Reported content';
          enriched['content_preview'] = report['description'] ?? '';
          enriched['content_owner_name'] = 'Unknown';
        }

        return enriched;
      }).toList();
    } catch (e) {
      _errorMessage = 'Failed to load reports: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Verify/approve a user
  Future<bool> verifyUser(String userId) async {
    try {
      await _client
          .from('users')
          .update({'email_verified': true})
          .eq('user_id', userId);

      await _logAdminAction('verify_user', 'Verified user', userId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to verify user: $e';
      notifyListeners();
      return false;
    }
  }

  /// Suspend a user
  Future<bool> suspendUser({
    required String userId,
    required String reason,
    required String adminId,
    bool isPermanent = false,
    int? daysToExpire,
  }) async {
    try {
      final expiresAt = isPermanent
          ? null
          : DateTime.now().add(Duration(days: daysToExpire ?? 7));

      await _client.from('user_suspensions').insert({
        'user_id': userId,
        'reason': reason,
        'suspended_by': adminId,
        'is_permanent': isPermanent,
        'expires_at': expiresAt?.toIso8601String(),
      });

      await _logAdminAction('suspend_user', 'Suspended user: $reason', userId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to suspend user: $e';
      notifyListeners();
      return false;
    }
  }

  /// Unsuspend a user
  Future<bool> unsuspendUser(String userId) async {
    try {
      await _client.from('user_suspensions').delete().eq('user_id', userId);

      await _logAdminAction('unsuspend_user', 'Unsuspended user', userId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to unsuspend user: $e';
      notifyListeners();
      return false;
    }
  }

  /// Promote user to admin
  Future<bool> promoteToAdmin(String userId) async {
    try {
      await SupabaseDatabase.addUserRole(userId: userId, roleName: 'admin');

      await _logAdminAction(
        'promote_to_admin',
        'User promoted to admin',
        userId,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to promote user: $e';
      notifyListeners();
      return false;
    }
  }

  /// Remove admin role
  Future<bool> removeAdminRole(String userId) async {
    try {
      await SupabaseDatabase.removeUserRole(userId: userId, roleName: 'admin');

      await _logAdminAction('remove_admin_role', 'Admin role removed', userId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to remove admin role: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete forum post
  Future<bool> deleteForumPost(String postId) async {
    try {
      await _client.from('forum_posts').delete().eq('post_id', postId);

      await _logAdminAction('delete_forum_post', 'Deleted forum post', null);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete post: $e';
      notifyListeners();
      return false;
    }
  }

  /// Resolve a report
  Future<bool> resolveReport({
    required String reportId,
    required String adminId,
    required String resolutionNotes,
  }) async {
    try {
      await _client
          .from('reported_content')
          .update({
            'status': 'resolved',
            'resolved_by': adminId,
            'resolution_notes': resolutionNotes,
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('report_id', reportId);

      await _logAdminAction('resolve_report', resolutionNotes, null);
      _notifyDataChanged();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to resolve report: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> dismissReport({
    required String reportId,
    required String adminId,
    String? resolutionNotes,
  }) async {
    try {
      await _client
          .from('reported_content')
          .update({
            'status': 'dismissed',
            'resolved_by': adminId,
            'resolution_notes': resolutionNotes,
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('report_id', reportId);

      await _logAdminAction(
        'dismiss_report',
        resolutionNotes ?? 'Dismissed report',
        null,
      );
      _notifyDataChanged();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to dismiss report: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteForumComment(String commentId) async {
    try {
      await _client.from('forum_comments').delete().eq('comment_id', commentId);
      await _logAdminAction(
        'delete_forum_comment',
        'Deleted forum comment: $commentId',
        null,
      );
      _notifyDataChanged();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete comment: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProductReview(String reviewId) async {
    try {
      await _client.from('product_reviews').delete().eq('review_id', reviewId);
      await _logAdminAction(
        'delete_product_review',
        'Deleted product review: $reviewId',
        null,
      );
      _notifyDataChanged();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete review: $e';
      notifyListeners();
      return false;
    }
  }

  /// Log admin action
  Future<void> _logAdminAction(
    String action,
    String? details,
    String? targetUserId,
  ) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Get the admin_id from the admins table for the current user
      final adminRecord = await _client
          .from('admins')
          .select('admin_id')
          .eq('user_id', currentUserId)
          .maybeSingle();

      if (adminRecord == null) {
        // User is not in admins table, skip logging
        return;
      }

      final adminId = adminRecord['admin_id'];

      await _client.from('admin_logs').insert({
        'admin_id': adminId,
        'action': action,
        'details': details,
        'target_user_id': targetUserId,
      });
    } catch (e) {
      debugPrint('Error logging admin action: $e');
    }
  }

  /// Get user count
  Future<int> getUserCount() async {
    try {
      final response = await _client.from('users').select('user_id');
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Get revenue data for analytics
  Future<Map<String, dynamic>> getRevenueAnalytics() async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _client
          .from('v_orders')
          .select('total:total_amount, status:status_code, created_at')
          .neq('status_code', 'CANCELLED');

      double totalRevenue = 0;
      double completedRevenue = 0;

      for (var order in response) {
        totalRevenue += (order['total'] as num).toDouble();
        if ((order['status'] ?? '').toString().toUpperCase() == 'COMPLETED') {
          completedRevenue += (order['total'] as num).toDouble();
        }
      }

      _isLoading = false;
      notifyListeners();

      return {
        'total_revenue': totalRevenue,
        'completed_revenue': completedRevenue,
        'pending_revenue': totalRevenue - completedRevenue,
      };
    } catch (e) {
      _errorMessage = 'Failed to load revenue data: $e';
      _isLoading = false;
      notifyListeners();
      return {};
    }
  }

  // ========================================================================
  // FARMER VERIFICATION
  // ========================================================================

  /// Get pending farmer registrations (from farmer_registrations table)
  Future<List<Map<String, dynamic>>> getPendingFarmerRegistrations({
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _client
          .from('farmer_registrations')
          .select('''
            registration_id, farmer_id, status,
            farmers!inner(full_name, user_id, farm_name, specialty, birth_date, id_type, sex, place_of_birth, pcn,
            years_of_experience, residential_address, face_photo_path,
            valid_id_path, valid_id_back_path, farming_history, is_verified, is_active, 
            farm_latitude, farm_longitude, created_at, updated_at,
            users!fk_farmers_user(name, email, phone, avatar_url))
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      final mapped = (response as List).map((row) {
        final farmers = _normalizeUserRelation(row['farmers']);
        final users = _normalizeUserRelation(farmers?['users']);
        final statusName = _normalizeRegistrationStatus(row['status']);
        final applicantName = _buildApplicantName(
          name: users?['name'],
          email: users?['email'],
          farmName: farmers?['farm_name'],
          userId: farmers?['user_id'],
        );
        return {
          'registration_id': row['registration_id'],
          'farmer_id': row['farmer_id'],
          'status': statusName,
          'id_type': farmers?['id_type'],
          'full_name': farmers?['full_name'],
          'sex': farmers?['sex'],
          'place_of_birth': farmers?['place_of_birth'],
          'pcn': farmers?['pcn'],
          'user_id': farmers?['user_id'],
          'farm_name': farmers?['farm_name'],
          'specialty': farmers?['specialty'],
          'birth_date': farmers?['birth_date'],
          'years_of_experience': farmers?['years_of_experience'],
          'residential_address': farmers?['residential_address'],
          'face_photo_path': farmers?['face_photo_path'],
          'valid_id_path': farmers?['valid_id_path'],
          'valid_id_back_path': farmers?['valid_id_back_path'],
          'farming_history': farmers?['farming_history'],
          'farm_latitude': farmers?['farm_latitude'],
          'farm_longitude': farmers?['farm_longitude'],
          'created_at': farmers?['created_at'],
          'updated_at': farmers?['updated_at'],
          'users': users,
          'name': applicantName,
          'email': users?['email'],
          'phone': users?['phone'],
          'avatar_url': users?['avatar_url'],
          'applicant_name': applicantName,
          'farmer_name': applicantName,
          'farmer_email': users?['email'],
          'farmer_phone': users?['phone'],
        };
      }).toList();

      final hydrated = await _hydrateWithUserProfiles(
        List<Map<String, dynamic>>.from(mapped),
      );

      _isLoading = false;
      notifyListeners();
      return hydrated;
    } catch (e) {
      _errorMessage = 'Failed to load pending registrations: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Get all farmer registrations/farmers based on status
  /// - 'pending' → queries farmer_registrations table
  /// - 'verified'/'all' → queries farmers table
  Future<List<Map<String, dynamic>>> getAllFarmerRegistrations({
    String? status,
    int page = 0,
    int pageSize = 50,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      List<dynamic> response;

      if (status == 'pending') {
        // Query pending from farmer_registrations
        final pendingData = await _client
            .from('farmer_registrations')
            .select('''
              registration_id, farmer_id, status, created_at,
              farmers (
                full_name, user_id, farm_name, specialty, birth_date, id_type, sex, 
                place_of_birth, pcn, years_of_experience, residential_address,
                face_photo_path, valid_id_path, valid_id_back_path, 
                farming_history, is_verified, is_active,
                users (name, email, phone, avatar_url)
              )
            ''')
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .range(page * pageSize, (page + 1) * pageSize - 1);

        response = (pendingData as List).map((row) {
          final farmer = row['farmers'] is List
              ? (row['farmers'] as List).firstOrNull
              : row['farmers'];
          final user = farmer?['users'];

          final applicantName = _buildApplicantName(
            name: farmer?['full_name'] ?? user?['name'],
            email: user?['email'],
            farmName: farmer?['farm_name'],
            userId: farmer?['user_id'],
          );

          return {
            'registration_id': row['registration_id'],
            'farmer_id': row['farmer_id'],
            'user_id': farmer?['user_id'],
            'id_type': farmer?['id_type'],
            'full_name': farmer?['full_name'] ?? applicantName,
            'sex': farmer?['sex'],
            'place_of_birth': farmer?['place_of_birth'],
            'pcn': farmer?['pcn'],
            'farm_name': farmer?['farm_name'] ?? 'Pending Registration',
            'specialty': farmer?['specialty'] ?? 'General',
            'location': farmer?['residential_address'] ?? 'N/A',
            'is_verified': farmer?['is_verified'] == true,
            'is_active': farmer?['is_active'] == true,
            'status': 'pending',
            'created_at': row['created_at'],
            'email': user?['email'],
            'phone': user?['phone'],
            'avatar_url': user?['avatar_url'],
            'applicant_name': applicantName,
          };
        }).toList();
      } else {
        // Query all/verified from farmers table (base)
        var query = _client.from('farmers').select('''
          farmer_id, user_id, farm_name, specialty, location,
          birth_date, years_of_experience, residential_address,
          farming_history, face_photo_path, valid_id_path, valid_id_back_path,
          id_type, sex, place_of_birth, pcn,
          is_verified, is_active, created_at, updated_at,
          users (name, email, phone, avatar_url)
        ''');

        if (status == 'verified') {
          query = query.eq('is_verified', true);
        }

        final farmersData = await query
            .order('created_at', ascending: false)
            .range(page * pageSize, (page + 1) * pageSize - 1);

        response = (farmersData as List).map((row) {
          final user = row['users'];
          final applicantName = _buildApplicantName(
            name: user?['name'],
            email: user?['email'],
            farmName: row['farm_name'],
            userId: row['user_id'],
          );

          return {
            ...Map<String, dynamic>.from(row as Map),
            'name': applicantName,
            'applicant_name': applicantName,
            'email': user?['email'],
            'phone': user?['phone'],
            'avatar_url': user?['avatar_url'],
            'status': row['is_verified'] == true ? 'verified' : 'unverified',
            'face_photo_path': row['face_photo_path'],
            'valid_id_path': row['valid_id_path'],
            'valid_id_back_path': row['valid_id_back_path'],
            'birth_date': row['birth_date'],
            'years_of_experience': row['years_of_experience'],
            'residential_address': row['residential_address'],
            'farming_history': row['farming_history'],
            'id_type': row['id_type'],
            'sex': row['sex'],
            'place_of_birth': row['place_of_birth'],
            'pcn': row['pcn'],
          };
        }).toList();

        // If 'all', merge pending registrations that aren't in farmers table yet
        if (status == null || status == 'all') {
          try {
            final pendingRegs = await _client
                .from('farmer_registrations')
                .select(
                  'registration_id, farmer_id, status, created_at, farmers(full_name)',
                )
                .eq('status', 'pending');

            final existingFarmerIds = response
                .map((r) => r['farmer_id'].toString())
                .toSet();

            for (var reg in (pendingRegs as List)) {
              if (!existingFarmerIds.contains(reg['farmer_id'].toString())) {
                response.add({
                  'registration_id': reg['registration_id'],
                  'farmer_id': reg['farmer_id'],
                  'status': 'pending',
                  'name': reg['farmers']?['full_name'],
                  'farm_name': 'Pending Registration',
                  'created_at': reg['created_at'],
                  'is_verified': false,
                });
              }
            }
          } catch (e) {
            debugPrint('Merge pending failed: $e');
          }
        }
      }

      final hydrated = await _hydrateWithUserProfiles(
        List<Map<String, dynamic>>.from(response),
      );

      _isLoading = false;
      notifyListeners();
      return hydrated;
    } catch (e) {
      _errorMessage = 'Failed to load farmers: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Get a single farmer's full details for the admin dialog.
  Future<Map<String, dynamic>?> getFarmerDetails({
    required String farmerId,
    String? userId,
  }) async {
    try {
      Map<String, dynamic>? farmer;

      final profileQuery = _client.from('v_farmer_profiles').select('''
        farmer_id, user_id, farm_name, specialty, location, badge, image_url,
        face_photo_path, valid_id_path, valid_id_back_path, years_of_experience,
        residential_address, farming_history, birth_date,
        is_verified, is_active, created_at, updated_at,
        farmer_name, farmer_email, farmer_phone, avatar_url,
        total_sales, total_products, average_rating, total_reviews
      ''');

      if (farmerId.isNotEmpty) {
        farmer = await profileQuery.eq('farmer_id', farmerId).maybeSingle();
      }

      if (farmer == null && userId != null && userId.isNotEmpty) {
        farmer = await profileQuery.eq('user_id', userId).maybeSingle();
      }

      farmer ??= await _client
          .from('farmers')
          .select('''
            farmer_id, user_id, farm_name, specialty, birth_date,
            years_of_experience, residential_address, face_photo_path,
            valid_id_path, valid_id_back_path, farming_history, location,
            id_type, sex, place_of_birth, pcn, is_verified,
            is_active, created_at, updated_at
          ''')
          .eq('farmer_id', farmerId)
          .maybeSingle();

      if (farmer == null) {
        return null;
      }

      return farmer;
    } catch (e) {
      _errorMessage = 'Failed to load farmer details: $e';
      notifyListeners();
      return null;
    }
  }

  /// Get user contact profile by user_id with a fallback view for stricter RLS.
  Future<Map<String, dynamic>?> getUserContactByUserId(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return null;

    try {
      final direct = await _client
          .from('users')
          .select('user_id, name, email, phone, avatar_url')
          .eq('user_id', cleanUserId)
          .maybeSingle();

      if (direct != null) {
        return Map<String, dynamic>.from(direct);
      }
    } catch (e) {
      debugPrint('Direct users lookup failed for $cleanUserId: $e');
    }

    try {
      final viewRow = await _client
          .from('v_users_with_roles')
          .select('*')
          .eq('user_id', cleanUserId)
          .maybeSingle();

      if (viewRow == null) return null;

      return {
        'user_id': viewRow['user_id'],
        'name': viewRow['name'],
        'email': viewRow['email'],
        'phone': viewRow['phone'],
        'avatar_url': viewRow['avatar_url'],
      };
    } catch (e) {
      debugPrint('Fallback user lookup failed for $cleanUserId: $e');
      return null;
    }
  }

  /// Resolve a pending registration_id for approve/reject actions.
  /// This prevents silent no-op when list rows are missing registration_id.
  Future<String?> resolvePendingRegistrationId({
    String? registrationId,
    String? farmerId,
    String? userId,
  }) async {
    final directId = (registrationId ?? '').trim();
    if (directId.isNotEmpty) return directId;

    try {
      if (farmerId != null && farmerId.trim().isNotEmpty) {
        final byFarmer = await _client
            .from('farmer_registrations')
            .select('registration_id')
            .eq('farmer_id', farmerId.trim())
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        final resolved = (byFarmer?['registration_id'] ?? '').toString();
        if (resolved.isNotEmpty) return resolved;
      }

      if (userId != null && userId.trim().isNotEmpty) {
        final byUser = await _client
            .from('farmer_registrations')
            .select('registration_id, farmers!inner(user_id)')
            .eq('farmers.user_id', userId.trim())
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        final resolved = (byUser?['registration_id'] ?? '').toString();
        if (resolved.isNotEmpty) return resolved;
      }
    } catch (e) {
      debugPrint('Failed to resolve pending registration ID: $e');
    }

    return null;
  }

  /// Approve farmer registration (creates farmer record from registration)
  Future<bool> approveFarmerRegistration({
    required String registrationId,
    String? reviewNotes,
  }) async {
    try {
      final registration = await _client
          .from('farmer_registrations')
          .select('farmer_id, farmers(full_name, farm_name, user_id)')
          .eq('registration_id', registrationId)
          .maybeSingle();

      if (registration == null) {
        _errorMessage = 'Registration not found: $registrationId';
        notifyListeners();
        return false;
      }

      // Update registration status to approved (2 = approved)
      final adminId = await _resolveCurrentAdminId();
      final updatePayload = <String, dynamic>{
        'status': 'approved',
        'review_notes': reviewNotes,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (adminId != null && adminId.isNotEmpty) {
        updatePayload['reviewed_by'] = adminId;
      }

      await _client
          .from('farmer_registrations')
          .update(updatePayload)
          .eq('registration_id', registrationId);

      // Update farmer as verified
      final farmerId = registration['farmer_id'];
      await _client
          .from('farmers')
          .update({
            'is_verified': true,
            'is_active': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('farmer_id', farmerId);

      final farmers = registration['farmers'] as Map<String, dynamic>?;
      final targetUserId = (farmers?['user_id'] ?? '').toString();
      final farmName = (farmers?['farm_name'] ?? '').toString();
      final fullName = (farmers?['full_name'] ?? '').toString();

      if (targetUserId.isNotEmpty && fullName.isNotEmpty) {
        // Update user's name to their verified legal name
        await _client
            .from('users')
            .update({'name': fullName})
            .eq('user_id', targetUserId);
      }

      if (targetUserId.isNotEmpty) {
        // Grant seller role to the user upon approval
        await SupabaseDatabase.addUserRole(
          userId: targetUserId,
          roleName: 'seller',
        );

        unawaited(
          _sendFarmerApprovalNotification(
            targetUserId: targetUserId,
            registrationId: registrationId,
            farmName: farmName,
          ),
        );
      }

      await _logAdminAction(
        'approve_farmer',
        'Approved farmer registration: $registrationId',
        null,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to approve registration: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  Future<void> _sendFarmerApprovalNotification({
    required String targetUserId,
    required String registrationId,
    String? farmName,
  }) async {
    try {
      final farmLabel = (farmName != null && farmName.trim().isNotEmpty)
          ? ' for ${farmName.trim()}'
          : '';

      await _invokePushNotificationWithRetry(
        targetUserId: targetUserId,
        title: 'Farmer Application Approved',
        body:
            'Your farmer application$farmLabel has been approved. You can now start selling on AgriDirect.',
        notificationCode: 'farmer_approved',
        linkType: 'farmer_registration',
        linkId: registrationId,
      );
    } catch (e) {
      // Approval should still succeed even if the push sender is not yet deployed.
      debugPrint('Failed to send farmer approval push notification: $e');
    }
  }

  /// Reject farmer registration
  Future<bool> rejectFarmerRegistration({
    required String registrationId,
    required String reason,
  }) async {
    try {
      final registration = await _client
          .from('farmer_registrations')
          .select('farmer_id, farmers(farm_name, user_id)')
          .eq('registration_id', registrationId)
          .maybeSingle();

      if (registration == null) {
        _errorMessage = 'Registration not found: $registrationId';
        notifyListeners();
        return false;
      }

      // Update registration status to rejected (3 = rejected)
      final adminId = await _resolveCurrentAdminId();
      final updatePayload = <String, dynamic>{
        'status': 'rejected',
        'review_notes': reason,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (adminId != null && adminId.isNotEmpty) {
        updatePayload['reviewed_by'] = adminId;
      }

      await _client
          .from('farmer_registrations')
          .update(updatePayload)
          .eq('registration_id', registrationId);

      // Update farmer as inactive
      final farmerId = registration['farmer_id'];
      await _client
          .from('farmers')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('farmer_id', farmerId);

      final farmers = registration['farmers'] as Map<String, dynamic>?;
      final targetUserId = (farmers?['user_id'] ?? '').toString();
      final farmName = (farmers?['farm_name'] ?? '').toString();
      if (targetUserId.isNotEmpty) {
        unawaited(
          _sendFarmerRejectionNotification(
            targetUserId: targetUserId,
            registrationId: registrationId,
            reason: reason,
            farmName: farmName,
          ),
        );
      }

      await _logAdminAction('reject_farmer', 'Rejected farmer: $reason', null);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to reject registration: $e';
      debugPrint(_errorMessage);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _sendFarmerRejectionNotification({
    required String targetUserId,
    required String registrationId,
    required String reason,
    String? farmName,
  }) async {
    try {
      final farmLabel = (farmName != null && farmName.trim().isNotEmpty)
          ? ' for ${farmName.trim()}'
          : '';
      final cleanReason = reason.trim().isEmpty
          ? 'No reason provided.'
          : reason.trim();

      await _invokePushNotificationWithRetry(
        targetUserId: targetUserId,
        title: 'Farmer Application Rejected',
        body:
            'Your farmer application$farmLabel was rejected. Reason: $cleanReason You can update your details and apply again.',
        notificationCode: 'farmer_rejected',
        linkType: 'farmer_registration',
        linkId: registrationId,
      );
    } catch (e) {
      // Rejection should still succeed even if push sending fails.
      debugPrint('Failed to send farmer rejection push notification: $e');
    }
  }

  Future<void> _invokePushNotificationWithRetry({
    required String targetUserId,
    required String title,
    required String body,
    required String notificationCode,
    required String linkType,
    required String linkId,
    int maxAttempts = 2,
  }) async {
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _client.functions.invoke(
          'send-push-notification',
          body: {
            'targetUserId': targetUserId,
            'title': title,
            'body': body,
            'notificationCode': notificationCode,
            'linkType': linkType,
            'linkId': linkId,
          },
        );

        final responseData = response.data;
        if (responseData is Map<String, dynamic>) {
          final sent = (responseData['sent'] as num?)?.toInt();
          final total = (responseData['total'] as num?)?.toInt();
          final reason = responseData['reason']?.toString();

          if (sent != null && total != null && total > 0 && sent == 0) {
            debugPrint(
              'Push delivery returned 0/$total for user $targetUserId (code: $notificationCode).',
            );
          }

          if (reason != null && reason.isNotEmpty) {
            debugPrint('Push delivery note for $targetUserId: $reason');
          }

          if (responseData['error'] != null) {
            throw Exception(responseData['error']);
          }
        }

        return;
      } catch (e) {
        lastError = e;
        if (attempt == maxAttempts) {
          break;
        }
      }
    }

    throw Exception(
      'Push notification failed after $maxAttempts attempts: $lastError',
    );
  }

  Future<Map<String, dynamic>> sendAnnouncementPush({
    required String audience,
    required String title,
    required String body,
  }) async {
    _errorMessage = null;

    final normalizedAudience = audience.trim();
    if (normalizedAudience.isEmpty) {
      throw Exception('Audience is required.');
    }
    if (title.trim().isEmpty || body.trim().isEmpty) {
      throw Exception('Title and message are required.');
    }

    try {
      final response = await _client.functions.invoke(
        'send-push-notification',
        body: {
          'audience': normalizedAudience,
          'title': title.trim(),
          'body': body.trim(),
          'notificationCode': 'announcement',
          'linkType': 'announcement',
          'linkId': null,
        },
      );

      // Best-effort audit log (don’t block sending if this fails).
      unawaited(
        _logAdminAction(
          'send_announcement',
          'Broadcast announcement to $normalizedAudience: ${title.trim()}',
          null,
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['error'] != null) {
          throw Exception(data['error'].toString());
        }
        return data;
      }

      return {'success': true};
    } catch (e) {
      _errorMessage = 'Failed to send announcement: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Verify farmer (for already approved farmers in farmers table)
  Future<bool> verifyFarmer({
    required String farmerId,
    String? reviewNotes,
  }) async {
    try {
      await _client
          .from('farmers')
          .update({
            'is_verified': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('farmer_id', farmerId);

      await _logAdminAction(
        'verify_farmer',
        'Verified farmer: $farmerId',
        null,
      );

      // Log the verification action
      if (reviewNotes != null) {
        debugPrint('Review notes: $reviewNotes');
      }

      _notifyDataChanged();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to verify farmer: $e';
      notifyListeners();
      return false;
    }
  }

  /// Unverify farmer (Remove verification status)
  Future<bool> unverifyFarmer({
    required String farmerId,
    String? reviewNotes,
  }) async {
    try {
      await _client
          .from('farmers')
          .update({
            'is_verified': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('farmer_id', farmerId);

      await _logAdminAction(
        'unverify_farmer',
        'Unverified farmer: ${reviewNotes ?? farmerId}',
        null,
      );

      _notifyDataChanged();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to unverify farmer: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get registration history for a farmer
  Future<List<Map<String, dynamic>>> getFarmerRegistrationHistory(
    String farmerId,
  ) async {
    try {
      final response = await _client
          .from('farmer_registrations')
          .select('''
            registration_id, status, review_notes,
            created_at, updated_at,
            admins(admin_id) 
          ''')
          .eq('farmer_id', farmerId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response).map((row) {
        String statusText = 'Pending';
        Color statusColor = const Color(0xFFF59E0B);
        final status = _normalizeRegistrationStatus(row['status']);
        if (status == 'approved') {
          statusText = 'Approved';
          statusColor = const Color(0xFF10B981);
        } else if (status == 'rejected') {
          statusText = 'Rejected';
          statusColor = Colors.red;
        }

        return {
          'id': row['registration_id'],
          'status': statusText,
          'color': statusColor,
          'notes': row['review_notes'],
          'date': row['created_at'],
          'reviewer': 'Admin',
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to load farmer history: $e');
      return [];
    }
  }

  // ========================================================================
  // CATEGORIES MANAGEMENT
  // ========================================================================

  /// Get all categories
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    try {
      final response = await _client
          .from('categories')
          .select(
            'category_id, name, description, is_active, parent_category_id, created_at',
          )
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _errorMessage = 'Failed to load categories: $e';
      return [];
    }
  }

  /// Create category
  Future<bool> createCategory({
    required String name,
    String? description,
    String? parentCategoryId,
  }) async {
    try {
      await _client.from('categories').insert({
        'name': name,
        'description': description,
        'parent_category_id': parentCategoryId,
        'is_active': true,
      });
      await _logAdminAction('create_category', 'Created category: $name', null);
      _notifyDataChanged();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to create category: $e';
      return false;
    }
  }

  /// Update category
  Future<bool> updateCategory({
    required String categoryId,
    String? name,
    String? description,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (isActive != null) updates['is_active'] = isActive;

      await _client
          .from('categories')
          .update(updates)
          .eq('category_id', categoryId);
      await _logAdminAction('update_category', 'Updated category: $name', null);
      _notifyDataChanged();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update category: $e';
      return false;
    }
  }

  /// Delete category
  Future<bool> deleteCategory(String categoryId) async {
    try {
      await _client.from('categories').delete().eq('category_id', categoryId);
      await _logAdminAction('delete_category', 'Deleted category', null);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete category: $e';
      return false;
    }
  }

  // ========================================================================
  // UNITS MANAGEMENT
  // ========================================================================

  /// Get all units
  Future<List<Map<String, dynamic>>> getAllUnits() async {
    try {
      final response = await _client
          .from('units')
          .select('unit_id, name, abbreviation, created_at')
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _errorMessage = 'Failed to load units: $e';
      return [];
    }
  }

  /// Create unit
  Future<bool> createUnit({
    required String name,
    required String abbreviation,
  }) async {
    try {
      await _client.from('units').insert({
        'name': name,
        'abbreviation': abbreviation,
      });
      await _logAdminAction(
        'create_unit',
        'Created unit: $name ($abbreviation)',
        null,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to create unit: $e';
      return false;
    }
  }

  /// Delete unit
  Future<bool> deleteUnit(String unitId) async {
    try {
      await _client.from('units').delete().eq('unit_id', unitId);
      await _logAdminAction('delete_unit', 'Deleted unit', null);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete unit: $e';
      return false;
    }
  }

  // ========================================================================
  // ADMIN LOGS
  // ========================================================================

  /// Get admin, farmer, and customer activity logs.
  Future<List<Map<String, dynamic>>> getSystemActivityLogs({
    int page = 0,
    int pageSize = 50,
    String? actionFilter,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final adminLogs = await _getAdminLogRows(
        page: page,
        pageSize: pageSize,
        actionFilter: actionFilter,
      );

      final activityLogs = await _getSystemActivityLogRows(
        page: page,
        pageSize: pageSize,
        actionFilter: actionFilter,
      );

      final sessionLogs = _isSessionActionFilter(actionFilter)
          ? await _getUserSessionLogRows(
              page: page,
              pageSize: pageSize,
              actionFilter: actionFilter,
            )
          : <Map<String, dynamic>>[];

      final combined = [...adminLogs, ...activityLogs, ...sessionLogs];
      combined.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      _isLoading = false;
      notifyListeners();
      return combined.take(pageSize).toList();
    } catch (e) {
      _errorMessage = 'Failed to load activity logs: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Backward-compatible admin log entry point.
  Future<List<Map<String, dynamic>>> getAdminLogs({
    int page = 0,
    int pageSize = 50,
    String? actionFilter,
  }) {
    return getSystemActivityLogs(
      page: page,
      pageSize: pageSize,
      actionFilter: actionFilter,
    );
  }

  Future<List<Map<String, dynamic>>> _getAdminLogRows({
    required int page,
    required int pageSize,
    String? actionFilter,
  }) async {
    const userActivityFilters = {
      'user_session_start',
      'farmer_session_start',
      'customer_session_start',
    };

    if (actionFilter != null && userActivityFilters.contains(actionFilter)) {
      return [];
    }

    var query = _client
        .from('admin_logs')
        .select(
          'log_id, action, details, ip_address, created_at, admin_id, target_user_id, admins!inner(user_id, users!inner(name, email))',
        );

    if (actionFilter != null && actionFilter != 'all') {
      query = query.eq('action', actionFilter);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    // Flatten admin name into each log entry
    final enriched = (response as List).map((log) {
      final admin = log['admins'];
      final user = admin?['users'];
      return {
        ...Map<String, dynamic>.from(log),
        'actor_name': user?['name'] ?? 'System',
        'actor_email': user?['email'] ?? '',
        'actor_role': 'Admin',
        'admin_name': user?['name'] ?? 'System',
        'admin_email': user?['email'] ?? '',
      };
    }).toList();

    return List<Map<String, dynamic>>.from(enriched);
  }

  bool _isSessionActionFilter(String? actionFilter) {
    return actionFilter == 'user_session_start' ||
        actionFilter == 'farmer_session_start' ||
        actionFilter == 'customer_session_start';
  }

  Future<List<Map<String, dynamic>>> _getSystemActivityLogRows({
    required int page,
    required int pageSize,
    String? actionFilter,
  }) async {
    if (_isSessionActionFilter(actionFilter)) return [];

    try {
      var query = _client
          .from('system_activity_logs')
          .select(
            'log_id, actor_user_id, actor_role, action, details, entity_type, entity_id, severity, metadata, created_at',
          );

      if (actionFilter != null && actionFilter != 'all') {
        query = query.eq('action', actionFilter);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      final logs = List<Map<String, dynamic>>.from(
        (response as List).map((row) => Map<String, dynamic>.from(row)),
      );

      if (logs.isEmpty) return [];

      final actorIds = logs
          .map((log) => log['actor_user_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final userById = <String, Map<String, dynamic>>{};
      if (actorIds.isNotEmpty) {
        final users = await _client
            .from('users')
            .select('user_id, name, email')
            .inFilter('user_id', actorIds);

        for (final user in users as List) {
          final row = Map<String, dynamic>.from(user);
          final userId = row['user_id']?.toString();
          if (userId != null) userById[userId] = row;
        }
      }

      return logs.map((log) {
        final actorId = log['actor_user_id']?.toString();
        final user = actorId == null ? null : userById[actorId];
        final role = (log['actor_role'] ?? 'User').toString();
        final fallbackName = role == 'Farmer'
            ? 'Farmer'
            : role == 'Customer'
            ? 'Customer'
            : 'System';

        return {
          ...log,
          'target_user_id': actorId,
          'actor_name': user?['name'] ?? fallbackName,
          'actor_email': user?['email'] ?? '',
          'actor_role': role,
          'admin_name': user?['name'] ?? fallbackName,
          'admin_email': user?['email'] ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to load system activity logs: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getUserSessionLogRows({
    required int page,
    required int pageSize,
    String? actionFilter,
  }) async {
    const allowedFilters = {
      null,
      'all',
      'user_session_start',
      'farmer_session_start',
      'customer_session_start',
    };

    if (!allowedFilters.contains(actionFilter)) {
      return [];
    }

    final response = await _client
        .from('app_sessions')
        .select(
          'session_id, user_id, start_time, end_time, duration_seconds, platform, device_info, app_version, created_at',
        )
        .order('start_time', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    final sessions = List<Map<String, dynamic>>.from(
      (response as List).map((s) => Map<String, dynamic>.from(s)),
    );

    if (sessions.isEmpty) return [];

    final userIds = sessions
        .map((s) => s['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final userById = <String, Map<String, dynamic>>{};
    final farmerByUserId = <String, Map<String, dynamic>>{};
    final customerByUserId = <String, Map<String, dynamic>>{};

    if (userIds.isNotEmpty) {
      final users = await _client
          .from('users')
          .select('user_id, name, email')
          .inFilter('user_id', userIds);
      for (final user in users as List) {
        final row = Map<String, dynamic>.from(user);
        final userId = row['user_id']?.toString();
        if (userId != null) userById[userId] = row;
      }

      final farmers = await _client
          .from('farmers')
          .select('farmer_id, user_id, farm_name')
          .inFilter('user_id', userIds);
      for (final farmer in farmers as List) {
        final row = Map<String, dynamic>.from(farmer);
        final userId = row['user_id']?.toString();
        if (userId != null) farmerByUserId[userId] = row;
      }

      final customers = await _client
          .from('customers')
          .select('customer_id, user_id')
          .inFilter('user_id', userIds);
      for (final customer in customers as List) {
        final row = Map<String, dynamic>.from(customer);
        final userId = row['user_id']?.toString();
        if (userId != null) customerByUserId[userId] = row;
      }
    }

    return sessions
        .where((session) {
          final userId = session['user_id']?.toString() ?? '';
          final isFarmer = farmerByUserId.containsKey(userId);
          final isCustomer = customerByUserId.containsKey(userId);

          if (actionFilter == 'farmer_session_start') return isFarmer;
          if (actionFilter == 'customer_session_start') return isCustomer;
          return true;
        })
        .map((session) {
          final userId = session['user_id']?.toString() ?? '';
          final user = userById[userId];
          final farmer = farmerByUserId[userId];
          final isFarmer = farmer != null;
          final isCustomer = customerByUserId.containsKey(userId);
          final role = isFarmer ? 'Farmer' : (isCustomer ? 'Customer' : 'User');
          final action = isFarmer
              ? 'farmer_session_start'
              : (isCustomer ? 'customer_session_start' : 'user_session_start');
          final platform = (session['platform'] ?? 'unknown').toString();
          final duration = _formatSessionDuration(session['duration_seconds']);
          final appVersion = (session['app_version'] ?? '').toString().trim();
          final name = (farmer?['farm_name'] ?? user?['name'] ?? role)
              .toString();
          final details = StringBuffer('$role session on $platform');
          if (duration.isNotEmpty) details.write(' - $duration');
          if (appVersion.isNotEmpty) details.write(' - v$appVersion');

          return {
            'log_id': session['session_id'],
            'action': action,
            'details': details.toString(),
            'created_at': session['start_time'] ?? session['created_at'],
            'target_user_id': userId,
            'actor_name': name,
            'actor_email': user?['email'] ?? '',
            'actor_role': role,
            'admin_name': name,
            'admin_email': user?['email'] ?? '',
          };
        })
        .toList();
  }

  String _formatSessionDuration(dynamic rawSeconds) {
    final seconds = rawSeconds is int
        ? rawSeconds
        : int.tryParse(rawSeconds?.toString() ?? '');
    if (seconds == null || seconds <= 0) {
      return 'active now';
    }

    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m';
    return '${duration.inSeconds}s';
  }

  // ========================================================================
  // PRODUCT MANAGEMENT
  // ========================================================================

  /// Approve product
  Future<bool> approveProduct(String productId) async {
    try {
      await _client
          .from('products')
          .update({
            'is_active': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('product_id', productId);
      await _logAdminAction('approve_product', 'Approved product', null);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to approve product: $e';
      return false;
    }
  }

  /// Suspend product
  Future<bool> suspendProduct(String productId, String reason) async {
    try {
      await _client
          .from('products')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('product_id', productId);
      await _logAdminAction(
        'suspend_product',
        'Suspended product: $reason',
        null,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to suspend product: $e';
      return false;
    }
  }

  /// Delete product
  Future<bool> deleteProduct(String productId) async {
    try {
      await _client.from('products').delete().eq('product_id', productId);
      await _logAdminAction('delete_product', 'Deleted product', null);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete product: $e';
      return false;
    }
  }

  /// Feature/unfeature product
  Future<bool> toggleFeaturedProduct(String productId, bool isFeatured) async {
    try {
      await _client
          .from('products')
          .update({
            'is_featured': isFeatured,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('product_id', productId);
      await _logAdminAction(
        isFeatured ? 'feature_product' : 'unfeature_product',
        isFeatured ? 'Featured product' : 'Unfeatured product',
        null,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update product: $e';
      return false;
    }
  }

  // ========================================================================
  // ORDER MANAGEMENT
  // ========================================================================

  /// Update order status
  Future<bool> updateOrderStatus({
    required String orderId,
    required String newStatus,
    String? notes,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;

      // Get current status and history
      final orderData = await _client
          .from('orders')
          .select('status, status_history')
          .eq('order_id', orderId)
          .single();
      final oldStatus = orderData['status'];
      final currentHistory = List<Map<String, dynamic>>.from(
        orderData['status_history'] as List? ?? [],
      );

      // Append to status history
      currentHistory.add({
        'from_status': oldStatus,
        'to_status': newStatus,
        'notes': notes,
        'changed_by': userId,
        'changed_at': DateTime.now().toIso8601String(),
      });

      // Update order with new status and history
      await _client
          .from('orders')
          .update({
            'status': newStatus,
            'status_history': currentHistory,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('order_id', orderId);

      await _logAdminAction(
        'update_order_status',
        'Changed order status to $newStatus',
        null,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update order status: $e';
      return false;
    }
  }

  /// Get order details with items
  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    try {
      final response = await _client
          .from('orders')
          .select('''
            order_id, order_number, status, subtotal, delivery_fee, total_amount,
            payment_method, special_instructions, status_history, created_at, updated_at,
            customers (
              users (name, email, phone)
            ),
            farmers (
              farm_name,
              users (name, email, phone)
            ),
            delivery_addresses (
              label, recipient_name, recipient_phone, street, barangay, city, province
            ),
            order_items (
              product_name, quantity, unit_price, subtotal
            )
          ''')
          .eq('order_id', orderId)
          .single();
      return response;
    } catch (e) {
      _errorMessage = 'Failed to load order details: $e';
      return null;
    }
  }

  // ========================================================================
  // USER ACTIVITY & ANALYTICS
  // ========================================================================

  /// Get user activity summary
  Future<List<Map<String, dynamic>>> getUserActivitySummary({
    int days = 7,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));

      // Since user_activity_logs was removed for 3NF, we aggregate from sessions
      final response = await _client
          .from('app_sessions')
          .select(
            'start_time, clicks_count, keystrokes_count, duration_seconds',
          )
          .gte('start_time', startDate.toIso8601String());

      // Manually aggregate by date for the chart
      final Map<String, Map<String, dynamic>> dailyStats = {};

      for (var session in response as List) {
        final date = (session['start_time'] as String).split('T')[0];
        if (!dailyStats.containsKey(date)) {
          dailyStats[date] = {
            'date': date,
            'total_clicks': 0,
            'total_keystrokes': 0,
            'total_sessions': 0,
            'total_time_seconds': 0,
          };
        }

        dailyStats[date]!['total_clicks'] += session['clicks_count'] ?? 0;
        dailyStats[date]!['total_keystrokes'] +=
            session['keystrokes_count'] ?? 0;
        dailyStats[date]!['total_sessions'] += 1;
        dailyStats[date]!['total_time_seconds'] +=
            session['duration_seconds'] ?? 0;
      }

      return dailyStats.values.toList()
        ..sort((a, b) => a['date'].compareTo(b['date']));
    } catch (e) {
      _errorMessage = 'Failed to load activity summary: $e';
      return [];
    }
  }

  /// Get active sessions count
  Future<int> getActiveSessionsCount() async {
    try {
      final thirtyMinutesAgo = DateTime.now().subtract(
        const Duration(minutes: 30),
      );
      final response = await _client
          .from('app_sessions')
          .select('session_id')
          .gte('start_time', thirtyMinutesAgo.toIso8601String())
          .isFilter('end_time', null);
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Get all farmers
  Future<List<Map<String, dynamic>>> getAllFarmers({
    int page = 0,
    int pageSize = 20,
    bool? isVerified,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      var query = _client.from('farmers').select('''
            farmer_id, farm_name, specialty, location, badge, is_verified, is_active,
            total_sales, total_products, created_at,
            users (user_id, name, email, phone, avatar_url)
          ''');

      if (isVerified != null) {
        query = query.eq('is_verified', isVerified);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      _isLoading = false;
      notifyListeners();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _errorMessage = 'Failed to load farmers: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Get dashboard counts (Simplified for 3NF compatibility)
  Future<Map<String, dynamic>> getDashboardCounts() async {
    try {
      final results = await Future.wait([
        _client.from('v_users_with_roles').select('user_id'),
        _client.from('farmers').select('farmer_id'),
        _client.from('farmers').select('farmer_id').eq('is_verified', true),
        _client.from('products').select('product_id'),
        _client.from('orders').select('order_id, total_amount'),
        _client
            .from('reported_content')
            .select('report_id')
            .eq('status', 'pending'),
        _client
            .from('farmer_registrations')
            .select('registration_id')
            .eq('status', 'pending'),
        _client
            .from('v_users_with_roles')
            .select('user_id')
            .gte(
              'created_at',
              DateTime.now()
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
            ),
      ]);

      double totalRevenue = 0;
      for (var order in (results[4] as List)) {
        totalRevenue += (order['total_amount'] ?? 0).toDouble();
      }

      return {
        'total_users': (results[0] as List)
            .map((row) => row['user_id'].toString())
            .toSet()
            .length,
        'new_users_today': (results[7] as List).length,
        'total_farmers': (results[1] as List).length,
        'verified_farmers': (results[2] as List).length,
        'total_products': (results[3] as List).length,
        'total_orders': (results[4] as List).length,
        'total_revenue': totalRevenue,
        'pending_verifications': (results[6] as List).length,
        'pending_reports': (results[5] as List).length,
        'avg_resolve_time': '12m',
      };
    } catch (e) {
      debugPrint('Error loading dashboard counts: $e');
      return {};
    }
  }

  /// Get specialized metrics for farmers
  Future<Map<String, dynamic>> getFarmerMetrics() async {
    try {
      final response = await _client.from('farmers').select('specialty');
      final specialties = response as List;

      final Map<String, int> counts = {};
      for (var row in specialties) {
        final s = row['specialty'] ?? 'General';
        counts[s] = (counts[s] ?? 0) + 1;
      }

      String topSpecialty = 'None';
      if (counts.isNotEmpty) {
        topSpecialty = counts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }

      return {'top_specialty': topSpecialty, 'avg_yield': '0.0'};
    } catch (e) {
      return {'top_specialty': 'General', 'avg_yield': '0.0'};
    }
  }

  /// Get specialized metrics for products
  Future<Map<String, dynamic>> getProductMetrics() async {
    try {
      final results = await Future.wait([
        _client.from('products').select('product_id'),
        _client.from('products').select('product_id').eq('is_active', true),
        _client.from('products').select('product_id').eq('stock_quantity', 0),
      ]);

      return {
        'total': (results[0] as List).length,
        'active': (results[1] as List).length,
        'out_of_stock': (results[2] as List).length,
      };
    } catch (e) {
      return {'total': 0, 'active': 0, 'out_of_stock': 0};
    }
  }

  /// Get recent dashboard activity (combined feed)
  Future<List<Map<String, dynamic>>> getDashboardActivity() async {
    try {
      final logs = await getSystemActivityLogs(pageSize: 4);
      return logs.map((log) {
        final action = (log['action'] ?? 'system_event').toString();
        final severity = (log['severity'] ?? '').toString();
        return {
          'type': action,
          'title': _dashboardActivityTitle(action, log),
          'subtitle': (log['details'] ?? 'No details available').toString(),
          'time': log['created_at'],
          'color': _dashboardActivityColor(action, severity),
          'icon': Icons.event_note_rounded,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching activity: $e');
      return [];
    }
  }

  String _dashboardActivityTitle(String action, Map<String, dynamic> log) {
    final metadata = log['metadata'] is Map
        ? Map<String, dynamic>.from(log['metadata'] as Map)
        : <String, dynamic>{};
    final orderNumber = metadata['order_number']?.toString();
    final productName = metadata['product_name']?.toString();

    switch (action) {
      case 'order_created':
        return orderNumber == null || orderNumber.isEmpty
            ? 'Order Placed'
            : 'Order Placed #$orderNumber';
      case 'preorder_created':
        return orderNumber == null || orderNumber.isEmpty
            ? 'Pre-order Placed'
            : 'Pre-order Placed #$orderNumber';
      case 'order_status_updated':
        return orderNumber == null || orderNumber.isEmpty
            ? 'Order Status Updated'
            : 'Order Updated #$orderNumber';
      case 'order_cancelled':
        return orderNumber == null || orderNumber.isEmpty
            ? 'Order Cancelled'
            : 'Order Cancelled #$orderNumber';
      case 'product_created':
        return productName == null || productName.isEmpty
            ? 'Product Added'
            : 'Product Added: $productName';
      case 'product_updated':
        return productName == null || productName.isEmpty
            ? 'Product Edited'
            : 'Product Edited: $productName';
      case 'product_archived':
        return productName == null || productName.isEmpty
            ? 'Product Archived'
            : 'Product Archived: $productName';
      default:
        return action
            .split('_')
            .where((part) => part.isNotEmpty)
            .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }

  Color _dashboardActivityColor(String action, String severity) {
    if (severity == 'critical') return const Color(0xFFEF4444);
    if (severity == 'warning') return const Color(0xFFF59E0B);

    if (action.startsWith('product_')) return const Color(0xFF10B981);
    if (action.contains('order')) return const Color(0xFF3B82F6);
    return const Color(0xFF0F766E);
  }

  /// Get signed URL for a file in storage
  Future<String?> getSignedUrl(String path) async {
    try {
      String bucket;
      String fileName;

      if (path.startsWith('http')) {
        // Handle full Supabase URL: https://.../storage/v1/object/public/bucket/path/to/file
        final uri = Uri.parse(path);
        final segments = uri.pathSegments;

        // Find 'public' or 'authenticated' in segments
        int objectIndex = segments.indexOf('object');
        if (objectIndex != -1 && segments.length > objectIndex + 2) {
          // segments[objectIndex+1] is 'public' or 'authenticated'
          bucket = segments[objectIndex + 2];
          fileName = segments.sublist(objectIndex + 3).join('/');
        } else {
          return null;
        }
      } else {
        // Determine bucket from relative path: bucket/path/to/file
        final parts = path.split('/');
        if (parts.length >= 2 &&
            (parts[0] == 'registrations' ||
                parts[0] == 'uploads' ||
                parts[0] == 'products')) {
          bucket = parts[0];
          fileName = parts.sublist(1).join('/');
        } else {
          // Fallback to registrations bucket for farmer documents if no bucket prefix
          bucket = 'registrations';
          fileName = path;
        }
      }

      // If fileName starts with the bucket name, strip it to avoid duplication
      final pathParts = fileName.split('/');
      if (pathParts.length >= 2 && pathParts[0] == bucket) {
        fileName = pathParts.sublist(1).join('/');
      }

      try {
        return await _client.storage
            .from(bucket)
            .createSignedUrl(fileName, 3600);
      } catch (e) {
        // Fallback Strategy: Try alternative common buckets
        final fallbacks = [
          'registrations',
          'uploads',
          'avatars',
          'customer-profiles',
          'farmer-documents',
        ];

        for (final fbBucket in fallbacks) {
          if (fbBucket == bucket) continue;
          try {
            // Also try stripping the bucket name from the fileName if it's redundant
            String fbFileName = fileName;
            if (pathParts.isNotEmpty && pathParts[0] == fbBucket) {
              fbFileName = pathParts.sublist(1).join('/');
            }
            return await _client.storage
                .from(fbBucket)
                .createSignedUrl(fbFileName, 3600);
          } catch (_) {}
        }

        debugPrint('Error generating signed URL for $path: $e');
        return null;
      }
    } catch (e) {
      debugPrint('Error generating signed URL: $e');
      return null;
    }
  }

  // ========================================================================
  // ARTICLE MANAGEMENT
  // ========================================================================

  /// Get all admin articles with pagination and filtering
  Future<List<Map<String, dynamic>>> getAllArticles({
    int page = 0,
    int pageSize = 10,
    String? status,
  }) async {
    try {
      var query = _client.from('admin_articles').select('*');

      if (status != null && status != 'All Content') {
        if (status == 'Published') {
          query = query.eq('is_published', true);
        } else if (status == 'Drafts') {
          query = query.eq('is_published', false);
        }
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _errorMessage = 'Failed to load articles: $e';
      return [];
    }
  }

  /// Create a new article
  Future<bool> createArticle({
    required String title,
    required String summary,
    required String body,
    String? category,
    String? coverImageUrl,
    bool isPublished = false,
    String audience = 'ALL',
  }) async {
    try {
      final adminId = await _resolveCurrentAdminId();
      if (adminId == null) throw Exception('Admin ID not found');

      await _client.from('admin_articles').insert({
        'title': title,
        'summary': summary,
        'body': body,
        'category': category,
        'cover_image_url': coverImageUrl,
        'is_published': isPublished,
        'admin_id': adminId,
        'published_at': isPublished ? DateTime.now().toIso8601String() : null,
        'audience': audience,
      });

      await _logAdminAction('create_article', 'Created article: $title', null);
      _notifyDataChanged();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to create article: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update an existing article
  Future<bool> updateArticle({
    required String articleId,
    required String title,
    required String summary,
    required String body,
    String? category,
    String? coverImageUrl,
    String? audience,
  }) async {
    try {
      final updateData = {
        'title': title,
        'summary': summary,
        'body': body,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (category != null) updateData['category'] = category;
      if (coverImageUrl != null) updateData['cover_image_url'] = coverImageUrl;
      if (audience != null) updateData['audience'] = audience;

      await _client
          .from('admin_articles')
          .update(updateData)
          .eq('article_id', articleId);

      await _logAdminAction('update_article', 'Updated article: $title', null);
      _notifyDataChanged();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update article: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update article audience
  Future<bool> updateArticleAudience(String articleId, String audience) async {
    try {
      await _client
          .from('admin_articles')
          .update({
            'audience': audience,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('article_id', articleId);

      await _logAdminAction(
        'update_article_audience',
        'Updated audience to $audience',
        null,
      );
      _notifyDataChanged();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update audience: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update article publication status
  Future<bool> updateArticleStatus(String articleId, bool isPublished) async {
    try {
      await _client
          .from('admin_articles')
          .update({
            'is_published': isPublished,
            'published_at': isPublished
                ? DateTime.now().toIso8601String()
                : null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('article_id', articleId);

      await _logAdminAction(
        isPublished ? 'publish_article' : 'unpublish_article',
        'Updated article status',
        null,
      );
      _notifyDataChanged();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update article: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete article
  Future<bool> deleteArticle(String articleId) async {
    try {
      await _client.from('admin_articles').delete().eq('article_id', articleId);
      await _logAdminAction('delete_article', 'Deleted article', null);
      _notifyDataChanged();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete article: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get article stats
  Future<Map<String, dynamic>> getArticleStats() async {
    try {
      final results = await Future.wait([
        _client.from('admin_articles').select('article_id'),
        _client
            .from('admin_articles')
            .select('article_id')
            .eq('is_published', true),
      ]);

      final total = (results[0] as List).length;
      final published = (results[1] as List).length;

      return {
        'total': total,
        'published': published,
        'drafts': total - published,
        'views': '0',
      };
    } catch (e) {
      return {'total': 0, 'published': 0, 'drafts': 0, 'views': '0'};
    }
  }

  /// Upload article cover image
  Future<String?> uploadArticleCover(dynamic bytes, String fileName) async {
    try {
      final path = 'articles/$fileName';
      if (bytes is List<int>) {
        await _client.storage
            .from('uploads')
            .uploadBinary(path, Uint8List.fromList(bytes));
      } else {
        // Handle other types if necessary
        return null;
      }
      return _client.storage.from('uploads').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading article cover: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // COMMUNITY POSTS MANAGEMENT
  // ──────────────────────────────────────────────────────────────────────────

  /// Get all community forum posts with pagination
  Future<List<Map<String, dynamic>>> getCommunityPosts({
    int page = 0,
    int pageSize = 10,
    String? searchQuery,
  }) async {
    try {
      var query = _client.from('v_forum_posts').select('*');

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'title.ilike.%$searchQuery%,body.ilike.%$searchQuery%,author_name.ilike.%$searchQuery%',
        );
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _errorMessage = 'Failed to load community posts: $e';
      return [];
    }
  }

  /// Delete a community post
  Future<bool> deleteCommunityPost(String postId) async {
    try {
      await _client.from('forum_posts').delete().eq('post_id', postId);
      await _logAdminAction(
        'delete_forum_post',
        'Deleted forum post: $postId',
        null,
      );
      _notifyDataChanged();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete post: $e';
      notifyListeners();
      return false;
    }
  }

  /// Toggle pin status of a community post
  Future<bool> togglePinCommunityPost(String postId, bool isPinned) async {
    try {
      await _client
          .from('forum_posts')
          .update({
            'is_pinned': isPinned,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('post_id', postId);

      await _logAdminAction(
        'pin_forum_post',
        '${isPinned ? 'Pinned' : 'Unpinned'} forum post: $postId',
        null,
      );
      _notifyDataChanged();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update pin status: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get community post stats
  Future<Map<String, dynamic>> getCommunityPostStats() async {
    try {
      final results = await Future.wait([
        _client.from('forum_posts').select('post_id'),
        _client.from('forum_posts').select('post_id').eq('is_pinned', true),
      ]);

      final total = (results[0] as List).length;
      final pinned = (results[1] as List).length;

      return {
        'total': total,
        'pinned': pinned,
        'recent': 0, // Could be calculated as posts in last 24h
      };
    } catch (e) {
      return {'total': 0, 'pinned': 0, 'recent': 0};
    }
  }
}
