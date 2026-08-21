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
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/services/commerce/voucher_service.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../widgets/web_consumer_nav_bar.dart';

/// Dedicated full-page checkout for cart items (web).
class WebCartCheckoutScreen extends StatefulWidget {
  const WebCartCheckoutScreen({super.key});

  @override
  State<WebCartCheckoutScreen> createState() => _WebCartCheckoutScreenState();
}

class _WebCartCheckoutScreenState extends State<WebCartCheckoutScreen> {
  static const Color _primary = Color(0xFF059669);
  static const Color _primaryDark = Color(0xFF047857);
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
  String _selectedDeliverySlot = 'morning'; // 'morning' | 'afternoon'

  List<FarmerProfile> _farmerProfiles = [];
  late List<CartItem> _cartItems;
  final Map<String, Map<String, dynamic>> _selectedVouchersByFarmer = {};

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

  double _calculateVoucherDiscountForFarmer(String farmerId, double farmerSubtotal) {
    final v = _selectedVouchersByFarmer[farmerId];
    if (v == null) return 0.0;
    final type = v['discount_type'] ?? '';
    final val = (v['discount_value'] as num).toDouble();
    if (type == 'flat') {
      return val;
    } else {
      final disc = farmerSubtotal * (val / 100);
      final maxDisc = v['max_discount'] != null ? (v['max_discount'] as num).toDouble() : null;
      if (maxDisc != null && disc > maxDisc) return maxDisc;
      return disc;
    }
  }

  double _totalVoucherDiscount() {
    double totalDiscount = 0.0;
    final Map<String, double> subtotalByFarmer = {};
    for (final item in _cartItems) {
      subtotalByFarmer[item.farmerId] = (subtotalByFarmer[item.farmerId] ?? 0.0) + item.total;
    }
    for (final entry in subtotalByFarmer.entries) {
      totalDiscount += _calculateVoucherDiscountForFarmer(entry.key, entry.value);
    }
    return totalDiscount;
  }

  double _subtotal() {
    double total = 0;
    for (final item in _cartItems) {
      total += item.total;
    }
    return total;
  }

  double _grandTotal() {
    final total = _subtotal() + _totalDeliveryFee() - _totalVoucherDiscount();
    return total < 0 ? 0.0 : total;
  }

  String _currency(double value) => '₱${value.toStringAsFixed(2)}';

  // ─── Submit ───

