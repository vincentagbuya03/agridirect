import 'package:flutter/foundation.dart';
import 'supabase_config.dart';

/// Admin Service - Handles all admin operations
class AdminService extends ChangeNotifier {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final _client = SupabaseConfig.client;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Check if current user is admin
  Future<bool> isUserAdmin(String userId) async {
    try {
      return await SupabaseDB.hasRole(userId: userId, roleName: 'admin');
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

      var query = _client
          .from('v_users_with_roles')
          .select('user_id, email, name, roles, created_at')
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

      return results;
    } catch (e) {
      _errorMessage = 'Failed to load users: $e';
      _isLoading = false;
      notifyListeners();
      return [];
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
            'product_id, name, farm_name, price, average_rating, review_count, is_preorder, farmer_id, created_at',
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
          .select('order_id, order_number, total, status, created_at')
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
            'report_id, content_type, reason, description, status, created_at',
          )
          .eq('status', status)
          .order('created_at', ascending: false);

      _isLoading = false;
      notifyListeners();
      return List<Map<String, dynamic>>.from(response);
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
      await SupabaseDB.addUserRole(userId: userId, roleName: 'admin');

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
      await SupabaseDB.removeUserRole(userId: userId, roleName: 'admin');

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
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to resolve report: $e';
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
      final adminId = _client.auth.currentUser?.id;
      if (adminId == null) return;

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
          .select('total, status, created_at')
          .neq('status', 'CANCELLED');

      double totalRevenue = 0;
      double completedRevenue = 0;

      for (var order in response) {
        totalRevenue += (order['total'] as num).toDouble();
        if (order['status'] == 'COMPLETED') {
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

  /// Get pending farmer registrations
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
            registration_id, status, created_at, updated_at,
            birth_date, years_of_experience, residential_address,
            face_photo_path, valid_id_path, farming_history,
            farmers (
              farmer_id, farm_name, specialty, location,
              users (user_id, name, email, phone, avatar_url)
            )
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      _isLoading = false;
      notifyListeners();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _errorMessage = 'Failed to load pending registrations: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Get all farmer registrations
  Future<List<Map<String, dynamic>>> getAllFarmerRegistrations({
    String? status,
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      var query = _client.from('farmer_registrations').select('''
            registration_id, status, created_at, updated_at,
            birth_date, years_of_experience, residential_address,
            face_photo_path, valid_id_path, farming_history, review_notes,
            farmers (
              farmer_id, farm_name, specialty, location, is_verified,
              users (user_id, name, email, phone, avatar_url)
            )
          ''');

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      _isLoading = false;
      notifyListeners();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _errorMessage = 'Failed to load registrations: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  /// Approve farmer registration
  Future<bool> approveFarmerRegistration({
    required String registrationId,
    required String farmerId,
    String? reviewNotes,
  }) async {
    try {
      final adminId = _client.auth.currentUser?.id;

      // Update registration status
      await _client.from('farmer_registrations').update({
        'status': 'approved',
        'reviewed_by': adminId,
        'review_notes': reviewNotes ?? 'Application approved',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('registration_id', registrationId);

      // Mark farmer as verified
      await _client.from('farmers').update({
        'is_verified': true,
        'badge': 'verified',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('farmer_id', farmerId);

      await _logAdminAction(
          'approve_farmer', 'Approved farmer registration', null);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to approve registration: $e';
      notifyListeners();
      return false;
    }
  }

  /// Reject farmer registration
  Future<bool> rejectFarmerRegistration({
    required String registrationId,
    required String reason,
  }) async {
    try {
      final adminId = _client.auth.currentUser?.id;

      await _client.from('farmer_registrations').update({
        'status': 'rejected',
        'reviewed_by': adminId,
        'review_notes': reason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('registration_id', registrationId);

      await _logAdminAction('reject_farmer', 'Rejected farmer: $reason', null);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to reject registration: $e';
      notifyListeners();
      return false;
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
            'category_id, name, description, icon, image_url, is_active, parent_category_id, created_at',
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
    String? icon,
    String? imageUrl,
    String? parentCategoryId,
  }) async {
    try {
      await _client.from('categories').insert({
        'name': name,
        'description': description,
        'icon': icon,
        'image_url': imageUrl,
        'parent_category_id': parentCategoryId,
        'is_active': true,
      });
      await _logAdminAction('create_category', 'Created category: $name', null);
      notifyListeners();
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
    String? icon,
    String? imageUrl,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (icon != null) updates['icon'] = icon;
      if (imageUrl != null) updates['image_url'] = imageUrl;
      if (isActive != null) updates['is_active'] = isActive;

      await _client
          .from('categories')
          .update(updates)
          .eq('category_id', categoryId);
      await _logAdminAction('update_category', 'Updated category: $name', null);
      notifyListeners();
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
          'create_unit', 'Created unit: $name ($abbreviation)', null);
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

  /// Get admin activity logs
  Future<List<Map<String, dynamic>>> getAdminLogs({
    int page = 0,
    int pageSize = 50,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _client
          .from('admin_logs')
          .select('log_id, action, details, ip_address, created_at, admin_id')
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      _isLoading = false;
      notifyListeners();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _errorMessage = 'Failed to load admin logs: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  // ========================================================================
  // PRODUCT MANAGEMENT
  // ========================================================================

  /// Approve product
  Future<bool> approveProduct(String productId) async {
    try {
      await _client.from('products').update({
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('product_id', productId);
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
      await _client.from('products').update({
        'is_active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('product_id', productId);
      await _logAdminAction(
          'suspend_product', 'Suspended product: $reason', null);
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
      await _client.from('products').update({
        'is_featured': isFeatured,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('product_id', productId);
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

      // Get current status
      final orderData = await _client
          .from('orders')
          .select('status')
          .eq('order_id', orderId)
          .single();
      final oldStatus = orderData['status'];

      // Update order
      await _client.from('orders').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('order_id', orderId);

      // Add to status history
      await _client.from('order_status_history').insert({
        'order_id': orderId,
        'old_status': oldStatus,
        'new_status': newStatus,
        'notes': notes,
        'changed_by': userId,
      });

      await _logAdminAction(
          'update_order_status', 'Changed order status to $newStatus', null);
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
      final response = await _client.from('orders').select('''
            order_id, order_number, status, subtotal, delivery_fee, total_amount,
            payment_method, special_instructions, created_at, updated_at,
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
            ),
            order_status_history (
              old_status, new_status, notes, created_at
            )
          ''').eq('order_id', orderId).single();
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
      final response = await _client
          .from('user_activity_logs')
          .select(
            'date, total_clicks, total_keystrokes, total_sessions, total_time_seconds',
          )
          .gte('date', startDate.toIso8601String().split('T')[0])
          .order('date');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _errorMessage = 'Failed to load activity summary: $e';
      return [];
    }
  }

  /// Get active sessions count
  Future<int> getActiveSessionsCount() async {
    try {
      final thirtyMinutesAgo =
          DateTime.now().subtract(const Duration(minutes: 30));
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

  /// Get dashboard counts
  Future<Map<String, int>> getDashboardCounts() async {
    try {
      final results = await Future.wait([
        _client.from('users').select('user_id'),
        _client.from('farmers').select('farmer_id'),
        _client.from('farmers').select('farmer_id').eq('is_verified', true),
        _client.from('products').select('product_id'),
        _client.from('orders').select('order_id'),
        _client
            .from('farmer_registrations')
            .select('registration_id')
            .eq('status', 'pending'),
        _client
            .from('reported_content')
            .select('report_id')
            .eq('status', 'pending'),
      ]);

      return {
        'total_users': (results[0] as List).length,
        'total_farmers': (results[1] as List).length,
        'verified_farmers': (results[2] as List).length,
        'total_products': (results[3] as List).length,
        'total_orders': (results[4] as List).length,
        'pending_verifications': (results[5] as List).length,
        'pending_reports': (results[6] as List).length,
      };
    } catch (e) {
      _errorMessage = 'Failed to load dashboard counts: $e';
      return {};
    }
  }

  /// Get recent notifications
  Future<List<Map<String, dynamic>>> getRecentNotifications({
    int limit = 10,
  }) async {
    try {
      final response = await _client
          .from('notifications')
          .select('notification_id, type, title, message, is_read, created_at')
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }
}
