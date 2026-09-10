import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../constants/web_design_tokens.dart';
import 'web_product_quick_view_dialog.dart';

/// Modern Responsive E-Commerce Product Card for AgriDirect Web
class WebProductCard extends StatefulWidget {
  final ProductItem product;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;
  final VoidCallback? onToggleWishlist;
  final bool isWishlisted;

  const WebProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onAddToCart,
    this.onToggleWishlist,
    this.isWishlisted = false,
  });

  @override
  State<WebProductCard> createState() => _WebProductCardState();
}

class _WebProductCardState extends State<WebProductCard> {
  bool _isHovered = false;

  double get _numericPrice {
    return double.tryParse(
          widget.product.price.replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        0.0;
  }

  double get _numericOriginalPrice {
    if (widget.product.originalPrice == null) return 0.0;
    return double.tryParse(
          widget.product.originalPrice!.replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        0.0;
  }

  int get _discountPercentage {
    if (widget.product.discountPercent != null &&
        widget.product.discountPercent! > 0) {
      return widget.product.discountPercent!.round();
    }
    if (_numericOriginalPrice > _numericPrice && _numericOriginalPrice > 0) {
      return (((_numericOriginalPrice - _numericPrice) /
                  _numericOriginalPrice) *
              100)
          .round();
    }
    return 0;
  }

  void _handleAddToCart(BuildContext context) {
    if (widget.onAddToCart != null) {
      widget.onAddToCart!();
    } else {
      CartService().addItem(widget.product);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: WebDesignTokens.primaryDark,
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Added ${widget.product.name} to cart!',
                  style: GoogleFonts.nunitoSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final discount = _discountPercentage;
    final hasDiscount = discount > 0;
    final ratingStr = widget.product.rating ?? '5.0';
    final soldCount = widget.product.soldCount ?? 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: _isHovered
            ? Matrix4.translationValues(0.0, -4.0, 0.0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: WebDesignTokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? WebDesignTokens.primary.withValues(alpha: 0.4)
                : WebDesignTokens.border,
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: _isHovered
              ? WebDesignTokens.cardHover
              : WebDesignTokens.cardRest,
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Image Container with Aspect Ratio 1:1 ───
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1.05,
                      child: Container(
                        color: WebDesignTokens.bg,
                        child: AnimatedScale(
                          scale: _isHovered ? 1.06 : 1.0,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                          child: widget.product.imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: widget.product.imageUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, error, stackTrace) =>
                                      _buildPlaceholder(),
                                )
                              : _buildPlaceholder(),
                        ),
                      ),
                    ),

                    // Top Left: Discount & Flash Badges
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.product.isFlashSale || hasDiscount)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.product.isFlashSale
                                    ? WebDesignTokens.dealAmber
                                    : WebDesignTokens.discountRed,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Text(
                                widget.product.isFlashSale
                                    ? '⚡ FLASH DEAL'
                                    : '-$discount%',
                                style: WebDesignTokens.badge(),
                              ),
                            ),
                          if (widget.product.isPreorder) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: WebDesignTokens.slate700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '📦 PRE-ORDER',
                                style: WebDesignTokens.badge(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Top Right: Wishlist Bookmark
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: widget.onToggleWishlist ?? () {},
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(
                              widget.isWishlisted
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                              color: widget.isWishlisted
                                  ? WebDesignTokens.discountRed
                                  : WebDesignTokens.slate500,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom Overlay: Quick Actions on Hover
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: AnimatedOpacity(
                        opacity: _isHovered ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        child: Row(
                          children: [
                            // Quick View Button
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: WebDesignTokens.dark,
                                  elevation: 4,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.remove_red_eye_outlined,
                                  size: 15,
                                ),
                                label: Text(
                                  'Quick View',
                                  style: GoogleFonts.rubik(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () {
                                  WebProductQuickViewDialog.show(
                                    context,
                                    product: widget.product,
                                    onAddToCart: () =>
                                        _handleAddToCart(context),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Quick Add to Cart Button
                            Material(
                              color: WebDesignTokens.primary,
                              borderRadius: BorderRadius.circular(8),
                              elevation: 4,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _handleAddToCart(context),
                                child: const Padding(
                                  padding: EdgeInsets.all(10.0),
                                  child: Icon(
                                    Icons.add_shopping_cart_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Details Block ───
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Farm Origin Tag
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: WebDesignTokens.primary,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  widget.product.farm,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.nunitoSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: WebDesignTokens.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Product Name
                          Text(
                            widget.product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.rubik(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: WebDesignTokens.dark,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                ratingStr,
                                style: GoogleFonts.rubik(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: WebDesignTokens.dark,
                                ),
                              ),
                              if (soldCount > 0) ...[
                                Text(
                                  ' • $soldCount sold',
                                  style: GoogleFonts.nunitoSans(
                                    fontSize: 11,
                                    color: WebDesignTokens.slate500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Price Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '₱${_numericPrice.toStringAsFixed(0)}',
                                style: WebDesignTokens.priceLarge(),
                              ),
                              Text(
                                '/${widget.product.unit}',
                                style: GoogleFonts.nunitoSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: WebDesignTokens.slate500,
                                ),
                              ),
                              if (hasDiscount && _numericOriginalPrice > 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '₱${_numericOriginalPrice.toStringAsFixed(0)}',
                                  style: GoogleFonts.rubik(
                                    fontSize: 11,
                                    color: WebDesignTokens.slate400,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: WebDesignTokens.bg,
      child: Center(
        child: Icon(
          Icons.eco_rounded,
          size: 40,
          color: WebDesignTokens.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
