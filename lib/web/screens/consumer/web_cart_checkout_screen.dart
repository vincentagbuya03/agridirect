import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/models/auth/user_address_model.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/services/user/user_service.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../../shared/models/farmer/farmer_profile_model.dart';
import '../../../shared/services/farmer/farmer_service.dart';
import '../../../shared/data/app_data.dart';


/// Dedicated full-page checkout for cart items (web).
class WebCartCheckoutScreen extends StatefulWidget {
  const WebCartCheckoutScreen({super.key});

  @override
  State<WebCartCheckoutScreen> createState() => _WebCartCheckoutScreenState();
}

class _WebCartCheckoutScreenState extends State<WebCartCheckoutScreen> {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _white = Colors.white;

  final UserService _userService = UserService();
  final TextEditingController _instructionsController = TextEditingController();

  List<UserAddress> _addresses = const [];
  UserAddress? _selectedAddress;
  bool _isLoadingAddresses = true;
  bool _isSubmittingOrder = false;
  String _paymentMethod = 'COD';

  List<FarmerProfile> _farmerProfiles = [];
  late List<CartItem> _cartItems;

  @override
  void initState() {
    super.initState();
    _cartItems = List.from(CartService().selectedItems);
    _loadAddresses();
    _loadFarmerProfiles();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadFarmerProfiles() async {
    final farmerIds = _cartItems.map((item) => item.farmerId).toSet().toList();
    try {
      final profiles = await FarmerService().getFarmerProfilesByIds(farmerIds);
      if (mounted) setState(() => _farmerProfiles = profiles);
    } catch (e) {
      debugPrint('Error loading farmer profiles: $e');
    }
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

  // ─── Delivery fee calculations ───

  double _totalDeliveryFee() {
    if (_paymentMethod != 'COD') return 0.0;

    final Map<String, double> subtotalByFarmer = {};
    for (final item in _cartItems) {
      subtotalByFarmer[item.farmerId] =
          (subtotalByFarmer[item.farmerId] ?? 0.0) + item.total;
    }

    double fee = 0.0;
    for (final entry in subtotalByFarmer.entries) {
      final profile = _farmerProfiles.cast<FarmerProfile?>().firstWhere(
        (p) => p?.profileId == entry.key,
        orElse: () => null,
      );
      final minAmount = profile?.freeDeliveryMinAmount ?? 0.0;
      if (minAmount > 0 && entry.value >= minAmount) {
        // Free delivery for this farmer
      } else {
        fee += 50.0;
      }
    }
    return fee;
  }

  double _subtotal() {
    double total = 0;
    for (final item in _cartItems) {
      total += item.total;
    }
    return total;
  }

  double _grandTotal() => _subtotal() + _totalDeliveryFee();

  String _currency(double value) => '₱${value.toStringAsFixed(2)}';

  // ─── Submit ───

  Future<void> _submitOrder() async {
    if (_cartItems.isEmpty) return;

    if (_paymentMethod == 'COD' && _selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address.')),
      );
      return;
    }

    setState(() => _isSubmittingOrder = true);
    try {
      final orderService = OrderService();
      final Map<String, List<OrderItemInput>> itemsByFarmer = {};
      for (final item in _cartItems) {
        itemsByFarmer.putIfAbsent(item.farmerId, () => []);
        itemsByFarmer[item.farmerId]!.add(
          OrderItemInput(
            productId: item.productId,
            quantity: item.quantity.toDouble(),
            unitPrice: item.priceValue,
          ),
        );
      }

      for (final entry in itemsByFarmer.entries) {
        // Calculate per-farmer delivery fee
        final farmerSubtotal = _cartItems
            .where((i) => i.farmerId == entry.key)
            .fold<double>(0.0, (sum, i) => sum + i.total);
        final profile = _farmerProfiles.cast<FarmerProfile?>().firstWhere(
          (p) => p?.profileId == entry.key,
          orElse: () => null,
        );
        final minAmount = profile?.freeDeliveryMinAmount ?? 0.0;
        double farmerDeliveryFee = 50.0;
        if (_paymentMethod != 'COD') {
          farmerDeliveryFee = 0.0;
        } else if (minAmount > 0 && farmerSubtotal >= minAmount) {
          farmerDeliveryFee = 0.0;
        }

        await orderService.createOfflineOrder(
          farmerId: entry.key,
          items: entry.value,
          paymentMethod: _paymentMethod,
          deliveryAddressId:
              _paymentMethod == 'COP' ? null : _selectedAddress?.addressId,
          notes: _instructionsController.text.trim(),
          deliveryFee: farmerDeliveryFee,
        );
      }

      await CartService().removeSelected();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order(s) placed successfully!'),
          backgroundColor: _primary,
        ),
      );
      context.go(AppRoutes.customerOrders);
    } catch (e) {
      if (!mounted) return;
      final rawMessage = e.toString().replaceFirst('Exception: ', '');
      final message = rawMessage.contains('Customer profile not found')
          ? 'Customer profile not found. Please complete your consumer profile first.'
          : rawMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order: $message'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingOrder = false);
    }
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    if (_cartItems.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.cart);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

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

