// ============================================================================
// lib/mobile/screens/consumer/preorder_payment_example.dart
// Example: How to integrate GCash/PayMaya in your screens
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/payment/payment_service.dart';
import '../../../shared/models/order/order_item_model.dart';
import 'checkout_screen.dart';

/// Example of how to navigate to checkout with payment
class PreorderPaymentExample extends StatelessWidget {
  const PreorderPaymentExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample preorder items
    final items = [
      OrderItem(
        orderItemId: 'item-1',
        orderId: '',
        productId: 'prod-123',
        productName: 'Fresh Tomatoes',
        quantity: 5,
        unitPrice: 50.0,
        createdAt: DateTime.now(),
      ),
      OrderItem(
        orderItemId: 'item-2',
        orderId: '',
        productId: 'prod-456',
        productName: 'Organic Lettuce',
        quantity: 2,
        unitPrice: 75.0,
        createdAt: DateTime.now(),
      ),
    ];

    final totalAmount = items.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.unitPrice),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pre-order Items',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display items
            for (var item in items) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName ?? 'Product',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${item.quantity.toStringAsFixed(0)} x ₱${item.unitPrice.toStringAsFixed(2)} = ₱${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 24),
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount:',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '₱${totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: const Color(0xFF13EC5B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Checkout button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CheckoutScreen(
                        items: items,
                        totalAmount: totalAmount,
                        farmerId: 'farmer-123', // Get from your data
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13EC5B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Proceed to Checkout',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// IMPLEMENTATION GUIDE: How to use PaymentService directly
// ============================================================================

/// Example usage in any screen
class PaymentServiceExample {
  final paymentService = PaymentService();

  /// Create and process a payment
  Future<void> processPayment({
    required String orderId,
    required double amount,
    required String paymentMethod, // 'gcash' or 'card'
    required String customerEmail,
    required String customerPhone,
  }) async {
    try {
      // Step 1: Create payment (pre-order)
      final paymentResponse = await paymentService.createPreOrderPayment(
        preOrderId: orderId,
        amountPhp: amount,
        paymentMethod: paymentMethod,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
      );

      print('✅ Payment created:');
      print('   - Transaction ID: ${paymentResponse.transactionId}');
      print('   - Payment Link: ${paymentResponse.paymentLink}');
      print('   - Checkout ID: ${paymentResponse.checkoutId}');

      // Step 2: Open payment link in browser/webview
      // await launchUrl(Uri.parse(paymentResponse.paymentLink));

      // Step 3: Poll for confirmation (automatic in PaymentProcessingScreen)
      // OR set up webhook listener on backend

    } catch (e) {
      print('❌ Payment failed: $e');
    }
  }

  /// Get payment status
  Future<void> checkPaymentStatus(String transactionId) async {
    try {
      final transaction = await paymentService.getTransaction(transactionId);

      if (transaction == null) {
        print('❌ Transaction not found');
        return;
      }

      print('📊 Payment Status:');
      print('   - Status: ${transaction.paymentStatus}');
      print('   - Amount: ₱${transaction.amountPhp}');
      print('   - Method: ${transaction.paymentMethod}');
      print('   - Created: ${transaction.createdAt}');
      print('   - Paid at: ${transaction.paidAt}');

    } catch (e) {
      print('❌ Error: $e');
    }
  }

  /// Get customer's transaction history
  Future<void> getTransactionHistory() async {
    try {
      final transactions = await paymentService.getCustomerTransactions();

      print('📋 Your Transactions:');
      for (var txn in transactions) {
        print('   - Order: ${txn.orderId}, Status: ${txn.paymentStatus}, Amount: ₱${txn.amountPhp}');
      }

    } catch (e) {
      print('❌ Error: $e');
    }
  }

  /// Confirm payment (called by webhook)
  Future<void> confirmPaymentByReference({
    required String transactionId,
    required String paymentReference,
  }) async {
    try {
      final transaction = await paymentService.confirmPayment(
        transactionId: transactionId,
        paymentReference: paymentReference,
      );

      print('✅ Payment confirmed: ${transaction.paymentStatus}');

    } catch (e) {
      print('❌ Error: $e');
    }
  }

  /// Cancel payment
  Future<void> cancelPayment(String transactionId) async {
    try {
      await paymentService.cancelPayment(transactionId);
      print('✅ Payment cancelled');

    } catch (e) {
      print('❌ Error: $e');
    }
  }
}

// ============================================================================
// IMPLEMENTATION CHECKLIST
// ============================================================================

/*
✅ COMPLETED:
 1. PaymentService created with GCash/Card support via PayMongo
 2. PayMayaService created for marketplace API integration
 3. PayMongoService created for pre-order API integration
 4. CheckoutScreen UI created with functional payment flow
 5. Transaction model created
 6. Database migration prepared
 7. Payment processing screen with url_launcher integration
 8. Pre-Order Hub "Reserve Now" → Checkout navigation connected
 9. OrderService.createOrder integrated into checkout flow

📝 TODO:
 1. Add PayMongo API credentials to .env file (currently using test keys)
 2. Configure deep links in AndroidManifest.xml & Info.plist
 3. Update app router with payment redirect routes
 4. Run database migration in Supabase
 5. Generate transaction model from JSON (build_runner)
 6. Test with staging API keys
 7. Set up webhook endpoint for payment confirmation
 8. Deploy to production and switch to production API keys

🧪 TESTING CHECKLIST:
 □ Test GCash payment flow (end-to-end)
 □ Test Card payment flow (end-to-end)
 □ Test payment cancellation
 □ Test payment failure handling
 □ Test deep link redirection
 □ Test webhook signature verification
 □ Test transaction history retrieval
 □ Test farmer payment retrieval
 □ Test refund (manual or auto)

*/
