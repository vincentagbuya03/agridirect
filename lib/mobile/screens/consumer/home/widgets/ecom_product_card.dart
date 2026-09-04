import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../../shared/data/app_data.dart';
import '../../../../../shared/styles/app_theme.dart';
import '../../../../../shared/services/commerce/cart_service.dart';
import '../../../../../shared/widgets/app_shimmer_loader.dart';
import '../../product_view_screen.dart';

/// High-density Shopee/Lazada-style E-Commerce Product Card for AgriDirect.
///
/// Strictly real-data driven: Badges, sold counters, discounts, and ratings
/// only display when backed by genuine database values.
class EcomProductCard extends StatelessWidget {
  final ProductItem product;
  final Position? userPosition;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const EcomProductCard({
    super.key,
    required this.product,
    this.userPosition,
    this.onTap,
    this.onAddToCart,
  });

  String? _computeDistance() {
    if (userPosition == null ||
        product.latitude == null ||
        product.longitude == null) {
      return null;
    }
    final distanceInMeters = Geolocator.distanceBetween(
      userPosition!.latitude,
      userPosition!.longitude,
      product.latitude!,
      product.longitude!,
    );
    final km = distanceInMeters / 1000.0;
    if (km < 1.0) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  void _handleAddToCart(BuildContext context) async {
    if (onAddToCart != null) {
      onAddToCart!();
      return;
    }
    final errorMsg = await CartService().addItem(product);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMsg ?? 'Added "${product.name}" to cart',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              errorMsg != null ? AppColors.error : AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.discountPercent != null &&
        product.discountPercent! > 0 &&
        product.originalPrice != null &&
        product.originalPrice!.isNotEmpty;

    final hasRating = product.rating != null &&
        product.rating!.isNotEmpty &&
        product.rating != '0' &&
        product.rating != '0.0';

    final hasSold = product.soldCount != null && product.soldCount! > 0;
    final distance = _computeDistance();
    final farmName = product.farm.isNotEmpty
        ? product.farm
        : (product.farmerName ?? '');

    return GestureDetector(
      onTap: onTap ??
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductViewScreen(product: product),
              ),
            );
          },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── PRODUCT IMAGE & DISCOUNT TAG ──
            AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  product.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          key: ValueKey('img_${product.productId}_${product.imageUrl}'),
                          imageUrl: product.imageUrl,
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          placeholderFadeInDuration: Duration.zero,
                          useOldImageOnUrlChange: true,
                          memCacheWidth: 400,
                          memCacheHeight: 400,
                          placeholder: (context, url) =>
                              const AppShimmerLoader(),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade100,
                            child: const Icon(
                              Icons.agriculture_rounded,
                              size: 36,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade100,
                          child: const Icon(
                            Icons.agriculture_rounded,
                            size: 36,
                            color: Colors.grey,
                          ),
                        ),

                  // Shopee-style discount badge
                  if (hasDiscount)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFA541C), // E-commerce flame orange
                          borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          '-${product.discountPercent!.toInt()}%',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),

                  // Free Shipping mini tag
                  if (product.isFreeShipping)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'FREE SHIP',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── PRODUCT DETAILS ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Farm name verification pill
                    if (farmName.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            size: 11,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              farmName,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                    // Product title
                    Text(
                      product.name,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Pricing block
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₱${product.price.replaceAll('₱', '').trim()}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                        if (product.unit.isNotEmpty)
                          Text(
                            '/${product.unit}',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        const SizedBox(width: 4),
                        if (hasDiscount)
                          Expanded(
                            child: Text(
                              '₱${product.originalPrice!.replaceAll('₱', '').trim()}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xFF94A3B8),
                                decoration: TextDecoration.lineThrough,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                      ],
                    ),

                    // Social proof (Rating & Sold) + Add to Cart button
                    Row(
                      children: [
                        if (hasRating) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 1),
                          Text(
                            product.rating!,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (hasSold)
                          Text(
                            '${product.soldCount} sold',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        if (distance != null && !hasSold)
                          Text(
                            distance,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _handleAddToCart(context),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 15,
                              color: AppColors.primary,
                            ),
                          ),
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
    );
  }
}