  // ─── Top Bar ───

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
              onPressed: () => context.go(AppRoutes.cart),
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
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_cart_rounded, size: 16, color: _primary),
                  const SizedBox(width: 6),
                  Text(
                    '${_cartItems.length} item${_cartItems.length == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ],
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
        _breadcrumb('Cart', () => context.go(AppRoutes.cart)),
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

  // ─── Left Column: Checkout Details ───

  Widget _buildCheckoutDetailsCard() {
    final requiresAddress = _paymentMethod == 'COD';

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
          // Payment method selection
          Row(
            children: [
              Expanded(child: _buildPaymentOption('COD', 'Cash on Delivery')),
              const SizedBox(width: 12),
              Expanded(child: _buildPaymentOption('COP', 'Cash on Pickup')),
            ],
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
                        'Visit each farm to collect your order(s).',
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
              hintText:
                  'Notes for the farmer, e.g. preferred delivery time, landmarks...',
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

  Widget _buildPaymentOption(String code, String label) {
    final isSelected = _paymentMethod == code;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _paymentMethod = code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _primary.withValues(alpha: 0.08) : _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primary : _border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              code,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isSelected ? _primary : _dark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: _muted),
            ),
          ],
        ),
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
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: _primary),
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
                    const Icon(Icons.person_outline_rounded,
                        size: 16, color: _muted),
                    const SizedBox(width: 8),
                    Text(
                      _selectedAddress!.recipientName,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _dark),
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
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: _muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selectedAddress!.street}, ${_selectedAddress!.barangay}, ${_selectedAddress!.city}, ${_selectedAddress!.province}',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: _dark, height: 1.4),
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

  // ─── Right Column: Order Summary ───

  Widget _buildOrderSummaryCard() {
    final subtotal = _subtotal();
    final deliveryFee = _totalDeliveryFee();
    final total = _grandTotal();

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
          // Item list
          ..._cartItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildItemRow(item),
              )),
          const Divider(height: 28),
          // Cost breakdown
          _costRow('Subtotal', _currency(subtotal)),
          const SizedBox(height: 12),
          _costRow(
            'Delivery Fee',
            deliveryFee > 0 ? _currency(deliveryFee) : 'Free',
          ),
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
                _currency(total),
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

  Widget _buildItemRow(CartItem item) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 56,
            height: 56,
            child: item.imageUrl.isNotEmpty
                ? SafeNetworkImage(
                    imageUrl: item.imageUrl,
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
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${item.quantity} ${item.unit} × ₱${item.priceValue.toStringAsFixed(0)}',
                style: GoogleFonts.inter(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ),
        Text(
          _currency(item.total),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
      ],
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
