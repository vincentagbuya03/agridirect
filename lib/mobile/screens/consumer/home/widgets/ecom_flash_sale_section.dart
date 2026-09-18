import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../shared/data/app_data.dart';
import '../../../../../shared/widgets/app_shimmer_loader.dart';
import '../../flash_sale_screen.dart';
import '../../product_view_screen.dart';

/// Shopee-style Flash Deals section with live digital countdown ticker [HH:MM:SS]
/// and real stock progress meters.
///
/// Strictly real-data driven: Collapses cleanly to `SizedBox.shrink()` if no active
/// flash deals exist in the database.
class EcomFlashSaleSection extends StatefulWidget {
  final List<ProductItem> flashProducts;

  const EcomFlashSaleSection({
    super.key,
    required this.flashProducts,
  });

  @override
  State<EcomFlashSaleSection> createState() => _EcomFlashSaleSectionState();
}

class _EcomFlashSaleSectionState extends State<EcomFlashSaleSection> {
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    _startCountdown();
  }

  @override
  void didUpdateWidget(covariant EcomFlashSaleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flashProducts != widget.flashProducts) {
      _calculateRemainingTime();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _calculateRemainingTime() {
    if (widget.flashProducts.isEmpty) {
      _remainingTime = Duration.zero;
      return;
    }

    DateTime? targetEnd;
    for (final p in widget.flashProducts) {
      if (p.flashSaleEnd != null) {
        if (targetEnd == null || p.flashSaleEnd!.isBefore(targetEnd)) {
          targetEnd = p.flashSaleEnd;
        }
      }
    }

    if (targetEnd != null) {
      final diff = targetEnd.difference(DateTime.now());
      _remainingTime = diff.isNegative ? Duration.zero : diff;
    } else {
      // Fallback: End of current day cycle
      final now = DateTime.now();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      _remainingTime = endOfDay.difference(now);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime = _remainingTime - const Duration(seconds: 1);
        });
      }
    });
  }

  Widget _buildTimeBox(String digits) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        digits,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flashProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    final hours = _remainingTime.inHours.toString().padLeft(2, '0');
    final minutes =
        (_remainingTime.inMinutes % 60).toString().padLeft(2, '0');
    final seconds =
        (_remainingTime.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── FLASH DEAL HEADER ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF4D4F), Color(0xFFFA541C)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.flash_on_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  'FLASH DEALS',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),

                // Digital Countdown Blocks
                _buildTimeBox(hours),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    ':',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildTimeBox(minutes),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    ':',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildTimeBox(seconds),

                const Spacer(),

                // See More Link
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FlashSaleScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'See All',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── HORIZONTAL PRODUCT CARDS ──
          SizedBox(
            height: 212,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: widget.flashProducts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final product = widget.flashProducts[index];
                final hasDiscount = product.discountPercent != null &&
                    product.discountPercent! > 0;

                // Real claim progress calculation
                double claimProgress = 0.5;
                if (product.claimPercentage != null &&
                    product.claimPercentage! > 0) {
                  claimProgress = (product.claimPercentage! / 100.0).clamp(0.05, 1.0);
                } else if (product.targetQuantity != null &&
                    product.targetQuantity! > 0 &&
                    product.reservedQuantity != null) {
                  claimProgress = (product.reservedQuantity! / product.targetQuantity!)
                      .clamp(0.05, 1.0);
                }

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductViewScreen(product: product),
                      ),
                    );
                  },
                  child: Container(
                    width: 130,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image container with discount badge
                        Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 1.0,
                              child: product.imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: product.imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, _) =>
                                          const AppShimmerLoader(),
                                      errorWidget: (_, _, _) =>
                                          Container(
                                        color: Colors.grey.shade100,
                                        child: const Icon(
                                          Icons.agriculture_rounded,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey.shade100,
                                      child: const Icon(
                                        Icons.agriculture_rounded,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),
                            if (hasDiscount)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFA541C),
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(6),
                                    ),
                                  ),
                                  child: Text(
                                    '-${product.discountPercent!.toInt()}%',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Pricing and Flame Claim Bar
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '₱${product.price.replaceAll('₱', '').trim()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFFA541C),
                                  ),
                                ),
                                const SizedBox(height: 3),

                                // Flame stock progress bar
                                Container(
                                  height: 13,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFE8D6),
                                    borderRadius: BorderRadius.circular(6.5),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      FractionallySizedBox(
                                        widthFactor: claimProgress,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFFFA541C),
                                                Color(0xFFFF7A45),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(6.5),
                                          ),
                                        ),
                                      ),
                                      Center(
                                        child: Text(
                                          '🔥 ${(claimProgress * 100).toInt()}% claimed',
                                          style: GoogleFonts.inter(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w800,
                                            color: claimProgress > 0.5
                                                ? Colors.white
                                                : const Color(0xFFD4380D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
}
