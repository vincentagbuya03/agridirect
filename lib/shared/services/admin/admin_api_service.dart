import 'package:supabase_flutter/supabase_flutter.dart';
// Note: Models use Map<String, dynamic> for flexibility with RLS views
// Typed models can be added to lib/shared/models/ as needed
import 'admin_service.dart';

/// Admin API Service Layer - Structured Backend Integration
/// This service provides an organized, strongly-typed interface for admin operations
class AdminAPIService {
  final SupabaseClient _client = Supabase.instance.client;
  // Fallback to existing logic where necessary
  final AdminService _legacyService = AdminService();

  // ==========================================
  // User Management Systems
  // ==========================================

  Future<List<Map<String, dynamic>>> getUsers({
    int page = 1,
    String? search,
  }) async {
    return _legacyService.getAllUsers(
      page: page - 1,
      pageSize: 50,
      searchQuery: search,
    );
  }

  Future<Map<String, dynamic>?> getUserDetail(String userId) async {
    final response = await _client
        .from('v_users_with_roles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return response;
  }

  Future<void> suspendUser(String userId, String reason) async {
    final adminId = _client.auth.currentUser?.id;
    if (adminId == null) throw Exception('Admin not logged in');

    await _legacyService.suspendUser(
      userId: userId,
      reason: reason,
      adminId: adminId,
      isPermanent: false,
    );
  }

  Future<void> unsuspendUser(String userId) async {
    await _legacyService.unsuspendUser(userId);
  }

  Future<void> deleteUser(String userId) async {
    // Requires RPC or edge function to delete auth.users completely
    await _client.rpc('delete_user_admin', params: {'target_user_id': userId});
  }

  Future<void> updateUserRole(String userId, String role) async {
    if (role == 'admin') {
      await _legacyService.promoteToAdmin(userId);
    } else {
      await _legacyService.removeAdminRole(userId);
    }
  }

  // ==========================================
  // Farmer Management
  // ==========================================

  Future<List<Map<String, dynamic>>> getFarmers({
    int page = 1,
    String? status,
  }) async {
    return _legacyService.getAllFarmerRegistrations(
      page: page - 1,
      status: status,
    );
  }

  Future<void> verifyFarmer(String farmerId) async {
    await _legacyService.verifyFarmer(farmerId: farmerId);
  }

  Future<void> rejectFarmer(String farmerId, String reason) async {
    await _legacyService.rejectFarmerRegistration(
      registrationId: farmerId,
      reason: reason,
    );
  }

  // ==========================================
  // Orders
  // ==========================================

  Future<List<Map<String, dynamic>>> getOrders({
    int page = 1,
    String? status,
    String? search,
  }) async {
    // Current AdminService doesn't support search/filter directly, extending it here
    var query = _client
        .from('v_orders')
        .select(
          'order_id, order_number, total:total_amount, status:status_code, created_at, customer_name',
        );

    if (status != null && status.isNotEmpty) {
      query = query.eq('status_code', status);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range((page - 1) * 20, page * 20 - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getOrderDetail(String orderId) async {
    final response = await _client
        .from('v_orders')
        .select()
        .eq('order_id', orderId)
        .maybeSingle();
    return response;
  }

  Future<void> cancelOrder(String orderId, String reason) async {
    await _client
        .from('orders')
        .update({'status': 'CANCELLED'})
        .eq('order_id', orderId);
    // Log reason logic could be added to an order_logs table
  }

  // ==========================================
  // Products
  // ==========================================

  Future<List<Map<String, dynamic>>> getProducts({
    int page = 1,
    String? category,
  }) async {
    return _legacyService.getAllProducts(page: page - 1);
  }

  Future<void> approveProduct(String productId) async {
    await _client
        .from('products')
        .update({'is_active': true, 'status': 'approved'})
        .eq('product_id', productId);
  }

  Future<void> rejectProduct(String productId, String reason) async {
    await _client
        .from('products')
        .update({'is_active': false, 'status': 'rejected'})
        .eq('product_id', productId);
  }

  Future<void> deleteProduct(String productId) async {
    await _client.from('products').delete().eq('product_id', productId);
  }

  // ==========================================
  // Analytics
  // ==========================================

  Future<Map<String, dynamic>> getDashboardStats() async {
    return await _legacyService.getDashboardStats() ?? {};
  }

  Future<List<Map<String, dynamic>>> getRevenueData(String period) async {
    // Pseudo implementation for charting
    return [];
  }

  Future<List<Map<String, dynamic>>> getUserGrowthData(String period) async {
    return [];
  }

  Future<List<Map<String, dynamic>>> getTopProducts() async {
    final response = await _client
        .from('v_products')
        .select()
        .order('average_rating', ascending: false)
        .limit(5);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getTopFarmers() async {
    final response = await _client
        .from('v_farmer_profiles')
        .select()
        .order('total_sales', ascending: false)
        .limit(5);
    return List<Map<String, dynamic>>.from(response);
  }

  // ==========================================
  // Reports
  // ==========================================

  Future<List<Map<String, dynamic>>> getReports({int page = 1}) async {
    return _legacyService.getReportedContent();
  }

  Future<void> resolveReport(String reportId, String action) async {
    final adminId = _client.auth.currentUser?.id;
    if (adminId == null) throw Exception('Admin not logged in');

    await _legacyService.resolveReport(
      reportId: reportId,
      adminId: adminId,
      resolutionNotes: action,
    );
  }
}
