import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/data/app_data.dart';
import '../../../shared/models/auth/user_address_model.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/services/user/user_service.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../widgets/web_consumer_nav_bar.dart';

class WebCartScreen extends StatefulWidget {
  const WebCartScreen({super.key});

  @override
  State<WebCartScreen> createState() => _WebCartScreenState();
}

class _WebCartScreenState extends State<WebCartScreen> {
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
  String _paymentMethod = 'COD';
  bool _isLoadingAddresses = true;
  bool _isOrdering = false;

  @override
  void initState() {
    super.initState();
    CartService().loadCart();
    _loadAddresses();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  void _handleNav(int index) {
    context.go(AppRoutes.webTabRoute(index));
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

  Future<void> _showCheckoutDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final requiresAddress = _paymentMethod == 'COD';
            final canSubmit =
                !_isOrdering &&
                CartService().selectedItems.isNotEmpty &&
                (!requiresAddress || _selectedAddress != null);

            return AlertDialog(
              backgroundColor: _white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.all(24),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Checkout',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose payment, confirm your delivery details, and place the order.',
                      style: GoogleFonts.inter(fontSize: 14, color: _muted),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Payment Method',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentOption(
                            title: 'COD',
                            subtitle: 'Cash on Delivery',
                            isSelected: _paymentMethod == 'COD',
                            onTap: () {
                              setDialogState(() => _paymentMethod = 'COD');
                              setState(() => _paymentMethod = 'COD');
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPaymentOption(
                            title: 'COP',
                            subtitle: 'Cash on Pickup',
                            isSelected: _paymentMethod == 'COP',
                            onTap: () {
                              setDialogState(() => _paymentMethod = 'COP');
                              setState(() => _paymentMethod = 'COP');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      requiresAddress ? 'Shipping Address' : 'Pickup',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingAddresses)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(color: _primary),
                        ),
                      )
                    else if (!requiresAddress)
                      _buildAddressPanel(
                        title: 'Pickup at the farm',
                        subtitle:
                            'No delivery address is required for Cash on Pickup.',
                        actions: const [],
                      )
                    else if (_addresses.isEmpty)
                      _buildAddressPanel(
                        title: 'No saved address',
                        subtitle:
                            'Add a delivery address first so COD orders can be placed on web.',
                        actions: [
                          TextButton(
                            onPressed: _openAddressBook,
                            child: const Text('Manage Addresses'),
                          ),
                        ],
                      )
                    else
                      _buildAddressSelector(setDialogState),
                    const SizedBox(height: 20),
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
                      decoration: InputDecoration(
                        hintText:
                            'e.g. Leave at the gate, call upon arrival...',
                        hintStyle: GoogleFonts.inter(color: _muted),
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
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border),
                      ),
                      child: _buildSummaryRow(
                        'Total',
                        'P${CartService().totalAmount.toStringAsFixed(2)}',
                        emphasize: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isOrdering
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: canSubmit
                      ? () async {
                          Navigator.of(dialogContext).pop();
                          await _submitCheckout();
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_isOrdering ? 'Ordering...' : 'Confirm Order'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
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
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isSelected ? _primary : _dark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressPanel({
    required String title,
    required String subtitle,
    required List<Widget> actions,
  }) {
    return Container(
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
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 13, color: _muted, height: 1.5),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: actions),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressSelector(StateSetter setDialogState) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedAddress?.addressId,
          decoration: InputDecoration(
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
          ),
          items: _addresses
              .map(
                (address) => DropdownMenuItem<String>(
                  value: address.addressId,
                  child: Text(
                    '${address.label} • ${address.city}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            final address = _addresses.cast<UserAddress?>().firstWhere(
              (item) => item?.addressId == value,
              orElse: () => null,
            );
            setDialogState(() => _selectedAddress = address);
            setState(() => _selectedAddress = address);
          },
        ),
        const SizedBox(height: 12),
        if (_selectedAddress != null)
          _buildAddressPanel(
            title: _selectedAddress!.label,
            subtitle:
                '${_selectedAddress!.recipientName}\n${_selectedAddress!.fullAddress}\n${_selectedAddress!.recipientPhone}',
            actions: [
              TextButton(
                onPressed: _openAddressBook,
                child: const Text('Manage Addresses'),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _submitCheckout() async {
    final cartItems = CartService().selectedItems;
    if (cartItems.isEmpty) return;

    setState(() => _isOrdering = true);
    try {
      final orderService = OrderService();
      final Map<String, List<OrderItemInput>> itemsByFarmer = {};
      for (final item in cartItems) {
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
        await orderService.createOfflineOrder(
          farmerId: entry.key,
          items: entry.value,
          paymentMethod: _paymentMethod,
          deliveryAddressId:
              _paymentMethod == 'COP' ? null : _selectedAddress?.addressId,
          notes: _instructionsController.text.trim(),
        );
      }

      await CartService().removeSelected();
      _instructionsController.clear();

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
      if (mounted) setState(() => _isOrdering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          WebConsumerNavBar(
            currentIndex: -1,
            onNavigate: _handleNav,
            onCartTap: () {},
            isCartActive: true,
            margin: const EdgeInsets.fromLTRB(32, 20, 32, 12),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: CartService(),
              builder: (context, _) {
                final cart = CartService();
                final items = cart.items;

                if (items.isEmpty) {
                  return _buildEmptyState();
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Cart',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Review what you added before checkout.',
                        style: GoogleFonts.inter(fontSize: 14, color: _muted),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: items
                                  .map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: _buildCartItem(item),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(child: _buildSummaryCard(cart)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 42,
                color: _primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your cart is empty',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add products from the shop and they will appear here.',
              style: GoogleFonts.inter(fontSize: 14, color: _muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(AppRoutes.shop),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Browse Products',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Checkbox(
            value: item.isSelected,
            activeColor: _primary,
            onChanged: (_) => CartService().toggleSelection(item.productId),
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: item.imageUrl.isNotEmpty
                ? SafeNetworkImage(
                    imageUrl: item.imageUrl,
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                    errorWidget: _buildImageFallback(),
                  )
                : _buildImageFallback(),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.farm,
                  style: GoogleFonts.inter(fontSize: 13, color: _muted),
                ),
                const SizedBox(height: 10),
                Text(
                  '${item.price} ${item.unit}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildQuantityControl(item),
          const SizedBox(width: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'P${item.total.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: () => CartService().removeItem(item.productId),
                child: Text(
                  'Remove',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFDC2626),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      width: 110,
      height: 110,
      color: _surface,
      child: const Icon(Icons.image_outlined, color: _muted, size: 30),
    );
  }

  Widget _buildQuantityControl(CartItem item) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                CartService().updateQuantity(item.productId, item.quantity - 1),
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          Text(
            '${item.quantity}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          IconButton(
            onPressed: () =>
                CartService().updateQuantity(item.productId, item.quantity + 1),
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(CartService cart) {
    final selectedCount = cart.selectedItems.length;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 18),
          _buildSummaryRow('Selected items', '$selectedCount'),
          const SizedBox(height: 10),
          _buildSummaryRow(
            'Subtotal',
            'P${cart.totalAmount.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 10),
          _buildSummaryRow('Delivery', 'Calculated at checkout'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(height: 1),
          ),
          _buildSummaryRow(
            'Total',
            'P${cart.totalAmount.toStringAsFixed(2)}',
            emphasize: true,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: selectedCount == 0
                  ? null
                  : _showCheckoutDialog,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                disabledBackgroundColor: _border,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Checkout',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go(AppRoutes.shop),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(color: _border),
              ),
              child: Text(
                'Continue Shopping',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: emphasize ? 15 : 14,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            color: emphasize ? _dark : _muted,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: emphasize ? 17 : 14,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: _dark,
          ),
        ),
      ],
    );
  }
}
