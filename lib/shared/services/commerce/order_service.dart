// ============================================================================
// lib/shared/services/commerce/order_service.dart
// Order and transaction operations
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/order/order_model.dart';
import '../../models/order/order_item_model.dart';
import '../logging/system_activity_logger.dart';

class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SystemActivityLogger _activityLogger = SystemActivityLogger();

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

  /// Watch user's orders in real-time
  Stream<List<Order>> watchMyOrders({int limit = 20}) async* {
    yield await getMyOrders(limit: limit);

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Trigger re-fetch when orders for this user change
    final stream = _supabase.from('orders').stream(primaryKey: ['order_id']);

    await for (final _ in stream) {
      yield await getMyOrders(limit: limit);
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

  /// Get order items
  Future<List<OrderItem>> getOrderItems(String orderId) async {
    try {
      // Joining with products to get name and image
      final response = await _supabase
          .from('order_items')
          .select('*, products(name, products:product_images(image_url))')
          .eq('order_id', orderId);

      return (response as List<dynamic>).map((item) {
        final product = item['products'] as Map<String, dynamic>?;
        final images = product?['products'] as List<dynamic>?;
        final imageUrl = images != null && images.isNotEmpty
            ? images.first['image_url'] as String?
            : null;

        return OrderItem(
          orderItemId: item['order_item_id'].toString(),
          orderId: item['order_id'].toString(),
          productId: item['product_id'].toString(),
          quantity: (item['quantity'] as num).toDouble(),
          unitPrice: (item['unit_price'] as num).toDouble(),
          createdAt: DateTime.parse(item['created_at']),
          productName: product?['name']?.toString(),
          productImage: imageUrl,
          subtotal: (item['subtotal'] as num?)?.toDouble(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Failed to fetch order items: $e');
      return [];
    }
  }

  /// Get delivery address for an order
  Future<Map<String, dynamic>?> getDeliveryAddress(String addressId) async {
    try {
      final response = await _supabase
          .from('delivery_addresses')
          .select()
          .eq('address_id', addressId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Failed to fetch delivery address: $e');
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
    double deliveryFee = 0.0,
    double discount = 0.0,
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
            'total_amount': subtotal + deliveryFee - discount,
            'payment_method': normalizedMethod,
            'delivery_method': normalizedMethod == 'COP'
                ? 'pickup'
                : 'delivery',
            'delivery_fee': deliveryFee,
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

      await _activityLogger.log(
        action: 'order_created',
        details:
            'Order placed: ${createdOrder.orderNumber} (${items.length} item${items.length == 1 ? '' : 's'})',
        entityType: 'order',
        entityId: createdOrder.orderId,
        metadata: {
          'order_id': createdOrder.orderId,
          'order_number': createdOrder.orderNumber,
          'customer_id': customerId,
          'farmer_id': farmerId,
          'payment_method': normalizedMethod,
          'item_count': items.length,
          'total_amount': createdOrder.total,
        },
      );

      // Notify the farmer about the new order
      try {
        final farmerRecord = await _supabase
            .from('farmers')
            .select('user_id')
            .eq('farmer_id', farmerId)
            .maybeSingle();
        final farmerUserId = farmerRecord?['user_id']?.toString();
        if (farmerUserId != null && farmerUserId.isNotEmpty) {
          final customerName = await _getUserDisplayName(customerId);
          await _supabase.functions.invoke(
            'send-push-notification',
            body: {
              'targetUserId': farmerUserId,
              'title': 'New Order Received',
              'body':
                  '$customerName has placed order ${createdOrder.orderNumber}',
              'notificationCode': 'new_order',
              'linkType': 'order',
              'linkId': createdOrder.orderId,
            },
          );
        }
      } catch (fcmError) {
        debugPrint('Failed to send new order push notification: $fcmError');
      }

      return createdOrder;
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  /// Update order status
  Future<Order> updateOrderStatus(
    String orderId,
    String newStatus, {
    String? cancellationReason,
  }) async {
    try {
      // Retrieve current order to check status before updating
      final currentOrder = await getOrderById(orderId);
      final currentStatus = currentOrder?.status.toLowerCase() ?? '';
      final targetStatus = newStatus.trim().toLowerCase();

      final orderStatusId = await _getOrderStatusId(newStatus);
      final updatePayload = <String, dynamic>{'order_status_id': orderStatusId};
      if (targetStatus == 'cancelled' &&
          cancellationReason != null &&
          cancellationReason.trim().isNotEmpty) {
        updatePayload['cancellation_reason'] = cancellationReason.trim();
      }
      final response = await _supabase
          .from('orders')
          .update(updatePayload)
          .eq('order_id', orderId)
          .select()
          .single();

      final updatedOrder = await getOrderById(response['order_id'] as String);
      if (updatedOrder == null) {
        throw Exception('Order was updated but could not be reloaded');
      }

      // If transitioning to completed, deduct stock
      if (currentStatus != 'completed' && targetStatus == 'completed') {
        final items = await getOrderItems(orderId);
        for (final item in items) {
          final inv = await _supabase
              .from('product_inventory')
              .select('available_quantity, reserved_quantity')
              .eq('product_id', item.productId)
              .maybeSingle();

          if (inv != null) {
            final prod = await _supabase
                .from('products')
                .select('is_preorder')
                .eq('product_id', item.productId)
                .maybeSingle();
            final isPreorder = prod?['is_preorder'] == true;

            if (isPreorder) {
              final reserved =
                  (inv['reserved_quantity'] as num?)?.toDouble() ?? 0.0;
              await _supabase
                  .from('product_inventory')
                  .update({
                    'reserved_quantity': (reserved - item.quantity).clamp(
                      0.0,
                      double.infinity,
                    ),
                  })
                  .eq('product_id', item.productId);
            } else {
              final available =
                  (inv['available_quantity'] as num?)?.toDouble() ?? 0.0;
              await _supabase
                  .from('product_inventory')
                  .update({
                    'available_quantity': (available - item.quantity).clamp(
                      0.0,
                      double.infinity,
                    ),
                  })
                  .eq('product_id', item.productId);
            }
          }
        }
      }
      // If transitioning away from completed, restore stock
      else if (currentStatus == 'completed' && targetStatus != 'completed') {
        final items = await getOrderItems(orderId);
        for (final item in items) {
          final inv = await _supabase
              .from('product_inventory')
              .select('available_quantity, reserved_quantity')
              .eq('product_id', item.productId)
              .maybeSingle();

          if (inv != null) {
            final prod = await _supabase
                .from('products')
                .select('is_preorder')
                .eq('product_id', item.productId)
                .maybeSingle();
            final isPreorder = prod?['is_preorder'] == true;

            if (isPreorder) {
              final reserved =
                  (inv['reserved_quantity'] as num?)?.toDouble() ?? 0.0;
              await _supabase
                  .from('product_inventory')
                  .update({'reserved_quantity': reserved + item.quantity})
                  .eq('product_id', item.productId);
            } else {
              final available =
                  (inv['available_quantity'] as num?)?.toDouble() ?? 0.0;
              await _supabase
                  .from('product_inventory')
                  .update({'available_quantity': available + item.quantity})
                  .eq('product_id', item.productId);
            }
          }
        }
      }

      final normalizedStatus = newStatus.trim().toLowerCase();
      await _activityLogger.log(
        action: normalizedStatus == 'cancelled'
            ? 'order_cancelled'
            : 'order_status_updated',
        details:
            'Order ${updatedOrder.orderNumber} status changed to ${normalizedStatus.toUpperCase()}',
        entityType: 'order',
        entityId: updatedOrder.orderId,
        severity: normalizedStatus == 'cancelled' ? 'warning' : 'info',
        metadata: {
          'order_id': updatedOrder.orderId,
          'order_number': updatedOrder.orderNumber,
          'new_status': normalizedStatus,
        },
      );

      // Notify the customer about the order status update
      try {
        final customerRecord = await _supabase
            .from('customers')
            .select('user_id')
            .eq('customer_id', updatedOrder.customerId)
            .maybeSingle();
        final customerUserId = customerRecord?['user_id']?.toString();
        if (customerUserId != null && customerUserId.isNotEmpty) {
          await _supabase.functions.invoke(
            'send-push-notification',
            body: {
              'targetUserId': customerUserId,
              'title': 'Order Status Updated',
              'body':
                  'Your order ${updatedOrder.orderNumber} status is now ${newStatus.toUpperCase()}',
              'notificationCode': 'order_status_update',
              'linkType': 'order',
              'linkId': updatedOrder.orderId,
            },
          );
        }
      } catch (fcmError) {
        debugPrint(
          'Failed to send order status update push notification: $fcmError',
        );
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
    double deliveryFee = 0.0,
    double discount = 0.0,
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
      deliveryFee: deliveryFee,
      discount: discount,
    );

    final customerId = await _getCurrentCustomerId();
    final conversationId = await _ensureConversation(
      customerId: customerId,
      farmerId: farmerId,
    );

    final farmerUserId = await _getFarmerUserIdByFarmerId(farmerId);

    // Send a structured order notice for the chat UI
    await _sendConversationMessage(
      conversationId: conversationId,
      messageText: '[ORDER_NOTICE:${order.orderId}:ORDER:$normalizedMethod]',
      recipientUserId: farmerUserId,
    );

    if (notes != null &&
        notes.trim().isNotEmpty &&
        notes.trim() != 'Customer selected Cash on Delivery for this order.' &&
        notes.trim() != 'Customer selected Cash on Pickup for this order.') {
      await _sendConversationMessage(
        conversationId: conversationId,
        messageText: notes.trim(),
        recipientUserId: farmerUserId,
      );
    }

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

    final normalizedMethod = paymentMethod.trim().toUpperCase();
    if (normalizedMethod != 'COD' && normalizedMethod != 'COP') {
      throw Exception('Offline payment method must be COD or COP');
    }

    try {
      final rpcResult = await _supabase.rpc(
        'create_offline_preorder',
        params: {
          'p_product_id': productId,
          'p_quantity': quantity,
          'p_payment_method': normalizedMethod,
          'p_delivery_address_id': deliveryAddressId,
          'p_notes': notes,
        },
      );

      final result = Map<String, dynamic>.from(rpcResult as Map);
      final orderId = result['order_id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        throw Exception('Pre-order was created but no order id was returned');
      }

      final createdOrder = await getOrderById(orderId);
      if (createdOrder == null) {
        throw Exception('Pre-order was created but could not be reloaded');
      }

      final conversationId = result['conversation_id']?.toString();
      final farmerUserId = result['farmer_user_id']?.toString();
      // Send a structured order notice for the chat UI
      if (conversationId != null && conversationId.isNotEmpty) {
        await _sendConversationMessage(
          conversationId: conversationId,
          messageText: '[ORDER_NOTICE:$orderId:PRE_ORDER:$normalizedMethod]',
          recipientUserId: farmerUserId,
        );

        // Only send additional notes if they aren't the default auto-generated ones
        if (notes != null &&
            notes.trim().isNotEmpty &&
            !notes.contains('Customer selected Cash on')) {
          await _sendConversationMessage(
            conversationId: conversationId,
            messageText: notes.trim(),
            recipientUserId: farmerUserId,
          );
        }
      }

      await _activityLogger.log(
        action: 'preorder_created',
        details:
            'Pre-order placed: ${createdOrder.orderNumber} for ${result['product_name'] ?? productId}',
        entityType: 'order',
        entityId: createdOrder.orderId,
        metadata: {
          'order_id': createdOrder.orderId,
          'order_number': createdOrder.orderNumber,
          'product_id': productId,
          'product_name': result['product_name'],
          'farmer_id': result['farmer_id'],
          'payment_method': normalizedMethod,
          'quantity': quantity,
        },
      );

      return {
        'order': createdOrder.toJson(),
        'payment_method': normalizedMethod,
        'payment_status': result['payment_status'] ?? 'offline_pending',
        'conversation_id': conversationId,
        'farmer_id': result['farmer_id']?.toString(),
        'farmer_user_id': farmerUserId,
        'product': {
          'product_id': result['product_id']?.toString() ?? productId,
          'name': result['product_name']?.toString(),
        },
      };
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to create pre-order: $e');
    }
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
    String? recipientUserId,
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

    if (recipientUserId == null || recipientUserId.isEmpty) {
      return;
    }

    final senderName = await _getUserDisplayName(userId);

    try {
      await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'targetUserId': recipientUserId,
          'title': 'New message from $senderName',
          'body': messageText,
          'notificationCode': 'new_message',
          'linkType': 'conversation',
          'linkId': conversationId,
          'data': {
            'conversation_id': conversationId,
            'sender_id': userId,
            'sender_name': senderName,
          },
        },
      );
    } catch (e) {
      debugPrint('Failed to send order message push notification: $e');
    }
  }

  Future<String> _getUserDisplayName(String userId) async {
    try {
      final user = await _supabase
          .from('users')
          .select('name, email')
          .eq('user_id', userId)
          .maybeSingle();

      final name = (user?['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        return name;
      }

      final email = (user?['email'] as String?)?.trim();
      if (email != null && email.isNotEmpty) {
        return email;
      }
    } catch (e) {
      debugPrint('Failed to resolve sender display name: $e');
    }

    return 'Someone';
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
