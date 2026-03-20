// ============================================================================
// lib/shared/services/payment/paymaya_service.dart
// PayMaya Payment Gateway Service (LEGACY - Being phased out)
// ============================================================================
// This is a minimal stub implementation for backward compatibility
// PayMaya is being replaced with PayMongo for new transactions
// ============================================================================

class PayMayaException implements Exception {
  final String message;
  PayMayaException(this.message);

  @override
  String toString() => message;
}

class PayMayaCheckoutResponse {
  final String checkoutId;
  final String checkoutUrl;
  final String status;

  PayMayaCheckoutResponse({
    required this.checkoutId,
    required this.checkoutUrl,
    required this.status,
  });
}

class PayMayaService {
  /// DEPRECATED: Create PayMaya checkout (stub - use PayMongoService instead)
  Future<PayMayaCheckoutResponse> createCheckout({
    required String transactionId,
    required double amountPhp,
    required String buyerEmail,
    required String buyerName,
    required String buyerPhone,
    required String productDescription,
  }) async {
    throw PayMayaException(
      'PayMaya is deprecated. Please use PayMongoService for new payments.'
    );
  }

  /// DEPRECATED: Get PayMaya payment status (stub)
  Future<String> getPaymentStatus(String checkoutId) async {
    throw PayMayaException(
      'PayMaya is deprecated. Please use PayMongoService to check payment status.'
    );
  }

  /// DEPRECATED: Refund PayMaya payment (stub)
  Future<void> refundPayment(String checkoutId) async {
    throw PayMayaException(
      'PayMaya is deprecated. Refunds are not available.'
    );
  }
}
