import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../constants/web_design_tokens.dart';

/// Modal dialog for inspecting a product and adding to cart without navigating away
class WebProductQuickViewDialog extends StatefulWidget {
  final ProductItem product;
  final VoidCallback? onAddToCart;

  const WebProductQuickViewDialog({
    super.key,
    required this.product,
    this.onAddToCart,
  });

  static Future<void> show(
    BuildContext context, {
    required ProductItem product,
    VoidCallback? onAddToCart,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => WebProductQuickViewDialog(
        product: product,
        onAddToCart: onAddToCart,
      ),
    );
  }

  @override
  State<WebProductQuickViewDialog> createState() =>
      _WebProductQuickViewDialogState();
}

class _WebProductQuickViewDialogState extends State<WebProductQuickViewDialog> {
  int _quantity = 1;

  double get _numericPrice {
    return double.tryParse(
            widget.product.price.replaceAll(RegExp(r'[^\d.]'), '')) ??
        0.0;
  }

  double get _numericOriginalPrice {
    if (widget.product.originalPrice == null) return 0.0;
    return double.tryParse(
            widget.product.originalPrice!.replaceAll(RegExp(r'[^\d.]'), '')) ??
        0.0;
  }

  void _handleAdd() {
    CartService().addItem(widget.product, _quantity);
    if (widget.onAddToCart != null) {
      widget.onAddToCart!();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 680;
    final subtotal = _numericPrice * _quantity;

    return Dialog(
      backgroundColor: WebDesignTokens.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? sw * 0.92 : 780,
          maxHeight: isMobile ? 650 : 520,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(28.0),
              child: isMobile
                  ? SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildImageSection(height: 240),
                          const SizedBox(height: 20),
                          _buildDetailsSection(subtotal),
                        ],
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: _buildImageSection()),
                        const SizedBox(width: 28),
                        Expanded(flex: 6, child: _buildDetailsSection(subtotal)),
                      ],
                    ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: WebDesignTokens.slate400),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection({double? height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height,
        color: WebDesignTokens.bg,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: widget.product.imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: widget.product.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, error, stackTrace) => const Icon(Icons.eco,
                      size: 60, color: WebDesignTokens.primary),
                )
              : const Icon(Icons.eco,
                  size: 60, color: WebDesignTokens.primary),
        ),
      ),
    );
  }

  Widget _buildDetailsSection(double subtotal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Farm & Location
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: WebDesignTokens.primaryLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 13, color: WebDesignTokens.primary),
                  const SizedBox(width: 4),
                  Text(
                    widget.product.farm,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: WebDesignTokens.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.product.farmerName != null &&
                widget.product.farmerName!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                'by ${widget.product.farmerName}',
                style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  color: WebDesignTokens.slate500,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Product Title
        Text(
          widget.product.name,
          style: GoogleFonts.rubik(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: WebDesignTokens.dark,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),

        // Price & Original Price
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '₱${_numericPrice.toStringAsFixed(0)}',
              style: WebDesignTokens.priceLarge(color: WebDesignTokens.primary),
            ),
            Text(
              ' / ${widget.product.unit}',
              style: GoogleFonts.nunitoSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: WebDesignTokens.slate500,
              ),
            ),
            if (_numericOriginalPrice > _numericPrice) ...[
              const SizedBox(width: 10),
              Text(
                '₱${_numericOriginalPrice.toStringAsFixed(0)}',
                style: GoogleFonts.rubik(
                  fontSize: 14,
                  color: WebDesignTokens.slate400,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),

        // Description
        if (widget.product.description != null &&
            widget.product.description!.isNotEmpty)
          Text(
            widget.product.description!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunitoSans(
              fontSize: 13,
              color: WebDesignTokens.slate600,
              height: 1.4,
            ),
          )
        else
          Text(
            'Freshly harvested local produce sourced directly from accredited San Carlos City farmers.',
            style: GoogleFonts.nunitoSans(
              fontSize: 13,
              color: WebDesignTokens.slate600,
              height: 1.4,
            ),
          ),
        const SizedBox(height: 20),

        // Quantity Stepper
        Row(
          children: [
            Text(
              'Quantity (${widget.product.unit}):',
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: WebDesignTokens.dark,
              ),
            ),
            const SizedBox(width: 14),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: WebDesignTokens.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_rounded, size: 16),
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                  ),
                  Container(
                    width: 36,
                    alignment: Alignment.center,
                    child: Text(
                      '$_quantity',
                      style: GoogleFonts.rubik(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: WebDesignTokens.dark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 16),
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Add to Cart & Full Details CTA
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: WebDesignTokens.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: Text(
                  'Add to Cart • ₱${subtotal.toStringAsFixed(0)}',
                  style: GoogleFonts.rubik(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _handleAdd,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              final prodId = widget.product.productId ?? 'view';
              context.push(AppRoutes.product(prodId), extra: widget.product);
            },
            child: Text(
              'View Complete Product Specifications >',
              style: GoogleFonts.nunitoSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: WebDesignTokens.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
