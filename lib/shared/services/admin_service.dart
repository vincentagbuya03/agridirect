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
      List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(response);
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
          .select('product_id, name, farm_name, price, average_rating, review_count, is_preorder, farmer_id, created_at')
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
          .select('post_id, author_name, title, likes_count, comments_count, created_at')
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
          .select('report_id, content_type, reason, description, status, created_at')
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
      await _client
          .from('user_suspensions')
          .delete()
          .eq('user_id', userId);

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

      await _logAdminAction('promote_to_admin', 'User promoted to admin', userId);
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
      await _client
          .from('forum_posts')
          .delete()
          .eq('post_id', postId);

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
      final response = await _client
          .from('users')
          .select('user_id');
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
}
