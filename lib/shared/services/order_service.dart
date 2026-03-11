// ============================================================================
// lib/shared/services/order_service.dart
// Order and transaction operations
// ============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order/order_model.dart';
import '../models/order/order_item_model.dart';

class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================================
  // ORDERS OPERATIONS
  // ============================================================================

  /// Get user's orders (as customer)
  Future<List<Order>> getMyOrders({int limit = 20}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('v_orders')
          .select()
          .eq('customer_id', userId)
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch my orders: \$e');
    }
  }

  /// Get farmer's received orders
  Future<List<Order>> getFarmerOrders({int limit = 20}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('v_orders')
          .select()
          .eq('farmer_id', userId)
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch farmer orders: \$e');
    }
  }

  /// Get order by ID
  Future<Order?> getOrderById(String orderId) async {
    try {
      final response = await _supabase
          .from('v_orders')
          .select()
          .eq('order_id', orderId)
          .single();

      return Order.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Create new order
  Future<Order> createOrder({
    required String farmerId,
    required List<OrderItemInput> items,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Generate unique order number
      final orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

      // Create order
      final orderResponse = await _supabase.from('orders').insert({
        'order_number': orderNumber,
        'customer_id': userId,
        'farmer_id': farmerId,
        'status': 'pending',
      }).select().single();

      final orderId = orderResponse['order_id'];

      // Add order items
      final itemsData = items.map((item) => {
            'order_id': orderId,
            'product_id': item.productId,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
          }).toList();

      await _supabase.from('order_items').insert(itemsData);

      return Order.fromJson(orderResponse);
    } catch (e) {
      throw Exception('Failed to create order: \$e');
    }
  }

  /// Update order status
  Future<Order> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final response = await _supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('order_id', orderId)
          .select()
          .single();

      return Order.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update order status: \$e');
    }
  }

  /// Cancel order
  Future<Order> cancelOrder(String orderId) async {
    return updateOrderStatus(orderId, 'cancelled');
  }

  // ============================================================================
  // ORDER ITEMS OPERATIONS
  // ============================================================================

  /// Get order items
  Future<List<OrderItem>> getOrderItems(String orderId) async {
    try {
      final response = await _supabase
          .from('v_order_items')
          .select()
          .eq('order_id', orderId);

      return (response as List<dynamic>)
          .map((json) => OrderItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch order items: \$e');
    }
  }
}

/// Helper class for order item input
class OrderItemInput {
  final String productId;
  final double quantity;
  final double unitPrice;

  OrderItemInput({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });
}
