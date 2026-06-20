import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/styles/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/services/user/user_service.dart';
import '../../../shared/models/auth/user_address_model.dart';
import 'orders_screen.dart';
import 'marketplace_screen.dart'; // AddressEditorSheet, AddressSelectorSheet
import '../../../shared/data/app_data.dart';
import '../../../shared/models/farmer/farmer_profile_model.dart';
import '../../../shared/services/farmer/farmer_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isOrdering = false;
  UserAddress? _address;
  String _paymentMethod = 'COD';
  bool _isLoadingAddress = true;
  final _instructionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadAddress() async {
    try {
      final addresses = await UserService().getAllUserAddresses();
      if (mounted) {
        setState(() {
          if (addresses.isNotEmpty) {
            _address = addresses.firstWhere(
              (a) => a.isDefault,
              orElse: () => addresses.first,
            );
          }
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  Future<UserAddress?> _openAddressEditor([UserAddress? initialAddress]) async {
    return await showModalBottomSheet<UserAddress>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressEditorSheet(initialAddress: initialAddress),
    );
  }

  Future<UserAddress?> _openAddressSelector() async {
    return await showModalBottomSheet<UserAddress>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressSelectorSheet(currentAddressId: _address?.addressId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Your Cart',
          style: AppTextStyles.headline3.copyWith(fontSize: 20),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textHeadline, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListenableBuilder(
        listenable: CartService(),
        builder: (context, _) {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        final items = CartService().items.where((item) {
          return currentUserId == null || item.farmerId != currentUserId;
        }).toList();

        if (items.isEmpty) {
            return _buildEmptyCart(context);
          }

          return Column(
            children: [
              _buildSelectAllHeader(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildCartItem(context, items[index]),
                ),
              ),
              _buildCheckoutSection(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your cart is empty',
            style: AppTextStyles.headline1.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 12),
          Text(
            'Looks like you haven\'t added anything\nto your cart yet.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSubtle),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: const Text('Start Shopping', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAllHeader() {
    final cart = CartService();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      color: AppColors.background,
      child: Row(
        children: [
          Transform.scale(
            scale: 1.1,
            child: Checkbox(
              value: cart.isAllSelected,
              onChanged: (v) => cart.toggleAll(v ?? false),
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              side: BorderSide(color: AppColors.textHeadline.withValues(alpha: 0.2), width: 1.5),
            ),
          ),
          Text(
            'Select All',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textHeadline,
            ),
          ),
          const Spacer(),
          Text(
            '${cart.items.length} items',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item) {
    return GestureDetector(
      onTap: () => CartService().toggleSelection(item.productId),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: item.isSelected ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textHeadline.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Transform.scale(
              scale: 1.1,
              child: Checkbox(
                value: item.isSelected,
                onChanged: (_) => CartService().toggleSelection(item.productId),
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                side: BorderSide(color: AppColors.textHeadline.withValues(alpha: 0.15), width: 1.5),
              ),
            ),
            const SizedBox(width: 2),
            Hero(
              tag: 'product_image_${item.productId}',
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: AppTextStyles.headline3.copyWith(
                            fontSize: 16,
                            color: AppColors.textHeadline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete_rounded, color: AppColors.error, size: 16),
                        ),
                        onPressed: () => CartService().removeItem(item.productId),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  Text(
                    item.farm,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSubtle,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '₱${item.priceValue.toStringAsFixed(2)}',
                          style: AppTextStyles.headline3.copyWith(
                            color: AppColors.primary,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildQuantitySelector(item),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantitySelector(CartItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQtyBtn(Icons.remove, () {
            CartService().updateQuantity(item.productId, item.quantity - 1);
          }),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${item.quantity}',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textHeadline,
                fontSize: 13,
              ),
            ),
          ),
          _buildQtyBtn(Icons.add, () {
            CartService().updateQuantity(item.productId, item.quantity + 1);
          }),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 14, color: AppColors.textHeadline),
      ),
    );
  }

  Widget _buildCheckoutSection(BuildContext context) {
    final cart = CartService();
    final total = cart.totalAmount;
    final selectedCount = cart.selectedItems.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textHeadline.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected ($selectedCount)',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSubtle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Amount',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textHeadline,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₱${total.toStringAsFixed(2)}',
                  style: AppTextStyles.headline1.copyWith(
                    color: AppColors.primary,
                    fontSize: 26,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: selectedCount > 0 ? _showCheckoutSheet : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_bag_rounded, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Checkout ($selectedCount)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckoutSheet() async {
    final cartItems = CartService().selectedItems;
    if (cartItems.isEmpty) return;

    final farmerIds = cartItems.map((item) => item.farmerId).toSet().toList();
    List<FarmerProfile> farmerProfiles = [];
    try {
      farmerProfiles = await FarmerService().getFarmerProfilesByIds(farmerIds);
    } catch (e) {
      debugPrint('Error pre-fetching farmer profiles: $e');
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          double totalDeliveryFee = 0.0;
          if (_paymentMethod == 'COD') {
            final Map<String, double> subtotalByFarmer = {};
            for (final item in cartItems) {
              subtotalByFarmer[item.farmerId] = (subtotalByFarmer[item.farmerId] ?? 0.0) + (item.priceValue * item.quantity);
            }

            for (final entry in subtotalByFarmer.entries) {
              final farmerId = entry.key;
              final subtotal = entry.value;
              final profile = farmerProfiles.cast<FarmerProfile?>().firstWhere(
                (p) => p?.profileId == farmerId,
                orElse: () => null,
              );
              final minAmount = profile?.freeDeliveryMinAmount ?? 0.0;
              if (minAmount > 0 && subtotal >= minAmount) {
                // Free delivery
              } else {
                totalDeliveryFee += 50.0;
              }
            }
          }

          final grandTotal = CartService().totalAmount + totalDeliveryFee;

          return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textHeadline.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Checkout Confirmation',
                style: AppTextStyles.headline1.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 20),

              // Selected Products List
              Text(
                'Selected Products',
                style: AppTextStyles.headline3.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.1)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: CartService().selectedItems.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: AppColors.textHeadline.withValues(alpha: 0.05),
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final item = CartService().selectedItems[index];
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: item.imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: AppTextStyles.headline3.copyWith(fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${item.quantity} ${item.unit} x ₱${item.priceValue.toStringAsFixed(0)}',
                                      style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                                    ),
                                    Text(
                                      '₱${(item.priceValue * item.quantity).toStringAsFixed(2)}',
                                      style: AppTextStyles.headline3.copyWith(
                                        fontSize: 14,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Address Section
              Text(
                _paymentMethod == 'COP'
                    ? 'Pickup Location (at Farm)'
                    : 'Shipping Address',
                style: AppTextStyles.headline3.copyWith(
                  fontSize: 14,
                  color: AppColors.textHeadline,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.textHeadline.withValues(alpha: 0.1),
                  ),
                ),
                child: _isLoadingAddress
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _paymentMethod == 'COP'
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.storefront_rounded,
                                  size: 20,
                                  color: AppColors.primary.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pickup at Farm',
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'You will need to visit the farmer\'s location to pickup your order(s).',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          fontSize: 11,
                                          color: AppColors.textSubtle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _address == null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No address set yet.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final updatedAddress = await _openAddressEditor();
                                  if (!mounted) return;
                                  if (updatedAddress != null) {
                                    setState(() => _address = updatedAddress);
                                    setSheetState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Shipping address updated.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.add_location_alt_rounded),
                                label: const Text('Add Address'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _address!.label,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _address!.recipientName,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _address!.street,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${_address!.barangay}, ${_address!.city}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSubtle,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final selected = await _openAddressSelector();
                                    if (selected != null && mounted) {
                                      setState(() => _address = selected);
                                      setSheetState(() {});
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.swap_horiz_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Change'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final updated = await _openAddressEditor(_address);
                                    if (updated != null && mounted) {
                                      setState(() => _address = updated);
                                      setSheetState(() {});
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Edit'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),

              // Payment Method
              Text(
                'Payment Method',
                style: AppTextStyles.headline3.copyWith(
                  fontSize: 14,
                  color: AppColors.textHeadline,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentOption(
                      title: 'COD',
                      subtitle: 'Cash on Delivery',
                      isSelected: _paymentMethod == 'COD',
                      onTap: () {
                        setSheetState(() => _paymentMethod = 'COD');
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
                        setSheetState(() => _paymentMethod = 'COP');
                        setState(() => _paymentMethod = 'COP');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Special Instructions (Optional)',
                style: AppTextStyles.headline3.copyWith(
                  fontSize: 14,
                  color: AppColors.textHeadline,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _instructionsController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Leave at the gate, call upon arrival...',
                  hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.textHeadline.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.textHeadline.withValues(alpha: 0.1)),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Order Summary
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal', style: AppTextStyles.bodyMedium),
                      Text(
                        '₱${CartService().totalAmount.toStringAsFixed(2)}',
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Delivery Fee', style: AppTextStyles.bodyMedium),
                      Text(
                        totalDeliveryFee > 0
                            ? '₱${totalDeliveryFee.toStringAsFixed(2)}'
                            : 'Free',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: totalDeliveryFee > 0 ? AppColors.textHeadline : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Amount', style: AppTextStyles.bodyLarge),
                      Text(
                        '₱${grandTotal.toStringAsFixed(2)}',
                        style: AppTextStyles.headline1.copyWith(
                          color: AppColors.primary,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_paymentMethod == 'COD' && _address == null || _isOrdering)
                      ? null
                      : () {
                          Navigator.pop(sheetContext);
                          _handleOrderNow();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _isOrdering ? 'Ordering...' : 'Confirm Order',
                    style: AppTextStyles.headline3.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
);
}

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textHeadline.withValues(alpha: 0.1),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: AppTextStyles.headline3.copyWith(
                fontSize: 16,
                color: isSelected ? AppColors.primary : AppColors.textHeadline,
              ),
            ),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 9,
                color: AppColors.textSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleOrderNow() async {
    final cartItems = CartService().selectedItems;
    if (cartItems.isEmpty) return;

    setState(() => _isOrdering = true);

    try {
      final orderService = OrderService();

      // Group items by farmer
      final Map<String, List<OrderItemInput>> itemsByFarmer = {};
      for (var item in cartItems) {
        if (!itemsByFarmer.containsKey(item.farmerId)) {
          itemsByFarmer[item.farmerId] = [];
        }
        itemsByFarmer[item.farmerId]!.add(
          OrderItemInput(
            productId: item.productId,
            quantity: item.quantity.toDouble(),
            unitPrice: item.priceValue,
          ),
        );
      }

      final farmerIds = itemsByFarmer.keys.toList();
      final farmerProfiles = await FarmerService().getFarmerProfilesByIds(farmerIds);

      // Process orders for each farmer
      for (var entry in itemsByFarmer.entries) {
        final farmerId = entry.key;
        final items = entry.value;

        final subtotal = items.fold<double>(
          0.0,
          (sum, item) => sum + (item.quantity * item.unitPrice),
        );

        double deliveryFee = 0.0;
        if (_paymentMethod == 'COD') {
          final profile = farmerProfiles.cast<FarmerProfile?>().firstWhere(
            (p) => p?.profileId == farmerId,
            orElse: () => null,
          );
          final minAmount = profile?.freeDeliveryMinAmount ?? 0.0;
          if (minAmount > 0 && subtotal >= minAmount) {
            deliveryFee = 0.0;
          } else {
            deliveryFee = 50.0;
          }
        }

        await orderService.createOfflineOrder(
          farmerId: farmerId,
          items: items,
          paymentMethod: _paymentMethod,
          deliveryAddressId: _paymentMethod == 'COP' ? null : _address?.addressId,
          notes: _instructionsController.text.trim(),
          deliveryFee: deliveryFee,
        );
      }

      // Remove selected items from the cart
      CartService().removeSelected();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order(s) placed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      // Navigate to orders screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OrdersScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      final rawMessage = e.toString().replaceFirst('Exception: ', '');
      final message = rawMessage.contains('Customer profile not found')
          ? 'Customer profile not found. Please complete your consumer profile first.'
          : rawMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order: $message'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isOrdering = false);
    }
  }
}