  Future<void> _submitOrder() async {
    if (_cartItems.isEmpty) return;

    if (_paymentMethod == 'COD' && _selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a delivery address.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmittingOrder = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
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

      final deliverySlotNote = _selectedDeliverySlot == 'morning'
          ? 'Preferred: Morning Dispatch (8AM - 12PM)'
          : 'Preferred: Afternoon Dispatch (1PM - 5PM)';
      final combinedNotes = _instructionsController.text.trim().isEmpty
          ? deliverySlotNote
          : '$deliverySlotNote | Notes: ${_instructionsController.text.trim()}';

      for (final entry in itemsByFarmer.entries) {
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

        final farmerDiscount = _calculateVoucherDiscountForFarmer(entry.key, farmerSubtotal);

        await orderService.createOfflineOrder(
          farmerId: entry.key,
          items: entry.value,
          paymentMethod: _paymentMethod,
          deliveryAddressId: _paymentMethod == 'COP' ? null : _selectedAddress?.addressId,
          notes: combinedNotes,
          deliveryFee: farmerDeliveryFee,
          discount: farmerDiscount,
        );

        final farmerVoucher = _selectedVouchersByFarmer[entry.key];
        if (farmerVoucher != null) {
          await VoucherService().markVoucherAsUsed(
            farmerVoucher['claim_id'],
            farmerVoucher['voucher_id'],
          );
        }
      }

      String? firstCategory;
      if (_cartItems.isNotEmpty) {
        try {
          final firstProduct = await SupabaseDataService().getProductById(_cartItems.first.productId);
          firstCategory = firstProduct?.categoryName;
        } catch (_) {}
      }

      await CartService().removeSelected();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Order placed successfully! Direct from Pangasinan farms.'),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go(AppRoutes.orderSuccess, extra: firstCategory);
    } catch (e) {
      if (!mounted) return;
      final rawMessage = e.toString().replaceFirst('Exception: ', '');
      final message = rawMessage.contains('Customer profile not found')
          ? 'Customer profile not found. Please complete your profile first.'
          : rawMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order: $message'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
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

    final sw = MediaQuery.of(context).size.width;
    final isCompact = sw < 980;

    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          Column(
            children: [
              WebConsumerNavBar(
                currentIndex: -1,
                onNavigate: (i) => context.go(AppRoutes.webTabRoute(i)),
                onCartTap: () => context.go(AppRoutes.cart),
                isCartActive: true,
                margin: EdgeInsets.fromLTRB(
                  isCompact ? 16 : 32,
                  20,
                  isCompact ? 16 : 32,
                  12,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 16 : 36,
                    12,
                    isCompact ? 16 : 36,
                    48,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1360),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStepperHeader(isCompact),
                          const SizedBox(height: 24),
                          if (isCompact)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFulfillmentDetailsCard(),
                                const SizedBox(height: 24),
                                _buildOrderSummaryCard(),
                              ],
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 62,
                                  child: _buildFulfillmentDetailsCard(),
                                ),
                                const SizedBox(width: 28),
                                Expanded(
                                  flex: 38,
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
          if (_isSubmittingOrder)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: _primary,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Confirming Farm Direct Order...',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Dispatching details to local growers',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── 3-Step Visual Checkout Stepper ───────────────────────────────────────
  Widget _buildStepperHeader(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x03000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go(AppRoutes.cart),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20, color: _dark),
                    splashRadius: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Order Checkout',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isCompact ? 18 : 22,
                      fontWeight: FontWeight.w900,
                      color: _dark,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_bag_rounded, size: 14, color: _primaryDark),
                    const SizedBox(width: 6),
                    Text(
                      '${_cartItems.length} item${_cartItems.length == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          // 3-Step Progress Bar
          Row(
            children: [
              _stepIndicator('1', 'Cart Review', true, false),
              _stepConnector(true),
              _stepIndicator('2', 'Shipping & Payment', true, true),
              _stepConnector(false),
              _stepIndicator('3', 'Confirmation', false, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepIndicator(String stepNum, String title, bool isComplete, bool isActive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isActive ? _primary : (isComplete ? const Color(0xFFDCFCE7) : _surface),
            shape: BoxShape.circle,
            border: Border.all(color: isActive || isComplete ? _primary : _border),
          ),
          child: Center(
            child: isComplete && !isActive
                ? const Icon(Icons.check_rounded, size: 14, color: _primaryDark)
                : Text(
                    stepNum,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isActive ? Colors.white : _muted,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? _dark : _muted,
          ),
        ),
      ],
    );
  }

  Widget _stepConnector(bool isComplete) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: isComplete ? _primary : const Color(0xFFE2E8F0),
      ),
    );
  }

  // ─── Left Column: Fulfillment Details ──────────────────────────────────────
  Widget _buildFulfillmentDetailsCard() {
    final requiresAddress = _paymentMethod == 'COD';

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          _buildSectionHeader(Icons.local_shipping_rounded, 'Fulfillment & Delivery Method'),
          const SizedBox(height: 16),

          // Payment Option Cards
          Row(
            children: [
              Expanded(
                child: _buildFulfillmentOption(
                  code: 'COD',
                  title: 'Cash on Delivery (COD)',
                  subtitle: 'Pay cash when produce arrives at your doorstep',
                  icon: Icons.delivery_dining_rounded,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildFulfillmentOption(
                  code: 'COP',
                  title: 'Cash on Pickup (COP)',
                  subtitle: 'Collect directly at the grower’s farm location',
                  icon: Icons.storefront_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 24),

          // Shipping Address / Farm Pickup Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(
                requiresAddress ? Icons.location_on_rounded : Icons.agriculture_rounded,
                requiresAddress ? 'Delivery Destination' : 'Farm Pickup Location',
              ),
              if (requiresAddress)
                TextButton.icon(
                  onPressed: _openAddressBook,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 16, color: _primary),
                  label: Text(
                    'Manage Addresses',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoadingAddresses)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: _primary),
              ),
            )
          else if (requiresAddress)
            _buildAddressPanel()
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.pin_drop_rounded, color: _primaryDark, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Direct Farm Collection',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pickup instructions & farm gate coordinates will be provided upon order confirmation.',
                          style: GoogleFonts.inter(fontSize: 12.5, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 26),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 24),

          // Preferred Delivery Time Slot
          _buildSectionHeader(Icons.schedule_rounded, 'Preferred Dispatch Time Slot'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimeSlotOption(
                  id: 'morning',
                  title: '🌅 Morning Dispatch',
                  timeRange: '8:00 AM – 12:00 PM (Early Harvest)',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildTimeSlotOption(
                  id: 'afternoon',
                  title: '🌇 Afternoon Dispatch',
                  timeRange: '1:00 PM – 5:00 PM (Evening Batch)',
                ),
              ),
            ],
          ),

