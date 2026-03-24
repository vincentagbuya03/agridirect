// ============================================================================
// lib/shared/services/order_service.dart
// Order and transaction operations
// ============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order/order_model.dart';
import '../models/order/order_item_model.dart';
import 'wallet_service.dart';

class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final WalletService _walletService = WalletService();

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
      if (items.isEmpty)
        throw Exception('Order must contain at least one item');

      final subtotal = items.fold<double>(
        0,
        (sum, item) => sum + (item.quantity * item.unitPrice),
      );

      // Generate unique order number
      final orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

      // Create order
      final orderResponse = await _supabase
          .from('orders')
          .insert({
            'order_number': orderNumber,
            'customer_id': userId,
            'farmer_id': farmerId,
            'status': 'pending',
            'subtotal': subtotal,
            'total_amount': subtotal,
          })
          .select()
          .single();

      final orderId = orderResponse['order_id'];

      final productIds = items.map((item) => item.productId).toSet().toList();
      final productRows = await _supabase
          .from('products')
          .select('product_id, name')
          .inFilter('product_id', productIds);
      final productNameById = <String, String>{
        for (final row in (productRows as List<dynamic>))
          (row['product_id'] as String): (row['name'] as String? ?? 'Product'),
      };

      // Add order items
      final itemsData = items
          .map(
            (item) => {
              'order_id': orderId,
              'product_id': item.productId,
              'product_name': productNameById[item.productId] ?? item.productId,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'subtotal': item.quantity * item.unitPrice,
            },
          )
          .toList();

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

  /// Marks an order payment as completed and credits the amount to the farmer wallet.
  /// Called after customer completes payment via GCash/PayMaya.
  Future<Map<String, dynamic>> payOrderDirectToFarmerWallet({
    required String orderId,
    required double amount,
    required String paymentMethod,
    String? transactionReference,
    String? notes,
  }) async {
    try {
      return await _walletService.processOrderPaymentToFarmerWallet(
        orderId: orderId,
        amount: amount,
        paymentMethod: paymentMethod,
        transactionReference: transactionReference,
        notes: notes,
      );
    } catch (e) {
      throw Exception('Failed to process payment to farmer wallet: $e');
    }
  }

  /// Creates an order and immediately credits the payment to the farmer wallet.
  Future<Map<String, dynamic>> createPaidOrderToFarmerWallet({
    required String farmerId,
    required List<OrderItemInput> items,
    required String paymentMethod,
    double? paymentAmount,
    String? transactionReference,
    String? notes,
  }) async {
    if (items.isEmpty) {
      throw Exception('Order must contain at least one item');
    }

    final order = await createOrder(farmerId: farmerId, items: items);
    final totalAmount = items.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.unitPrice),
    );
    final amountToCharge = paymentAmount ?? totalAmount;

    if (amountToCharge <= 0) {
      throw Exception('Payment amount must be greater than zero');
    }
    if (amountToCharge > totalAmount) {
      throw Exception('Payment amount cannot be greater than order total');
    }

    final payment = await payOrderDirectToFarmerWallet(
      orderId: order.orderId,
      amount: amountToCharge,
      paymentMethod: paymentMethod,
      transactionReference: transactionReference,
      notes: notes,
    );

    return {'order': order.toJson(), 'payment': payment};
  }

  /// Creates and pays a pre-order product by name, then credits payment to farmer wallet.
  Future<Map<String, dynamic>> createPaidPreOrderByProductName({
    required String productName,
    required double quantity,
    required String paymentMethod,
    double? paymentAmount,
    String? transactionReference,
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

    final result = await createPaidOrderToFarmerWallet(
      farmerId: farmerId,
      items: [
        OrderItemInput(
          productId: productId,
          quantity: quantity,
          unitPrice: unitPrice,
        ),
      ],
      paymentMethod: paymentMethod,
      paymentAmount: paymentAmount,
      transactionReference: transactionReference,
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
