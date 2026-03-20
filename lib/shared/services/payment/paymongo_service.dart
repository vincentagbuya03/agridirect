// ============================================================================
// lib/shared/services/payment/paymongo_service.dart
// PayMongo API Integration for Pre-Order Payments (GCash & Card)
// ============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

// ============================================================================
// PAYMONGO SERVICE
// ============================================================================

class PayMongoService {
  // PayMongo API Configuration - TEST Keys
  static const String _baseUrl = 'https://api.paymongo.com/v1';

  // TEST Keys - Replace with your actual keys
  static const String _publicKey = 'pk_test_MbrtriThUh1Jcg+2Jddn3u3';
  static const String _secretKey = 'sk_test_0dqnFUrFi+Xdi0eFkHnqgr0da';

  late final Dio _dio;

  PayMongoService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    // Setup authentication interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add Basic Auth header
          final credentials = '$_publicKey:$_secretKey';
          final encoded = base64Encode(utf8.encode(credentials));
          options.headers['Authorization'] = 'Basic $encoded';
          options.headers['Content-Type'] = 'application/json';
          return handler.next(options);
        },
        onError: (error, handler) {
          debugPrint('PayMongo API Error: ${error.response?.statusCode}');
          debugPrint('Response: ${error.response?.data}');
          return handler.next(error);
        },
      ),
    );
  }

  // ============================================================================
  // CREATE CHECKOUT SESSION (Pre-Order Payments)
  // ============================================================================

  /// Create a PayMongo checkout session for pre-order payments
  /// Returns checkout URL and ID for redirecting user to payment page
  Future<PayMongoCheckoutResponse> createCheckoutSession({
    required String transactionId,
    required double amountPhp,
    required String paymentMethod, // 'card' or 'gcash'
    required String buyerEmail,
    required String buyerName,
    required String buyerPhone,
    required String productDescription,
  }) async {
    try {
      final amountInCentavos = (amountPhp * 100).toInt();

      final payload = {
        'data': {
          'attributes': {
            'line_items': [
              {
                'currency': 'PHP',
                'amount': amountInCentavos,
                'description': productDescription,
                'name': 'Pre-Order Payment',
                'quantity': 1,
              }
            ],
            'payment_method_types': paymentMethod == 'gcash'
                ? ['gcash']
                : ['card'],
            'success_url':
                'agridirect://preorder-payment-success?sessionId={CHECKOUT_SESSION_ID}&txnId=$transactionId',
            'cancel_url':
                'agridirect://preorder-payment-cancel?sessionId={CHECKOUT_SESSION_ID}&txnId=$transactionId',
            'description': 'Pre-Order #$transactionId',
            'billing':
                _buildBillingInfo(buyerName, buyerEmail, buyerPhone),
          }
        }
      };

      debugPrint('PayMongo Checkout Request: $payload');

      final response = await _dio.post(
        '/checkout_sessions',
        data: payload,
      );

      debugPrint('PayMongo Checkout Response: ${response.data}');

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        final sessionData = data['data'] as Map<String, dynamic>;
        final attributes = sessionData['attributes'] as Map<String, dynamic>;
        final checkoutId = sessionData['id'] as String;
        final checkoutUrl = attributes['checkout_url'] as String;

        return PayMongoCheckoutResponse(
          checkoutId: checkoutId,
          checkoutUrl: checkoutUrl,
          status: attributes['status'] ?? 'open',
          createdAt:
              attributes['created_at'] ?? DateTime.now().toIso8601String(),
        );
      } else {
        throw PayMongoException(
          message:
              'Failed to create checkout: ${response.statusCode} - ${response.data}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      debugPrint('PayMongo DioException: ${e.message}');
      throw PayMongoException(
        message: e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      debugPrint('PayMongo Exception: $e');
      throw PayMongoException(message: e.toString());
    }
  }

  // ============================================================================
  // RETRIEVE CHECKOUT SESSION
  // ============================================================================

  /// Get checkout session details and payment status
  Future<PayMongoCheckoutResponse> getCheckoutSession(
      String checkoutId) async {
    try {
      final response = await _dio.get('/checkout_sessions/$checkoutId');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final sessionData = data['data'] as Map<String, dynamic>;
        final attributes = sessionData['attributes'] as Map<String, dynamic>;

        return PayMongoCheckoutResponse.fromJson(sessionData);
      } else {
        throw PayMongoException(
          message: 'Failed to retrieve checkout: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw PayMongoException(
        message: e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ============================================================================
  // GET PAYMENT STATUS
  // ============================================================================

  /// Get payment status from checkout session
  Future<String> getPaymentStatus(String checkoutId) async {
    try {
      final checkout = await getCheckoutSession(checkoutId);

      // Check if payment was successful
      final payments = checkout.payments ?? [];
      if (payments.isNotEmpty) {
        final lastPayment = payments.last;
        if (lastPayment['status'] == 'paid') {
          return 'paid';
        }
      }

      return checkout.status;
    } catch (e) {
      debugPrint('Error getting payment status: $e');
      return 'unknown';
    }
  }

  // ============================================================================
  // WEBHOOK SIGNATURE VERIFICATION
  // ============================================================================

  /// Verify webhook signature from PayMongo
  /// PayMongo sends webhooks with X-Paymongo-Signature header (HMAC-SHA256)
  bool verifyWebhookSignature({
    required String requestBody,
    required String signature,
  }) {
    try {
      // Compute HMAC-SHA256 using secret key
      final hmac =
          Hmac(sha256, utf8.encode(_secretKey)); // Use _secretKey from the class
      final digest = hmac.convert(utf8.encode(requestBody));
      final computedSignature = digest.toString();

      debugPrint('Computed signature: $computedSignature');
      debugPrint('Received signature: $signature');

      // Compare signatures
      return computedSignature == signature;
    } catch (e) {
      debugPrint('Signature verification error: $e');
      return false;
    }
  }

  // ============================================================================
  // REFUND PAYMENT
  // ============================================================================

  /// Refund a successful payment
  Future<bool> refundPayment({
    required String checkoutId,
    double? refundAmount,
  }) async {
    try {
      final payload = {
        'data': {
          'attributes': {
            if (refundAmount != null) 'amount': (refundAmount * 100).toInt(),
          }
        }
      };

      final response = await _dio.post(
        '/checkout_sessions/$checkoutId/refund',
        data: payload,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Refund error: $e');
      return false;
    }
  }

  // ============================================================================
  // PAYOUT API (For Farmer Payments)
  // ============================================================================

  /// Request a payout to farmer's bank account
  Future<PayMongoPayoutResponse> requestPayout({
    required double amountPhp,
    required String accountName,
    required String accountNumber,
    required String bankCode,
    required String referenceNumber,
  }) async {
    try {
      final amountInCentavos = (amountPhp * 100).toInt();

      final payload = {
        'data': {
          'attributes': {
            'amount': amountInCentavos,
            'currency': 'PHP',
            'description': 'Farmer earnings payout',
            'recipient': {
              'type': 'bank_account',
              'bank_account': {
                'account_name': accountName,
                'account_number': accountNumber,
                'bank_code': bankCode,
              }
            },
            'reference_number': referenceNumber,
          }
        }
      };

      debugPrint('PayMongo Payout Request: $payload');

      final response = await _dio.post(
        '/payouts',
        data: payload,
      );

      debugPrint('PayMongo Payout Response: ${response.data}');

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return PayMongoPayoutResponse.fromJson(data['data']);
      } else {
        throw PayMongoException(
          message: 'Failed to create payout: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw PayMongoException(
        message: e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw PayMongoException(message: e.toString());
    }
  }

  /// Get payout status
  Future<String> getPayoutStatus(String payoutId) async {
    try {
      final response = await _dio.get('/payouts/$payoutId');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final payoutData = data['data'] as Map<String, dynamic>;
        final attributes = payoutData['attributes'] as Map<String, dynamic>;
        return attributes['status'] ?? 'unknown';
      }

      return 'unknown';
    } catch (e) {
      debugPrint('Error getting payout status: $e');
      return 'unknown';
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  Map<String, dynamic> _buildBillingInfo(
    String name,
    String email,
    String phone,
  ) {
    final nameParts = name.split(' ');
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': {
        'line1': 'Philippines',
        'city': 'Philippines',
        'state': 'PH',
        'postal_code': '1000',
        'country_code': 'PH',
      }
    };
  }
}

// ============================================================================
// RESPONSE MODELS
// ============================================================================

class PayMongoCheckoutResponse {
  final String checkoutId;
  final String checkoutUrl;
  final String status; // 'open', 'completed', 'expired', 'cancelled'
  final String createdAt;
  final List<Map<String, dynamic>>? payments;

  PayMongoCheckoutResponse({
    required this.checkoutId,
    required this.checkoutUrl,
    required this.status,
    required this.createdAt,
    this.payments,
  });

  factory PayMongoCheckoutResponse.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>;
    final payments = (attributes['payments'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>()
        .toList();

    return PayMongoCheckoutResponse(
      checkoutId: json['id'] ?? '',
      checkoutUrl: attributes['checkout_url'] ?? '',
      status: attributes['status'] ?? 'open',
      createdAt:
          attributes['created_at'] ?? DateTime.now().toIso8601String(),
      payments: payments,
    );
  }
}

class PayMongoPayoutResponse {
  final String payoutId;
  final String status; // 'pending', 'processing', 'completed', 'failed'
  final double amountPhp;
  final String referenceNumber;
  final Map<String, dynamic>? payoutDetails;

  PayMongoPayoutResponse({
    required this.payoutId,
    required this.status,
    required this.amountPhp,
    required this.referenceNumber,
    this.payoutDetails,
  });

  factory PayMongoPayoutResponse.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>;
    return PayMongoPayoutResponse(
      payoutId: json['id'] ?? '',
      status: attributes['status'] ?? 'pending',
      amountPhp: (attributes['amount'] as int? ?? 0) / 100,
      referenceNumber: attributes['reference_number'] ?? '',
      payoutDetails: attributes,
    );
  }
}

// ============================================================================
// EXCEPTIONS
// ============================================================================

class PayMongoException implements Exception {
  final String message;
  final int? statusCode;

  PayMongoException({
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => 'PayMongoException: $message (Code: $statusCode)';
}