          const SizedBox(height: 26),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 24),

          // Special Instructions for Farmer
          _buildSectionHeader(Icons.speaker_notes_outlined, 'Special Instructions for Local Farmer'),
          const SizedBox(height: 12),
          TextField(
            controller: _instructionsController,
            maxLines: 3,
            style: GoogleFonts.inter(fontSize: 13.5, color: _dark),
            decoration: InputDecoration(
              hintText: 'e.g. Leave with security guard, preferred ripeness level, landmark near green gate...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
      ],
    );
  }

  Widget _buildFulfillmentOption({
    required String code,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _paymentMethod == code;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _paymentMethod = code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFECFDF5) : _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primary : _border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: isSelected ? _primaryDark : _muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? _primaryDark : _dark,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, size: 18, color: _primary),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 11.5, color: _muted, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotOption({
    required String id,
    required String title,
    required String timeRange,
  }) {
    final isSelected = _selectedDeliverySlot == id;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _selectedDeliverySlot = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFECFDF5) : _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _primary : _border,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? _primaryDark : _dark,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, size: 16, color: _primary),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              timeRange,
              style: GoogleFonts.inter(fontSize: 11, color: _muted),
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
                'No saved address found. Add one to use Cash on Delivery.',
                style: GoogleFonts.inter(fontSize: 13, color: _muted),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _openAddressBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Add Address'),
            ),
          ],
        ),
      );
    }

    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_rounded, size: 18, color: _primary),
                  const SizedBox(width: 8),
                  Text(
                    _selectedAddress?.recipientName ?? 'Recipient',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _selectedAddress?.label.toUpperCase() ?? 'HOME',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _primaryDark),
                    ),
                  ),
                ],
              ),
              Text(
                _selectedAddress?.recipientPhone ?? '',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _dark),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _selectedAddress != null
                ? '${_selectedAddress!.street}, ${_selectedAddress!.barangay}, ${_selectedAddress!.city}, ${_selectedAddress!.province}'
                : 'Please select an address',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.4),
          ),
        ],
      ),
    );
  }

  // ─── Right Column: Order Summary & Vouchers ────────────────────────────────
  Widget _buildOrderSummaryCard() {
    final subtotal = _subtotal();
    final deliveryFee = _totalDeliveryFee();
    final total = _grandTotal();

    final Map<String, List<CartItem>> itemsByFarmer = {};
    for (final item in _cartItems) {
      itemsByFarmer.putIfAbsent(item.farmerId, () => []);
      itemsByFarmer[item.farmerId]!.add(item);
    }

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _dark,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Item list grouped by farm
          ...itemsByFarmer.entries.map((entry) {
            final farmerId = entry.key;
            final farmerItems = entry.value;
            final profile = _farmerProfiles.cast<FarmerProfile?>().firstWhere(
              (p) => p?.profileId == farmerId,
              orElse: () => null,
            );
            final farmName = profile?.farmName ?? farmerItems.first.farm;
            final farmerSubtotal = farmerItems.fold<double>(0.0, (sum, i) => sum + i.total);

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
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
                      const Icon(Icons.storefront_rounded, size: 16, color: _primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          farmName,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: _dark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...farmerItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildItemRow(item),
                      )),
                  const Divider(height: 12, color: Color(0xFFE2E8F0)),
                  _buildFarmerVoucherRow(farmerId, farmName, farmerSubtotal),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),
          _costRow('Subtotal', _currency(subtotal)),
          const SizedBox(height: 8),
          _costRow(
            'Delivery Fee',
            deliveryFee > 0 ? _currency(deliveryFee) : 'Free Delivery',
            isHighlight: deliveryFee == 0,
          ),
          if (_totalVoucherDiscount() > 0) ...[
            const SizedBox(height: 8),
            _costRow(
              'Voucher Discount',
              '-${_currency(_totalVoucherDiscount())}',
              isDiscount: true,
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          // Total Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Amount',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Direct farmgate pricing', style: GoogleFonts.inter(fontSize: 11, color: _muted)),
                ],
              ),
              Text(
                _currency(total),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Place Order Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmittingOrder ? null : _submitOrder,
              icon: _isSubmittingOrder
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(
                _isSubmittingOrder ? 'Placing Order...' : 'Place Order Now',
                style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Safety Seal
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: _primaryDark),
                const SizedBox(width: 5),
                Text(
                  '100% Cash on Delivery Protected • No Prepayment',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _muted),
                ),
              ],
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
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 44,
            height: 44,
            child: item.imageUrl.isNotEmpty
                ? SafeNetworkImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: Container(color: Colors.grey[100], child: const Icon(Icons.eco_rounded, size: 18, color: _primary)),
                  )
                : Container(color: Colors.grey[100], child: const Icon(Icons.eco_rounded, size: 18, color: _primary)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${item.quantity} ${item.unit} × ₱${item.priceValue.toStringAsFixed(0)}',
                style: GoogleFonts.inter(fontSize: 11.5, color: _muted),
              ),
            ],
          ),
        ),
        Text(
          _currency(item.total),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
      ],
    );
  }

  Widget _buildFarmerVoucherRow(String farmerId, String farmName, double farmerSubtotal) {
    final selectedVoucher = _selectedVouchersByFarmer[farmerId];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.confirmation_number_outlined, color: _primaryDark, size: 15),
            const SizedBox(width: 5),
            Text(
              selectedVoucher != null ? 'Voucher Applied' : 'Shop Voucher',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: _dark),
            ),
          ],
        ),
        TextButton(
          onPressed: () => _openVoucherSelectionDialogForFarmer(farmerId, farmName, farmerSubtotal),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 20)),
          child: Text(
            selectedVoucher == null ? 'Select Voucher' : 'Change (${selectedVoucher['code']})',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: _primary,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openVoucherSelectionDialogForFarmer(
    String farmerId,
    String farmName,
    double farmerSubtotal,
  ) async {
    final currentUserId = AuthService().userId;
    if (currentUserId.isEmpty) return;

    final voucherService = VoucherService();
    bool isLoading = true;
    List<Map<String, dynamic>> validVouchers = [];

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (isLoading) {
              voucherService.getUserClaimedVouchersForFarmer(currentUserId, farmerId).then((vouchers) {
                setModalState(() {
                  validVouchers = vouchers.where((v) {
                    final minSpend = (v['min_spend'] as num?)?.toDouble() ?? 0.0;
                    return farmerSubtotal >= minSpend;
                  }).toList();
                  isLoading = false;
                });
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Vouchers for $farmName', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
              content: SizedBox(
                width: 400,
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator(color: _primary)),
                      )
                    : validVouchers.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No eligible vouchers available for this order amount.',
                              style: GoogleFonts.inter(fontSize: 13, color: _muted),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: validVouchers.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final v = validVouchers[i];
                              return ListTile(
                                tileColor: _surface,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                title: Text(v['code'] ?? 'VOUCHER', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13)),
                                subtitle: Text(v['description'] ?? '', style: GoogleFonts.inter(fontSize: 11)),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
                                  onPressed: () {
                                    setState(() => _selectedVouchersByFarmer[farmerId] = v);
                                    Navigator.pop(dialogCtx);
                                  },
                                  child: const Text('Apply'),
                                ),
                              );
                            },
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _costRow(String label, String value, {bool isHighlight = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: _muted)),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDiscount
                ? const Color(0xFFDC2626)
                : (isHighlight ? _primaryDark : _dark),
          ),
        ),
      ],
    );
  }
}
