import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/data/app_data.dart';
import '../../../shared/models/auth/user_address_model.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/services/user/user_service.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../../shared/models/farmer/farmer_profile_model.dart';
import '../../../shared/services/farmer/farmer_service.dart';

class WebCheckoutScreen extends StatefulWidget {
  const WebCheckoutScreen({
    super.key,
    required this.product,
    required this.initialQuantity,
  });

  final ProductItem product;
  final int initialQuantity;

  @override
  State<WebCheckoutScreen> createState() => _WebCheckoutScreenState();
}

class _WebCheckoutScreenState extends State<WebCheckoutScreen> {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _white = Colors.white;

  final OrderService _orderService = OrderService();
  final UserService _userService = UserService();
  final TextEditingController _instructionsController = TextEditingController();

  List<UserAddress> _addresses = const [];
  UserAddress? _selectedAddress;
  bool _isLoadingAddresses = true;
  bool _isSubmittingOrder = false;
  late int _quantity;
  String _selectedPaymentMethod = 'COD';
  FarmerProfile? _farmerProfile;

  static const List<String> _paymentOptions = ['COD', 'COP'];

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity;
    _loadAddresses();
    _loadFarmerProfile();
  }

  Future<void> _loadFarmerProfile() async {
    final farmerId = widget.product.farmerId;
    if (farmerId == null || farmerId.isEmpty) return;
    try {
      final profile = await FarmerService().getFarmerProfileByFarmerId(farmerId);
      if (mounted) {
        setState(() {
          _farmerProfile = profile;
        });
      }
    } catch (e) {
      debugPrint('Error loading farmer profile: $e');
    }
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoadingAddresses = true);
    try {
      final addresses = await _userService.getAllUserAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _selectedAddress = addresses.cast<UserAddress?>().firstWhere(
          (address) => address?.isDefault == true,
          orElse: () => addresses.isNotEmpty ? addresses.first : null,
        );
        _isLoadingAddresses = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingAddresses = false);
    }
  }

  Future<void> _openAddressBook() async {
    await context.push(AppRoutes.addressBook);
    if (!mounted) return;
    await _loadAddresses();
  }

  String _currencyLabel(double value) {
    return '₱${value.toStringAsFixed(2)}';
  }

  double _priceValue() {
    final raw = widget.product.price;
    return double.tryParse(raw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }

  double _calculateSubtotal() {
    return _priceValue() * _quantity;
  }

  double _calculateDeliveryFee() {
    if (_selectedPaymentMethod != 'COD') return 0.0;
    final minAmount = _farmerProfile?.freeDeliveryMinAmount ?? 0.0;
    final subtotal = _calculateSubtotal();
    if (minAmount > 0 && subtotal >= minAmount) {
      return 0.0;
    }
    return 50.0;
  }

  double _calculateTotal() {
    return _calculateSubtotal() + _calculateDeliveryFee();
  }

  Future<void> _submitOrder() async {
    final productId = widget.product.productId;
    final farmerId = widget.product.farmerId;
    if (productId == null ||
        productId.isEmpty ||
        farmerId == null ||
        farmerId.isEmpty) {
      return;
    }

    if (_selectedPaymentMethod == 'COD' && _selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address.')),
      );
      return;
    }

    setState(() => _isSubmittingOrder = true);
    try {
      await _orderService.createOfflineOrder(
        farmerId: farmerId,
        items: [
          OrderItemInput(
            productId: productId,
            quantity: _quantity.toDouble(),
            unitPrice: _priceValue(),
          ),
        ],
        paymentMethod: _selectedPaymentMethod,
        deliveryAddressId:
            _selectedPaymentMethod == 'COP' ? null : _selectedAddress?.addressId,
        notes: _instructionsController.text.trim(),
        deliveryFee: _calculateDeliveryFee(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully!')),
      );
      context.go(AppRoutes.customerOrders);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSubmittingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 980;

    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 32,
                24,
                isCompact ? 16 : 32,
                48,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBreadcrumbs(),
                      const SizedBox(height: 24),
                      isCompact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildOrderSummaryCard(),
                                const SizedBox(height: 24),
                                _buildCheckoutDetailsCard(),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: _buildCheckoutDetailsCard(),
                                ),
                                const SizedBox(width: 28),
                                Expanded(
                                  flex: 5,
                                  child: _buildOrderSummaryCard(),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: _white,
          border: Border(bottom: BorderSide(color: _border)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => context.go(AppRoutes.productDetails, extra: widget.product),
              icon: const Icon(Icons.arrow_back_rounded, color: _dark),
            ),
            const SizedBox(width: 8),
            Text(
              'Checkout',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    return Row(
      children: [
        _breadcrumb('Shop', () => context.go(AppRoutes.shop)),
        _crumbArrow(),
        _breadcrumb(widget.product.name, () => context.go(AppRoutes.productDetails, extra: widget.product)),
        _crumbArrow(),
        Text(
          'Checkout',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
      ],
    );
  }

  Widget _breadcrumb(String label, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: _primary),
        ),
      ),
    );
  }

  Widget _crumbArrow() =>
      const Icon(Icons.chevron_right_rounded, size: 18, color: _muted);

  Widget _buildCheckoutDetailsCard() {
    final requiresAddress = _selectedPaymentMethod == 'COD';

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fulfillment Options',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _selectedPaymentMethod,
            items: _paymentOptions
                .map(
                  (method) => DropdownMenuItem<String>(
                    value: method,
                    child: Text(
                      method == 'COD' ? 'Cash on Delivery (COD)' : 'Cash on Pickup (COP)',
                      style: GoogleFonts.inter(fontSize: 14, color: _dark),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedPaymentMethod = value);
            },
            decoration: InputDecoration(
              labelText: 'Payment method',
              labelStyle: GoogleFonts.inter(color: _muted),
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            requiresAddress ? 'Shipping Address' : 'Pickup Location (at Farm)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 10),
          if (_isLoadingAddresses)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(color: _primary),
              ),
            )
          else if (requiresAddress)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAddressPanel(),
                const SizedBox(height: 24),
              ],
            )
          else
            Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pickup will be arranged directly with the farmer.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.product.farm,
                        style: GoogleFonts.inter(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          Text(
            'Special Instructions',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _instructionsController,
            maxLines: 3,
            style: GoogleFonts.inter(fontSize: 14, color: _dark),
            decoration: InputDecoration(
              hintText: 'Notes for the farmer, e.g. preferred delivery time, landmarks...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressPanel() {
    if (_addresses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'No saved address found. Add one first to use Cash on Delivery.',
                style: GoogleFonts.inter(fontSize: 13, color: _muted),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _openAddressBook,
              child: Text(
                'Manage',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _primary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedAddress?.addressId,
          items: _addresses
              .map(
                (address) => DropdownMenuItem<String>(
                  value: address.addressId,
                  child: Text(
                    '${address.label} • ${address.city}',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 14, color: _dark),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedAddress = _addresses.cast<UserAddress?>().firstWhere(
                (address) => address?.addressId == value,
                orElse: () => null,
              );
            });
          },
          decoration: InputDecoration(
            labelText: 'Delivery address',
            labelStyle: GoogleFonts.inter(color: _muted),
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedAddress != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 16, color: _muted),
                    const SizedBox(width: 8),
                    Text(
                      _selectedAddress!.recipientName,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _dark),
                    ),
                    const Spacer(),
                    const Icon(Icons.phone_outlined, size: 16, color: _muted),
                    const SizedBox(width: 8),
                    Text(
                      _selectedAddress!.recipientPhone,
                      style: GoogleFonts.inter(fontSize: 13, color: _dark),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: _muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selectedAddress!.street}, ${_selectedAddress!.barangay}, ${_selectedAddress!.city}, ${_selectedAddress!.province}',
                        style: GoogleFonts.inter(fontSize: 13, color: _dark, height: 1.4),
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

  Widget _buildOrderSummaryCard() {
    final subtotal = _calculateSubtotal();
    final deliveryFee = _calculateDeliveryFee();
    final total = _calculateTotal();
    final productImage = widget.product.imageUrl.trim();

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 20),
          // Product Item Row
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: productImage.isNotEmpty
                      ? SafeNetworkImage(
                          imageUrl: productImage,
                          fit: BoxFit.cover,
                          placeholder: Container(color: Colors.grey[100]),
                          errorWidget: Container(
                            color: Colors.grey[100],
                            child: const Icon(Icons.image_outlined, color: _muted),
                          ),
                        )
                      : Container(
                          color: Colors.grey[100],
                          child: const Icon(Icons.image_outlined, color: _muted),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_currencyLabel(_priceValue())} per ${widget.product.unit}',
                      style: GoogleFonts.inter(fontSize: 13, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Quantity Adjustment inside Checkout
          Row(
            children: [
              Text(
                'Quantity',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _dark,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 16),
                      onPressed: () {
                        if (_quantity > 1) {
                          setState(() => _quantity--);
                        }
                      },
                    ),
                    Text(
                      '$_quantity',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 16),
                      onPressed: () {
                        if (_quantity < 99) {
                          setState(() => _quantity++);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.product.unit,
                style: GoogleFonts.inter(fontSize: 13, color: _muted),
              ),
            ],
          ),
          const Divider(height: 36),
          // Cost Details
          _costRow('Subtotal', _currencyLabel(subtotal)),
          const SizedBox(height: 12),
          _costRow('Delivery Fee', deliveryFee > 0 ? _currencyLabel(deliveryFee) : 'Free'),
          const Divider(height: 36),
          Row(
            children: [
              Text(
                'Total Amount',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const Spacer(),
              Text(
                _currencyLabel(total),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmittingOrder ? null : _submitOrder,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: _white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _isSubmittingOrder ? 'Placing Order...' : 'Place Order',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _costRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, color: _muted),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
      ],
    );
  }
}
