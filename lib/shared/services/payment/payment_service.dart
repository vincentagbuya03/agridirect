// ============================================================================
// lib/shared/services/payment/payment_service.dart
// Payment processing service - handles both regular orders and pre-orders
// ============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'paymongo_service.dart';
import 'paymaya_service.dart';

class PaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final PayMongoService _payMongoService = PayMongoService();
  final PayMayaService _payMayaService = PayMayaService();

  // ============================================================================
  // CREATE PRE-ORDER PAYMENT (Using PayMongo)
  // ============================================================================

  /// Create payment specifically for pre-orders using PayMongo
  /// This is the NEW method for pre-order checkout
  Future<PaymentResponse> createPreOrderPayment({
    required String preOrderId,
    required double amountPhp,
    required String paymentMethod, // 'gcash' or 'card'
    required String customerEmail,
    required String customerPhone,
    String customerName = 'Customer',
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Validate payment method
      if (paymentMethod != 'gcash' && paymentMethod != 'card') {
        throw Exception('Unsupported payment method: $paymentMethod');
      }

      // Create transaction record in Supabase (PENDING state)
      final txnResponse = await _supabase
          .from('transactions')
          .insert({
            'order_id': preOrderId,
            'amount_php': amountPhp,
            'payment_method': paymentMethod,
            'payment_status': 'pending',
            'customer_email': customerEmail,
            'customer_phone': customerPhone,
            'transaction_type': 'preorder', // Mark as pre-order
          })
          .select()
          .single();

      final transactionId = txnResponse['transaction_id'] as String;

      // Call PayMongo API to create checkout session
      final paymentMethodDesc =
          paymentMethod == 'gcash' ? 'GCash Pre-Order' : 'Card Pre-Order';

      final checkoutResponse = await _payMongoService.createCheckoutSession(
        transactionId: transactionId,
        amountPhp: amountPhp,
        paymentMethod: paymentMethod,
        buyerEmail: customerEmail,
        buyerName: customerName,
        buyerPhone: customerPhone,
        productDescription: paymentMethodDesc,
      );

      debugPrint('PayMongo Payment created: $checkoutResponse');

      // Store PayMongo checkout ID in transaction
      await _supabase.from('transactions').update({
        'gateway_response': {
          'checkoutId': checkoutResponse.checkoutId,
          'checkoutUrl': checkoutResponse.checkoutUrl,
          'status': checkoutResponse.status,
          'gateway': 'paymongo',
        }
      }).eq('transaction_id', transactionId);

      return PaymentResponse(
        transactionId: transactionId,
        paymentLink: checkoutResponse.checkoutUrl,
        amount: amountPhp,
        orderId: preOrderId,
        checkoutId: checkoutResponse.checkoutId,
      );
    } on PayMongoException catch (e) {
      debugPrint('PayMongo error: $e');
      throw Exception('Payment gateway error: ${e.message}');
    } catch (e) {
      debugPrint('Pre-order payment creation error: $e');
      throw Exception('Failed to create payment: $e');
    }
  }

  // ============================================================================
  // CREATE REGULAR ORDER PAYMENT (Using PayMaya - existing method)
  // ============================================================================

  /// Create payment for regular marketplace orders (existing method)
  /// Supports: GCash (via PayMaya), PayMaya
  Future<PaymentResponse> createPayment({
    required String orderId,
    required double amountPhp,
    required String paymentMethod, // 'gcash', 'paymaya'
    required String customerEmail,
    required String customerPhone,
    String customerName = 'Customer',
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Validate payment method
      if (paymentMethod != 'gcash' && paymentMethod != 'paymaya') {
        throw Exception('Unsupported payment method: $paymentMethod');
      }

      // Create transaction record in Supabase (PENDING state)
      final txnResponse = await _supabase
          .from('transactions')
          .insert({
            'order_id': orderId,
            'amount_php': amountPhp,
            'payment_method': paymentMethod,
            'payment_status': 'pending',
            'customer_email': customerEmail,
            'customer_phone': customerPhone,
            'transaction_type': 'marketplace', // Regular order
          })
          .select()
          .single();

      final transactionId = txnResponse['transaction_id'] as String;

      // Call PayMaya API to create checkout
      final paymentMethodDesc =
          paymentMethod == 'gcash' ? 'GCash Order' : 'PayMaya Order';

      final checkoutResponse = await _payMayaService.createCheckout(
        transactionId: transactionId,
        amountPhp: amountPhp,
        buyerEmail: customerEmail,
        buyerName: customerName,
        buyerPhone: customerPhone,
        productDescription: paymentMethodDesc,
      );

      debugPrint('Payment created: $checkoutResponse');

      // Store PayMaya checkout ID in transaction
      await _supabase.from('transactions').update({
        'gateway_response': {
          'checkoutId': checkoutResponse.checkoutId,
          'status': checkoutResponse.status,
          'gateway': 'paymaya',
        }
      }).eq('transaction_id', transactionId);

      return PaymentResponse(
        transactionId: transactionId,
        paymentLink: checkoutResponse.checkoutUrl,
        amount: amountPhp,
        orderId: orderId,
        checkoutId: checkoutResponse.checkoutId,
      );
    } on PayMayaException catch (e) {
      debugPrint('PayMaya error: $e');
      throw Exception('Payment gateway error: ${e.message}');
    } catch (e) {
      debugPrint('Payment creation error: $e');
      throw Exception('Failed to create payment: $e');
    }
  }

  // ============================================================================
  // CHECK PAYMENT STATUS
  // ============================================================================

  /// Check payment status from gateway
  Future<bool> checkPaymentStatus(String checkoutId, String gateway) async {
    try {
      String status;

      if (gateway == 'paymongo') {
        status = await _payMongoService.getPaymentStatus(checkoutId);
      } else {
        status = await _payMayaService.getPaymentStatus(checkoutId);
      }

      if (status.toLowerCase() == 'paid' ||
          status.toLowerCase() == 'completed') {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Status check error: $e');
      return false;
    }
  }

  // ============================================================================
  // GET TRANSACTION
  // ============================================================================

  /// Get transaction by order ID
  Future<Transaction?> getTransactionByOrderId(String orderId) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();

      if (response == null) return null;
      return Transaction.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch transaction: $e');
    }
  }

  /// Get transaction by transaction ID
  Future<Transaction?> getTransaction(String transactionId) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select()
          .eq('transaction_id', transactionId)
          .maybeSingle();

      if (response == null) return null;
      return Transaction.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch transaction: $e');
    }
  }

  // ============================================================================
  // VERIFY PAYMENT (Webhook / Manual Check)
  // ============================================================================

  /// Mark payment as confirmed (called via webhook or manual verification)
  Future<Transaction> confirmPayment({
    required String transactionId,
    required String paymentReference,
  }) async {
    try {
      final response = await _supabase
          .from('transactions')
          .update({
            'payment_status': 'confirmed',
            'payment_reference': paymentReference,
            'paid_at': DateTime.now().toIso8601String(),
          })
          .eq('transaction_id', transactionId)
          .select()
          .single();

      // Mark order as confirmed
      final transaction = Transaction.fromJson(response);
      await _supabase
          .from('orders')
          .update({'status': 'confirmed'})
          .eq('order_id', transaction.orderId);

      return transaction;
    } catch (e) {
      throw Exception('Failed to confirm payment: $e');
    }
  }

  /// Mark payment as failed
  Future<Transaction> failPayment({
    required String transactionId,
    required String reason,
  }) async {
    try {
      final response = await _supabase
          .from('transactions')
          .update({
            'payment_status': 'failed',
            'gateway_response': {'error': reason},
          })
          .eq('transaction_id', transactionId)
          .select()
          .single();

      return Transaction.fromJson(response);
    } catch (e) {
      throw Exception('Failed to mark payment as failed: $e');
    }
  }

  // ============================================================================
  // CANCEL PAYMENT
  // ============================================================================

  /// Cancel pending payment & refund if needed
  Future<void> cancelPayment(String transactionId) async {
    try {
      await _supabase
          .from('transactions')
          .update({
            'payment_status': 'cancelled',
          })
          .eq('transaction_id', transactionId);

      // Mark order as cancelled
      final transaction = await getTransaction(transactionId);
      if (transaction != null) {
        await _supabase
            .from('orders')
            .update({'status': 'cancelled'})
            .eq('order_id', transaction.orderId);
      }
    } catch (e) {
      throw Exception('Failed to cancel payment: $e');
    }
  }

  // ============================================================================
  // POLLING (For checking payment status without webhook)
  // ============================================================================

  /// Poll payment status periodically
  Stream<Transaction?> pollPaymentStatus(
    String transactionId, {
    Duration interval = const Duration(seconds: 5),
    Duration timeout = const Duration(minutes: 30),
  }) async* {
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      try {
        final transaction = await getTransaction(transactionId);
        yield transaction;

        // Stop polling if confirmed or failed
        if (transaction != null &&
            (transaction.isConfirmed || transaction.isFailed)) {
          return;
        }

        await Future.delayed(interval);
      } catch (e) {
        yield null;
      }
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get customer's payment history
  Future<List<Transaction>> getCustomerTransactions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('transactions')
          .select('''
            *,
            orders(customer_id)
          ''')
          .eq('orders.customer_id', userId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  /// Get farmer's received payments (from pre-orders and orders)
  Future<List<Transaction>> getFarmerPayments() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('transactions')
          .select('''
            *,
            orders(farmer_id)
          ''')
          .eq('orders.farmer_id', userId)
          .eq('payment_status', 'confirmed')
          .order('paid_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch farmer payments: $e');
    }
  }

  /// Get farmer's pre-order earnings specifically
  Future<double> getFarmerPreOrderEarnings(String farmerId) async {
    try {
      final transactions = await _supabase
          .from('transactions')
          .select('''
            amount_php,
            orders(farmer_id)
          ''')
          .eq('orders.farmer_id', farmerId)
          .eq('payment_status', 'confirmed')
          .eq('transaction_type', 'preorder');

      double total = 0;
      for (var txn in transactions as List<dynamic>) {
        total += (txn['amount_php'] as num).toDouble();
      }
      return total;
    } catch (e) {
      debugPrint('Error fetching pre-order earnings: $e');
      return 0;
    }
  }
}

