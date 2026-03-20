// ============================================================================
// lib/mobile/screens/consumer/checkout_screen.dart
// Pre-order checkout & payment
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/models/order/order_item_model.dart';
import '../../../shared/services/payment/payment_service.dart';
import '../../../shared/services/order/order_service.dart';
import '../common/payment_success_screen.dart';
import '../common/payment_failed_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<OrderItem> items;
  final double totalAmount;
  final String farmerId;

  const CheckoutScreen({
    super.key,
    required this.items,
    required this.totalAmount,
    required this.farmerId,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const Color primary = Color(0xFF13EC5B);
  static const Color dark = Color(0xFF0F172A);

  final _paymentService = PaymentService();
  final _orderService = OrderService();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedPaymentMethod = 'gcash'; // default payment method for pre-orders
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      appBar: AppBar(
        title: Text(
          'Checkout',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: dark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: dark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderSummary(),
            const SizedBox(height: 28),
            _buildCustomerInfo(),
            const SizedBox(height: 28),
            _buildPaymentMethodSelector(),
            const SizedBox(height: 28),
            _buildPaymentInfo(),
            const SizedBox(height: 32),
            _buildPayButton(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Summary',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: dark,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (int i = 0; i < widget.items.length; i++) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.items[i].productName ?? 'Product',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: dark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.items[i].quantity.toStringAsFixed(0)} x ₱${widget.items[i].unitPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₱${(widget.items[i].quantity * widget.items[i].unitPrice).toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: dark,
                      ),
                    ),
                  ],
                ),
                if (i < widget.items.length - 1)
                  Divider(height: 16, color: Colors.grey[200]),
              ],
              Divider(height: 16, color: Colors.grey[300]),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: dark,
                    ),
                  ),
                  Text(
                    '₱${widget.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerInfo() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Information',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: dark,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'your@email.com',
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primary, width: 1.5),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email required';
              if (!v.contains('@')) return 'Invalid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '+63 9XX XXXX XXX',
              prefixText: '+63 ',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primary, width: 1.5),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Phone required';
              if (v.length < 10) return 'Invalid phone';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: dark,
          ),
        ),
        const SizedBox(height: 16),
        _buildPaymentMethodCard(
          method: 'gcash',
          label: 'GCash',
          icon: '📱',
          description: 'Mobile payment via PayMongo',
        ),
        const SizedBox(height: 12),
        _buildPaymentMethodCard(
          method: 'card',
          label: 'Card Payment',
          icon: '💳',
          description: 'Credit/Debit Card via PayMongo',
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard({
    required String method,
    required String label,
    required String icon,
    required String description,
  }) {
    final isSelected = _selectedPaymentMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primary : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: dark,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? primary : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfo() {
    final infoMap = {
      'gcash': {
        'title': 'GCash Payment',
        'desc':
            'You will be redirected to PayMongo to complete the payment via GCash.',
        'fee': '0%',
      },
      'card': {
        'title': 'Card Payment',
        'desc': 'Pay securely using your credit or debit card via PayMongo.',
        'fee': '0%',
      },
    };

    final info = infoMap[_selectedPaymentMethod] ?? infoMap['gcash']!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_rounded, color: primary, size: 20),
              const SizedBox(width: 8),
              Text(
                info['title']!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            info['desc']!,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Processing Fee',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                info['fee']!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: dark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: dark,
          disabledBackgroundColor: primary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isProcessing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(dark),
                ),
              )
            : Text(
                'Proceed to Payment',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      // Create a real order using OrderService
      final orderItems = widget.items
          .map((item) => OrderItemInput(
                productId: item.productId,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
              ))
          .toList();

      final order = await _orderService.createOrder(
        farmerId: widget.farmerId,
        items: orderItems,
      );

      // Create payment using PayMongo (for pre-orders)
      final payment = await _paymentService.createPreOrderPayment(
        preOrderId: order.orderId,
        amountPhp: widget.totalAmount,
        paymentMethod: _selectedPaymentMethod,
        customerEmail: _emailController.text,
        customerPhone: '+63${_phoneController.text}',
      );

      if (mounted) {
        // Navigate to payment processing screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentProcessingScreen(
              paymentResponse: payment,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

// ============================================================================
// PAYMENT PROCESSING SCREEN (for PayMongo Pre-Orders)
// ============================================================================

class PaymentProcessingScreen extends StatefulWidget {
  final PaymentResponse paymentResponse;

  const PaymentProcessingScreen({
    super.key,
    required this.paymentResponse,
  });

  @override
  State<PaymentProcessingScreen> createState() =>
      _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> {
  late PaymentService _paymentService;
  late Stream<Transaction?> _statusStream;
  bool _paymentLinkOpened = false;

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentService();

    // Poll payment status every 5 seconds
    _statusStream = _paymentService.pollPaymentStatus(
      widget.paymentResponse.transactionId,
      interval: const Duration(seconds: 5),
    );

    // Automatically open the payment link
    _openPaymentLink();
  }

  Future<void> _openPaymentLink() async {
    final url = Uri.parse(widget.paymentResponse.paymentLink);
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (launched) {
        setState(() => _paymentLinkOpened = true);
      }
    } catch (e) {
      debugPrint('Could not launch payment URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Payment still pending. Check your email for status.'),
            ),
          );
        }
      },
      child: Scaffold(
        body: StreamBuilder<Transaction?>(
          stream: _statusStream,
          builder: (context, snapshot) {
            final transaction = snapshot.data;

            if (transaction?.isConfirmed == true) {
              // Navigate to success screen
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentSuccessScreen(
                        transactionId: widget.paymentResponse.transactionId,
                      ),
                    ),
                  );
                }
              });
              return _buildSuccessScreen();
            }

            if (transaction?.isFailed == true) {
              // Navigate to failed screen
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentFailedScreen(
                        transactionId: widget.paymentResponse.transactionId,
                      ),
                    ),
                  );
                }
              });
              return _buildFailedScreen();
            }

            return _buildProcessingScreen();
          },
        ),
      ),
    );
  }

  Widget _buildProcessingScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF13EC5B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.access_time_rounded,
                  color: Color(0xFF13EC5B), size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'Processing Payment',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _paymentLinkOpened
                  ? 'Complete your payment in the browser.\nWe\'ll update this page automatically.'
                  : 'Opening payment page...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Color(0xFF13EC5B)),
            const SizedBox(height: 32),
            // Button to re-open payment link
            OutlinedButton.icon(
              onPressed: _openPaymentLink,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open Payment Page'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF13EC5B),
                side: const BorderSide(color: Color(0xFF13EC5B)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Cancel button
            TextButton(
              onPressed: () async {
                try {
                  await _paymentService
                      .cancelPayment(widget.paymentResponse.transactionId);
                } catch (_) {}
                if (mounted) Navigator.pop(context);
              },
              child: Text(
                'Cancel Payment',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: const BoxDecoration(
              color: Color(0xFF13EC5B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            'Payment Successful!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your pre-order is confirmed',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13EC5B),
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Back to Home',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.red, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            'Payment Failed',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again or use another payment method',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Try Again',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
