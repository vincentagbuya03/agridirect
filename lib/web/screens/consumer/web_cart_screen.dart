import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../constants/web_design_tokens.dart';
import '../../widgets/web_footer.dart';
import '../../widgets/ecom/web_ecom_header.dart';
import '../../widgets/ecom/web_multi_farm_cart_group.dart';

/// Flagship Multi-Vendor E-Commerce Cart Screen for AgriDirect Web
class WebCartScreen extends StatefulWidget {
  const WebCartScreen({super.key});

  @override
  State<WebCartScreen> createState() => _WebCartScreenState();
}

class _WebCartScreenState extends State<WebCartScreen> {
  final TextEditingController _voucherCtrl = TextEditingController();
  String? _appliedVoucher;
  double _discountAmount = 0.0;

  @override
  void dispose() {
    _voucherCtrl.dispose();
    super.dispose();
  }

  void _applyVoucher() {
    final code = _voucherCtrl.text.trim().toUpperCase();
    if (code == 'FARMDIRECT' || code == 'SANCARLOS') {
      setState(() {
        _appliedVoucher = code;
        _discountAmount = 30.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voucher applied! Saved ₱30 on your order.'),
          backgroundColor: WebDesignTokens.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid voucher code. Try "FARMDIRECT" or "SANCARLOS"'),
          backgroundColor: WebDesignTokens.discountRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final containerWidth = WebBreakpoints.containerWidth(sw);
    final isCompact = sw < 1024;
    final isMobile = WebBreakpoints.isMobile(sw);

    return ListenableBuilder(
      listenable: CartService(),
      builder: (context, _) {
        final cart = CartService();
        final items = cart.items;
        final selectedItems = cart.selectedItems;
        final subtotal = cart.selectedTotal;
        final deliveryFee = subtotal >= 500 || subtotal == 0 ? 0.0 : 45.0;
        final finalTotal = (subtotal + deliveryFee - _discountAmount).clamp(0.0, double.infinity);

        // Group items by Farm
        final Map<String, List<CartItem>> groupedByFarm = {};
        for (final item in items) {
          final key = item.farm.isNotEmpty ? item.farm : 'San Carlos Cooperative';
          groupedByFarm.putIfAbsent(key, () => []).add(item);
        }

        return Scaffold(
          backgroundColor: WebDesignTokens.bg,
          body: Column(
            children: [
              // ─── Header ───
              WebEcomHeader(
                currentIndex: 4,
                onNavigate: (index, [route]) {
                  if (route != null) {
                    context.go(route);
                  } else {
                    context.go(AppRoutes.webTabRoute(index));
                  }
                },
              ),

              // ─── Cart Content ───
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),

                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: containerWidth),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 12 : 24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title & Stepper Breadcrumb
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Shopping Cart (${cart.itemCount})',
                                      style: GoogleFonts.rubik(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: WebDesignTokens.dark,
                                      ),
                                    ),
                                    Text(
                                      'Step 1 of 3: Cart Review',
                                      style: GoogleFonts.nunitoSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: WebDesignTokens.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                if (items.isEmpty)
                                  _buildEmptyCart(context)
                                else if (isCompact)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildSelectAllBar(cart),
                                      const SizedBox(height: 16),
                                      _buildFarmGroupsList(groupedByFarm, cart),
                                      const SizedBox(height: 24),
                                      _buildOrderSummaryCard(
                                        context,
                                        cart,
                                        selectedItems,
                                        subtotal,
                                        deliveryFee,
                                        finalTotal,
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Left Column: Farm Groups (8 cols)
                                      Expanded(
                                        flex: 8,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildSelectAllBar(cart),
                                            const SizedBox(height: 16),
                                            _buildFarmGroupsList(
                                                groupedByFarm, cart),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 28),

                                      // Right Column: Order Summary Card (4 cols)
                                      Expanded(
                                        flex: 4,
                                        child: _buildOrderSummaryCard(
                                          context,
                                          cart,
                                          selectedItems,
                                          subtotal,
                                          deliveryFee,
                                          finalTotal,
                                        ),
                                      ),
                                    ],
                                  ),

                                const SizedBox(height: 48),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Footer
                      const AgriDirectWebFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectAllBar(CartService cart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: WebDesignTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WebDesignTokens.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Checkbox(
                value: cart.isAllSelected,
                activeColor: WebDesignTokens.primary,
                onChanged: (val) => cart.toggleAll(val ?? false),
              ),
              const SizedBox(width: 4),
              Text(
                'Select All (${cart.totalQuantity} items)',
                style: GoogleFonts.rubik(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: WebDesignTokens.dark,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              for (final item in cart.selectedItems) {
                cart.removeItem(item.productId);
              }
            },
            child: Text(
              'Remove Selected',
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: WebDesignTokens.discountRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmGroupsList(
    Map<String, List<CartItem>> groups,
    CartService cart,
  ) {
    return Column(
      children: groups.entries.map((entry) {
        final farmName = entry.key;
        final farmItems = entry.value;
        final farmerId = farmItems.first.farmerId;
        final isSelected = cart.isFarmSelected(farmerId);

        return WebMultiFarmCartGroup(
          farmName: farmName,
          farmerId: farmerId,
          items: farmItems,
          isSelected: isSelected,
          onSelectAll: (val) => cart.toggleFarmSelection(farmerId, val ?? false),
          onToggleItem: (item, val) => cart.toggleSelection(item.productId),
          onQuantityChanged: (item, qty) =>
              cart.updateQuantity(item.productId, qty),
          onItemRemoved: (item) => cart.removeItem(item.productId),
          onChatFarmer: () => context.push(AppRoutes.messages),
        );
      }).toList(),
    );
  }

  Widget _buildOrderSummaryCard(
    BuildContext context,
    CartService cart,
    List<CartItem> selectedItems,
    double subtotal,
    double deliveryFee,
    double finalTotal,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: WebDesignTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WebDesignTokens.border),
        boxShadow: WebDesignTokens.cardRest,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Order Summary',
            style: GoogleFonts.rubik(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: WebDesignTokens.dark,
            ),
          ),
          const Divider(height: 24, color: WebDesignTokens.border),

          // Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Produce Subtotal',
                style: GoogleFonts.nunitoSans(
                  fontSize: 14,
                  color: WebDesignTokens.slate600,
                ),
              ),
              Text(
                '₱${subtotal.toStringAsFixed(2)}',
                style: GoogleFonts.rubik(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: WebDesignTokens.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Delivery
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Local Delivery Fee',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 14,
                      color: WebDesignTokens.slate600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: WebDesignTokens.slate400),
                ],
              ),
              Text(
                deliveryFee == 0.0 ? 'FREE' : '₱${deliveryFee.toStringAsFixed(2)}',
                style: GoogleFonts.rubik(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: deliveryFee == 0.0
                      ? WebDesignTokens.primary
                      : WebDesignTokens.dark,
                ),
              ),
            ],
          ),

          if (deliveryFee == 0.0) ...[
            const SizedBox(height: 4),
            Text(
              '🎉 Free delivery unlocked on orders ₱500+!',
              style: GoogleFonts.nunitoSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: WebDesignTokens.primary,
              ),
            ),
          ],

          if (_discountAmount > 0) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Voucher Discount ($_appliedVoucher)',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: WebDesignTokens.discountRed,
                  ),
                ),
                Text(
                  '-₱${_discountAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.rubik(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: WebDesignTokens.discountRed,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 24, color: WebDesignTokens.border),

          // Voucher Code Input
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _voucherCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter Voucher Code',
                      hintStyle: GoogleFonts.nunitoSans(fontSize: 12),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: WebDesignTokens.border),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: WebDesignTokens.dark,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _applyVoucher,
                child: const Text('Apply'),
              ),
            ],
          ),
          const Divider(height: 28, color: WebDesignTokens.border),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Total Amount',
                style: GoogleFonts.rubik(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: WebDesignTokens.dark,
                ),
              ),
              Text(
                '₱${finalTotal.toStringAsFixed(2)}',
                style: GoogleFonts.rubik(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: WebDesignTokens.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Proceed Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: WebDesignTokens.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: selectedItems.isEmpty
                ? null
                : () => context.go(AppRoutes.cartCheckout),
            child: Text(
              'Proceed to Checkout (${selectedItems.length} items)',
              style: GoogleFonts.rubik(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Trust Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security_rounded,
                  size: 15, color: WebDesignTokens.primary),
              const SizedBox(width: 6),
              Text(
                '100% AgriDirect Escrow & Farmer Protection',
                style: GoogleFonts.nunitoSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: WebDesignTokens.slate500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(60),
      decoration: BoxDecoration(
        color: WebDesignTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WebDesignTokens.border),
      ),
      child: Column(
        children: [
          Icon(Icons.shopping_bag_outlined,
              size: 64, color: WebDesignTokens.slate400),
          const SizedBox(height: 16),
          Text(
            'Your Shopping Cart is Empty',
            style: GoogleFonts.rubik(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: WebDesignTokens.dark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Explore fresh local harvests direct from San Carlos City growers!',
            style: GoogleFonts.nunitoSans(
              fontSize: 14,
              color: WebDesignTokens.slate500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: WebDesignTokens.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.storefront_rounded, size: 20),
            label: Text(
              'Shop Today\'s Harvest >',
              style: GoogleFonts.rubik(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => context.go(AppRoutes.shop),
          ),
        ],
      ),
    );
  }
}
