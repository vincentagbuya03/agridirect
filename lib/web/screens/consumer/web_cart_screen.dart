import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../widgets/web_consumer_nav_bar.dart';

class WebCartScreen extends StatefulWidget {
  const WebCartScreen({super.key});

  @override
  State<WebCartScreen> createState() => _WebCartScreenState();
}

class _WebCartScreenState extends State<WebCartScreen> {
  static const Color _primary = Color(0xFF059669);
  static const Color _primaryDark = Color(0xFF047857);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _white = Colors.white;

  @override
  void initState() {
    super.initState();
    CartService().loadCart();
  }

  void _handleNav(int index) {
    context.go(AppRoutes.webTabRoute(index));
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isCompact = sw < 980;

    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          WebConsumerNavBar(
            currentIndex: -1,
            onNavigate: _handleNav,
            onCartTap: () {},
            isCartActive: true,
            margin: EdgeInsets.fromLTRB(
              isCompact ? 16 : 32,
              20,
              isCompact ? 16 : 32,
              12,
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: CartService(),
              builder: (context, _) {
                final cart = CartService();
                final items = cart.items;

                if (items.isEmpty) {
                  return _buildEmptyState(isCompact);
                }

                final selectedCount = cart.selectedItems.length;
                final allSelected = items.isNotEmpty && items.every((i) => i.isSelected);

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 16 : 36,
                    8,
                    isCompact ? 16 : 36,
                    48,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1360),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCartHeader(items.length, selectedCount, isCompact),
                          const SizedBox(height: 20),
                          _buildMasterToolbar(items, allSelected, selectedCount, isCompact),
                          const SizedBox(height: 18),
                          if (isCompact)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildItemsList(items, true),
                                const SizedBox(height: 20),
                                _buildOrderSummaryCard(cart, isCompact),
                                const SizedBox(height: 20),
                                _buildTrustGuaranteesCard(),
                              ],
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column (65%): Farm-Grouped Cart Items
                                Expanded(
                                  flex: 65,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildItemsList(items, false),
                                      const SizedBox(height: 24),
                                      _buildTrustGuaranteesCard(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 28),

                                // Right Column (35%): Sticky Order Summary
                                Expanded(
                                  flex: 35,
                                  child: _buildOrderSummaryCard(cart, isCompact),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildCartHeader(int totalItems, int selectedCount, bool isCompact) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_bag_rounded, size: 13, color: _primary),
                      const SizedBox(width: 5),
                      Text(
                        'DIRECT FARM CART',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _primaryDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your Fresh Harvest Cart',
              style: GoogleFonts.plusJakartaSans(
                fontSize: isCompact ? 24 : 30,
                fontWeight: FontWeight.w900,
                color: _dark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Review items, adjust quantities, and support local Pangasinan farmers directly.',
              style: GoogleFonts.inter(
                fontSize: isCompact ? 12.5 : 13.5,
                color: _muted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Master Toolbar (Select All + Bulk Actions) ────────────────────────────
  Widget _buildMasterToolbar(List<CartItem> items, bool allSelected, int selectedCount, bool isCompact) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x03000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Checkbox(
                value: allSelected,
                activeColor: _primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                onChanged: (val) {
                  final target = val ?? false;
                  for (final item in items) {
                    if (item.isSelected != target) {
                      CartService().toggleSelection(item.productId);
                    }
                  }
                },
              ),
              const SizedBox(width: 6),
              Text(
                'Select All (${items.length} items)',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
            ],
          ),
          if (selectedCount > 0)
            TextButton.icon(
              onPressed: () {
                final selected = List<CartItem>.from(CartService().selectedItems);
                for (final item in selected) {
                  CartService().removeItem(item.productId);
                }
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
              label: Text(
                'Remove Selected ($selectedCount)',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Farm Grouped Items List ───────────────────────────────────────────────
  Widget _buildItemsList(List<CartItem> items, bool isCompact) {
    // Group items by farmer / farm name
    final Map<String, List<CartItem>> grouped = {};
    for (final item in items) {
      grouped.putIfAbsent(item.farm, () => []).add(item);
    }

    return Column(
      children: grouped.entries.map((entry) {
        final farmName = entry.key;
        final farmItems = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x03000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Farm Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.storefront_rounded, size: 16, color: _primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              farmName.isNotEmpty ? farmName : 'Local Farm Producer',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: _dark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'VERIFIED FARM',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: _primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Farm's Produce Items
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: farmItems.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  return _buildProduceRow(farmItems[index], isCompact);
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── Individual Produce Row ────────────────────────────────────────────────
  Widget _buildProduceRow(CartItem item, bool isCompact) {
    return Padding(
      padding: EdgeInsets.all(isCompact ? 14 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: item.isSelected,
            activeColor: _primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            onChanged: (_) => CartService().toggleSelection(item.productId),
          ),
          const SizedBox(width: 8),

          // Image Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: item.imageUrl.isNotEmpty
                ? SafeNetworkImage(
                    imageUrl: item.imageUrl,
                    width: isCompact ? 72 : 88,
                    height: isCompact ? 72 : 88,
                    fit: BoxFit.cover,
                    errorWidget: _buildImageFallback(size: isCompact ? 72 : 88),
                  )
                : _buildImageFallback(size: isCompact ? 72 : 88),
          ),
          const SizedBox(width: 16),

          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isCompact ? 15 : 16.5,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.price} ${item.unit}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _primaryDark,
                  ),
                ),
                if (isCompact) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildQuantityControl(item),
                      Text(
                        '₱${item.total.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _dark,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          if (!isCompact) ...[
            const SizedBox(width: 16),
            _buildQuantityControl(item),
            const SizedBox(width: 24),
            SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₱${item.total.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => CartService().removeItem(item.productId),
                      child: Text(
                        'Remove',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Quantity Stepper Control ───────────────────────────────────────────────
  Widget _buildQuantityControl(CartItem item) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => CartService().updateQuantity(item.productId, item.quantity - 1),
            icon: const Icon(Icons.remove_rounded, size: 16),
            splashRadius: 16,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${item.quantity}',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
          ),
          IconButton(
            onPressed: () async {
              final warning = await CartService().updateQuantity(item.productId, item.quantity + 1);
              if (warning != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(warning),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.add_rounded, size: 16),
            splashRadius: 16,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // ─── Sticky Order Summary Card (Right Column) ──────────────────────────────
  Widget _buildOrderSummaryCard(CartService cart, bool isCompact) {
    final selectedCount = cart.selectedItems.length;
    final subtotal = cart.selectedTotal;

    return Container(
      padding: const EdgeInsets.all(24),
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
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          // Subtotal Rows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected items',
                style: GoogleFonts.inter(fontSize: 13, color: _muted),
              ),
              Text(
                '$selectedCount item${selectedCount == 1 ? '' : 's'}',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _dark),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: GoogleFonts.inter(fontSize: 13, color: _muted),
              ),
              Text(
                '₱${subtotal.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery Fee',
                style: GoogleFonts.inter(fontSize: 13, color: _muted),
              ),
              Text(
                'Calculated at checkout',
                style: GoogleFonts.inter(fontSize: 12, color: _primaryDark, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 18),

          // Grand Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated Total',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'VAT included',
                    style: GoogleFonts.inter(fontSize: 11, color: _muted),
                  ),
                ],
              ),
              Text(
                '₱${subtotal.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Checkout CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: selectedCount > 0 ? () => context.push(AppRoutes.cartCheckout) : null,
              icon: const Icon(Icons.lock_outline_rounded, size: 16),
              label: Text(
                selectedCount > 0 ? 'Checkout ($selectedCount)' : 'Select Items to Checkout',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                disabledForegroundColor: _muted,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Continue Shopping
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go(AppRoutes.shop),
              style: OutlinedButton.styleFrom(
                foregroundColor: _dark,
                side: const BorderSide(color: _border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Continue Shopping',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Trust Guarantees Strip ────────────────────────────────────────────────
  Widget _buildTrustGuaranteesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          _trustPill(Icons.spa_rounded, '100% Farm Fresh', 'Directly from local growers'),
          _trustPill(Icons.local_shipping_outlined, 'Fast Local Dispatch', 'Same-day harvested'),
          _trustPill(Icons.verified_user_outlined, 'COD Protected', 'Pay upon receiving'),
        ],
      ),
    );
  }

  Widget _trustPill(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: _dark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 11, color: _muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isCompact) {
    return Center(
      child: Container(
        width: 560,
        margin: EdgeInsets.all(isCompact ? 16 : 0),
        padding: EdgeInsets.all(isCompact ? 24 : 40),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_basket_outlined,
                size: 38,
                color: _primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your cart is empty',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse fresh produce, grains, and fruits from local Pangasinan farmers.',
              style: GoogleFonts.inter(fontSize: 13.5, color: _muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.shop),
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: const Text('Browse Fresh Produce'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageFallback({double size = 88}) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFF1F5F9),
      child: Icon(Icons.eco_rounded, color: _primary.withValues(alpha: 0.5), size: size * 0.35),
    );
  }
}
