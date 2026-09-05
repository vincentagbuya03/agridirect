import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../constants/web_design_tokens.dart';

/// Interactive mini-cart flyout overlay showing top items and quick checkout
class WebCartFlyout extends StatelessWidget {
  final VoidCallback onViewCart;
  final VoidCallback onCheckout;

  const WebCartFlyout({
    super.key,
    required this.onViewCart,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartService(),
      builder: (context, _) {
        final cart = CartService();
        final items = cart.items;

        return Container(
          width: 360,
          constraints: const BoxConstraints(maxHeight: 460),
          decoration: BoxDecoration(
            color: WebDesignTokens.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: WebDesignTokens.border),
            boxShadow: WebDesignTokens.dropdownShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Shopping Cart (${cart.itemCount})',
                      style: GoogleFonts.rubik(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: WebDesignTokens.dark,
                      ),
                    ),
                    Text(
                      '${cart.totalQuantity} items',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 13,
                        color: WebDesignTokens.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: WebDesignTokens.border),

              // Items List or Empty State
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.shopping_basket_outlined,
                          size: 48, color: WebDesignTokens.slate400),
                      const SizedBox(height: 12),
                      Text(
                        'Your cart is empty',
                        style: GoogleFonts.rubik(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: WebDesignTokens.dark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Explore fresh harvests from San Carlos farmers!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunitoSans(
                          fontSize: 12,
                          color: WebDesignTokens.slate500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length > 3 ? 3 : items.length,
                    separatorBuilder: (_, index) => Divider(
                      height: 1,
                      color: WebDesignTokens.border.withValues(alpha: 0.5),
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            // Product Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 48,
                                height: 48,
                                color: WebDesignTokens.bg,
                                child: item.imageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: item.imageUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, error, stackTrace) => const Icon(
                                            Icons.eco,
                                            color: WebDesignTokens.primary,
                                            size: 20),
                                      )
                                    : const Icon(Icons.eco,
                                        color: WebDesignTokens.primary,
                                        size: 20),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.nunitoSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: WebDesignTokens.dark,
                                    ),
                                  ),
                                  Text(
                                    '${item.quantity} ${item.unit} × ₱${item.priceValue.toStringAsFixed(0)}',
                                    style: GoogleFonts.nunitoSans(
                                      fontSize: 12,
                                      color: WebDesignTokens.slate500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Total
                            Text(
                              '₱${item.total.toStringAsFixed(0)}',
                              style: GoogleFonts.rubik(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: WebDesignTokens.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              if (items.length > 3)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '+${items.length - 3} more items in cart',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: WebDesignTokens.slate500,
                    ),
                  ),
                ),

              if (items.isNotEmpty) ...[
                const Divider(height: 1, color: WebDesignTokens.border),
                // Footer Total & Actions
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Estimated Subtotal',
                            style: GoogleFonts.nunitoSans(
                              fontSize: 13,
                              color: WebDesignTokens.slate600,
                            ),
                          ),
                          Text(
                            '₱${cart.totalAmount.toStringAsFixed(2)}',
                            style: GoogleFonts.rubik(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: WebDesignTokens.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: WebDesignTokens.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: onViewCart,
                              child: Text(
                                'View Cart',
                                style: GoogleFonts.rubik(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: WebDesignTokens.dark,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: WebDesignTokens.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: onCheckout,
                              child: Text(
                                'Checkout',
                                style: GoogleFonts.rubik(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
