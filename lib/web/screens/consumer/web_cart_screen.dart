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
  static const Color _primary = Color(0xFF16A34A);
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
    final isCompact = sw < 900;

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

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 16 : 32,
                    8,
                    isCompact ? 16 : 32,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Cart',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isCompact ? 28 : 34,
                          fontWeight: FontWeight.w800,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Review what you added before checkout.',
                        style: GoogleFonts.inter(
                          fontSize: isCompact ? 13 : 14,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 24),
                      isCompact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Column(
                                  children: items
                                      .map(
                                        (item) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          child: _buildCartItem(item, true),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 12),
                                _buildSummaryCard(cart),
                              ],
                            )
                          : Row(
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
                                            child: _buildCartItem(item, false),
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
              width: isCompact ? 72 : 88,
              height: isCompact ? 72 : 88,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: isCompact ? 32 : 42,
                color: _primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your cart is empty',
              style: GoogleFonts.plusJakartaSans(
                fontSize: isCompact ? 22 : 26,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add products from the shop and they will appear here.',
              style: GoogleFonts.inter(fontSize: isCompact ? 13 : 14, color: _muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(AppRoutes.shop),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: isCompact ? 14 : 16,
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

  Widget _buildCartItem(CartItem item, bool isCompact) {
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: item.isSelected,
                  activeColor: _primary,
                  onChanged: (_) => CartService().toggleSelection(item.productId),
                ),
                const SizedBox(width: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: item.imageUrl.isNotEmpty
                      ? SafeNetworkImage(
                          imageUrl: item.imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorWidget: _buildImageFallback(size: 80),
                        )
                      : _buildImageFallback(size: 80),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.farm,
                        style: GoogleFonts.inter(fontSize: 12, color: _muted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${item.price} ${item.unit}',
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
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildQuantityControl(item),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'P${item.total.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    TextButton(
                      onPressed: () => CartService().removeItem(item.productId),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Remove',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFDC2626),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

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

  Widget _buildImageFallback({double size = 110}) {
    return Container(
      width: size,
      height: size,
      color: _surface,
      child: Icon(Icons.image_outlined, color: _muted, size: size * 0.27),
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
                  : () => context.push(AppRoutes.cartCheckout),
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