// ============================================================================
// RESPONSE MODELS
// ============================================================================

class PaymentResponse {
  final String transactionId;
  final String paymentLink;
  final double amount;
  final String orderId;
  final String? checkoutId;

  PaymentResponse({
    required this.transactionId,
    required this.paymentLink,
    required this.amount,
    required this.orderId,
    this.checkoutId,
  });
}

// ============================================================================
// TRANSACTION MODEL (Simplified inline)
// ============================================================================

class Transaction {
  final String transactionId;
  final String orderId;
  final double amountPhp;
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentReference;
  final String? customerPhone;
  final String? customerEmail;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime updatedAt;
  final String? transactionType;
  final Map<String, dynamic>? gatewayResponse;

  Transaction({
    required this.transactionId,
    required this.orderId,
    required this.amountPhp,
    required this.paymentMethod,
    required this.paymentStatus,
    this.paymentReference,
    this.customerPhone,
    this.customerEmail,
    required this.createdAt,
    this.paidAt,
    required this.updatedAt,
    this.transactionType,
    this.gatewayResponse,
  });

  // Getters
  bool get isPending => paymentStatus == 'pending';
  bool get isConfirmed => paymentStatus == 'confirmed';
  bool get isFailed => paymentStatus == 'failed';
  bool get isCancelled => paymentStatus == 'cancelled';
  bool get isPreOrder => transactionType == 'preorder';

  bool get isOverdue {
    final now = DateTime.now();
    return now.difference(createdAt).inHours > 24;
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      transactionId: json['transaction_id'] as String,
      orderId: json['order_id'] as String,
      amountPhp: (json['amount_php'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      paymentStatus: json['payment_status'] as String,
      paymentReference: json['payment_reference'] as String?,
      customerPhone: json['customer_phone'] as String?,
      customerEmail: json['customer_email'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      transactionType: json['transaction_type'] as String?,
      gatewayResponse: json['gateway_response'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'transaction_id': transactionId,
    'order_id': orderId,
    'amount_php': amountPhp,
    'payment_method': paymentMethod,
    'payment_status': paymentStatus,
    'payment_reference': paymentReference,
    'customer_phone': customerPhone,
    'customer_email': customerEmail,
    'created_at': createdAt.toIso8601String(),
    'paid_at': paidAt?.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'transaction_type': transactionType,
    'gateway_response': gatewayResponse,
  };
}
