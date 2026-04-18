// ============================================================================
// lib/shared/services/commerce/order_service.dart
// Order and transaction operations
// ============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/order/order_model.dart';
import '../../models/order/order_item_model.dart';

class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================================
  // ORDERS OPERATIONS
  // ============================================================================

  /// Get user's orders (as customer)
  Future<List<Order>> getMyOrders({int limit = 20}) async {
    try {
      final customerId = await _getCurrentCustomerId();

      final response = await _supabase
          .from('v_orders')
          .select()
          .eq('customer_id', customerId)
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch my orders: $e');
    }
  }

  /// Get farmer's received orders
  Future<List<Order>> getFarmerOrders({int limit = 20}) async {
    try {
      final farmerId = await _getCurrentFarmerId();

      final response = await _supabase
          .from('v_orders')
          .select()
          .eq('farmer_id', farmerId)
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch farmer orders: $e');
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
    required String paymentMethod,
    String? deliveryAddressId,
    String? specialInstructions,
  }) async {
    try {
      if (items.isEmpty) {
        throw Exception('Order must contain at least one item');
      }

      final customerId = await _getCurrentCustomerId();
      final normalizedMethod = paymentMethod.trim().toUpperCase();
      if (normalizedMethod != 'COD' && normalizedMethod != 'COP') {
        throw Exception('Payment method must be COD or COP');
      }
      final pendingStatusId = await _getOrderStatusId('pending');

      final subtotal = items.fold<double>(
        0,
        (sum, item) => sum + (item.quantity * item.unitPrice),
      );

      final productIds = items.map((item) => item.productId).toSet().toList();
      final productsResponse = await _supabase
          .from('products')
          .select('product_id, name')
          .inFilter('product_id', productIds);

      final productNameById = <String, String>{
        for (final row in (productsResponse as List<dynamic>))
          (row['product_id'] as String): (row['name'] as String? ?? 'Product'),
      };

      // Generate unique order number
      final orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

      // Create order
      final orderResponse = await _supabase
          .from('orders')
          .insert({
            'order_number': orderNumber,
            'customer_id': customerId,
            'farmer_id': farmerId,
            'order_status_id': pendingStatusId,
            'delivery_address_id': deliveryAddressId,
            'subtotal': subtotal,
            'total_amount': subtotal,
            'payment_method': normalizedMethod,
            'delivery_fee': 0.0,
            if (specialInstructions != null &&
                specialInstructions.trim().isNotEmpty)
              'special_instructions': specialInstructions.trim(),
          })
          .select()
          .single();

      final orderId = orderResponse['order_id'];

      // Add order items
      final itemsData = items
          .map(
            (item) => {
              'order_id': orderId,
              'product_id': item.productId,
              'product_name': productNameById[item.productId] ?? 'Product',
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'subtotal': item.quantity * item.unitPrice,
            },
          )
          .toList();

      await _supabase.from('order_items').insert(itemsData);

      final createdOrder = await getOrderById(orderId.toString());
      if (createdOrder == null) {
        throw Exception('Order was created but could not be reloaded');
      }
      return createdOrder;
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  /// Update order status
  Future<Order> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final orderStatusId = await _getOrderStatusId(newStatus);
      final response = await _supabase
          .from('orders')
          .update({'order_status_id': orderStatusId})
          .eq('order_id', orderId)
          .select()
          .single();

      final updatedOrder = await getOrderById(response['order_id'] as String);
      if (updatedOrder == null) {
        throw Exception('Order was updated but could not be reloaded');
      }
      return updatedOrder;
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  /// Cancel order
  Future<Order> cancelOrder(String orderId) async {
    return updateOrderStatus(orderId, 'cancelled');
  }

  /// Creates an order for offline payment without charging online or
  /// creating wallet records.
  Future<Map<String, dynamic>> createOfflineOrder({
    required String farmerId,
    required List<OrderItemInput> items,
    required String paymentMethod,
    String? deliveryAddressId,
    String? notes,
  }) async {
    if (items.isEmpty) {
      throw Exception('Order must contain at least one item');
    }

    final normalizedMethod = paymentMethod.trim().toUpperCase();
    if (normalizedMethod != 'COD' && normalizedMethod != 'COP') {
      throw Exception('Offline payment method must be COD or COP');
    }

    final order = await createOrder(
      farmerId: farmerId,
      items: items,
      paymentMethod: normalizedMethod,
      deliveryAddressId: deliveryAddressId,
      specialInstructions: notes,
    );

    final customerId = await _getCurrentCustomerId();
    final conversationId = await _ensureConversation(
      customerId: customerId,
      farmerId: farmerId,
    );

    if (notes != null && notes.trim().isNotEmpty) {
      await _sendConversationMessage(
        conversationId: conversationId,
        messageText: notes.trim(),
      );
    }

    final farmerUserId = await _getFarmerUserIdByFarmerId(farmerId);

    return {
      'order': order.toJson(),
      'payment_method': normalizedMethod,
      'payment_status': 'offline_pending',
      'conversation_id': conversationId,
      'farmer_user_id': farmerUserId,
    };
  }

  Future<Map<String, dynamic>> createOfflinePreOrderByProductId({
    required String productId,
    required double quantity,
    required String paymentMethod,
    String? deliveryAddressId,
    String? notes,
  }) async {
    if (quantity <= 0) {
      throw Exception('Quantity must be greater than zero');
    }

    final product = await _supabase
        .from('v_products')
        .select('product_id, farmer_id, price, name')
        .eq('product_id', productId)
        .eq('is_preorder', true)
        .maybeSingle();

    if (product == null) {
      throw Exception('Selected pre-order product is not available.');
    }

    final resolvedProductId = product['product_id'] as String?;
    final farmerId = product['farmer_id'] as String?;
    final unitPrice = (product['price'] as num?)?.toDouble();

    if (resolvedProductId == null || resolvedProductId.isEmpty) {
      throw Exception('Selected product does not have a product_id');
    }
    if (farmerId == null || farmerId.isEmpty) {
      throw Exception('Selected product does not have a farmer_id');
    }
    if (unitPrice == null || unitPrice <= 0) {
      throw Exception('Selected product has an invalid price');
    }

    final result = await createOfflineOrder(
      farmerId: farmerId,
      items: [
        OrderItemInput(
          productId: resolvedProductId,
          quantity: quantity,
          unitPrice: unitPrice,
        ),
      ],
      paymentMethod: paymentMethod,
      deliveryAddressId: deliveryAddressId,
      notes: notes,
    );

    return {
      ...result,
      'product': {'product_id': resolvedProductId, 'name': product['name']},
    };
  }

  /// Creates a pre-order product by name for offline payment only.
  Future<Map<String, dynamic>> createOfflinePreOrderByProductName({
    required String productName,
    required double quantity,
    required String paymentMethod,
    String? deliveryAddressId,
    String? notes,
  }) async {
    if (quantity <= 0) {
      throw Exception('Quantity must be greater than zero');
    }

    final exactMatch = await _supabase
        .from('v_products')
        .select('product_id, farmer_id, price, name')
        .eq('is_preorder', true)
        .ilike('name', productName)
        .limit(1)
        .maybeSingle();

    final product =
        exactMatch ??
        await _supabase
            .from('v_products')
            .select('product_id, farmer_id, price, name')
            .eq('is_preorder', true)
            .order('created_at', ascending: false)
            .limit(1)
            .single();

    final productId = product['product_id'] as String?;
    final farmerId = product['farmer_id'] as String?;
    final unitPrice = (product['price'] as num?)?.toDouble();

    if (productId == null || productId.isEmpty) {
      throw Exception('Selected product does not have a product_id');
    }
    if (farmerId == null || farmerId.isEmpty) {
      throw Exception('Selected product does not have a farmer_id');
    }
    if (unitPrice == null || unitPrice <= 0) {
      throw Exception('Selected product has an invalid price');
    }

    final result = await createOfflinePreOrderByProductId(
      productId: productId,
      quantity: quantity,
      paymentMethod: paymentMethod,
      deliveryAddressId: deliveryAddressId,
      notes: notes,
    );

    return {
      ...result,
      'product': {'product_id': productId, 'name': product['name']},
    };
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
      throw Exception('Failed to fetch order items: $e');
    }
  }

  Future<String> _getCurrentCustomerId() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _supabase
        .from('customers')
        .select('customer_id')
        .eq('user_id', userId)
        .maybeSingle();

    final customerId = response?['customer_id'] as String?;
    if (customerId == null || customerId.isEmpty) {
      throw Exception('Customer profile not found');
    }
    return customerId;
  }

  Future<String> _getCurrentFarmerId() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _supabase
        .from('farmers')
        .select('farmer_id')
        .eq('user_id', userId)
        .maybeSingle();

    final farmerId = response?['farmer_id'] as String?;
    if (farmerId == null || farmerId.isEmpty) {
      throw Exception('Farmer profile not found');
    }
    return farmerId;
  }

  Future<int> _getOrderStatusId(String code) async {
    final response = await _supabase
        .from('order_statuses')
        .select('order_status_id')
        .eq('code', code.toLowerCase())
        .maybeSingle();

    final orderStatusId = response?['order_status_id'] as int?;
    if (orderStatusId == null) {
      throw Exception('Order status ${code.toLowerCase()} is not configured');
    }
    return orderStatusId;
  }

  Future<String?> _getFarmerUserIdByFarmerId(String farmerId) async {
    final farmer = await _supabase
        .from('farmers')
        .select('user_id')
        .eq('farmer_id', farmerId)
        .maybeSingle();
    return farmer?['user_id']?.toString();
  }

  Future<String> _ensureConversation({
    required String customerId,
    required String farmerId,
  }) async {
    final existing = await _supabase
        .from('conversations')
        .select('conversation_id')
        .eq('customer_id', customerId)
        .eq('farmer_id', farmerId)
        .maybeSingle();

    if (existing != null) {
      return existing['conversation_id'].toString();
    }

    final inserted = await _supabase
        .from('conversations')
        .insert({
          'customer_id': customerId,
          'farmer_id': farmerId,
          'last_message_at': DateTime.now().toIso8601String(),
        })
        .select('conversation_id')
        .single();

    return inserted['conversation_id'].toString();
  }

  Future<void> _sendConversationMessage({
    required String conversationId,
    required String messageText,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'message_text': messageText,
    });

    await _supabase
        .from('conversations')
        .update({'last_message_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId);
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
