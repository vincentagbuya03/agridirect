import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';
import '../../widgets/web_promo_header.dart';
import 'dart:async';

class WebFlashSaleScreen extends StatefulWidget {
  const WebFlashSaleScreen({super.key});

  @override
  State<WebFlashSaleScreen> createState() => _WebFlashSaleScreenState();
}

class _WebFlashSaleScreenState extends State<WebFlashSaleScreen> {
  late Future<List<ProductItem>> _productsFuture;
  late Timer _timer;
  Duration _timeLeft = const Duration();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _productsFuture = SupabaseDataService().getFlashSaleProducts();
    _calculateTimeLeft();
    _startTimer();
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    setState(() {
      _timeLeft = midnight.difference(now);
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft.inSeconds > 0) {
        if (mounted) {
          setState(() {
            _timeLeft = _timeLeft - const Duration(seconds: 1);
          });
        }
      } else {
        _calculateTimeLeft();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _addToCart(ProductItem product) async {
    final result = await CartService().addItem(product);
    if (!mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), backgroundColor: Colors.red[600]),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Added ${product.name} to Cart!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'VIEW CART',
            textColor: Colors.white,
            onPressed: () => context.push('/cart'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            WebPromoHeader(
              activeTab: 'flash_sale',
              searchPlaceholder: 'Search flash deals on fresh harvest...',
              onSearchChanged: (q) =>
                  setState(() => _searchQuery = q.toLowerCase()),
            ),
            _buildHeroBanner(),
            const SizedBox(height: 32),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1350),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(),
                      const SizedBox(height: 24),
                      _buildProductGrid(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(_timeLeft.inHours);
    final minutes = twoDigits(_timeLeft.inMinutes.remainder(60));
    final seconds = twoDigits(_timeLeft.inSeconds.remainder(60));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7F1D1D), // Dark wine red
            Color(0xFF991B1B), // Crimson
            Color(0xFFDC2626), // Vivid red
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF991B1B).withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -60,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1350),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => context.pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Back to Marketplace',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.bolt_rounded,
                                      size: 16,
                                      color: Color(0xFF78350F),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'LIMITED TIME DEALS · UP TO 50% OFF',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF78350F),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Flash Deals',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Ends in $hours:$minutes:$seconds ⚡',
                                style: GoogleFonts.playfairDisplay(
                                  color: const Color(0xFFFCA5A5),
                                  fontSize: 48,
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.italic,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 620,
                                ),
                                child: Text(
                                  'Snag surplus farm harvests at deeply discounted wholesale prices before the timer runs out!',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 15,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (MediaQuery.of(context).size.width > 768) ...[
                          const SizedBox(width: 48),
                          // Countdown Boxes
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildTimerBox(hours, 'HOURS'),
                                const SizedBox(width: 8),
                                Text(
                                  ':',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildTimerBox(minutes, 'MINUTES'),
                                const SizedBox(width: 8),
                                Text(
                                  ':',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildTimerBox(seconds, 'SECONDS'),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBox(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hot Deals Right Now',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Discounted fresh items with limited stock available today',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildProductGrid() {
    final sw = MediaQuery.of(context).size.width;
    int crossAxisCount = sw < 640 ? 1 : (sw < 960 ? 2 : (sw < 1200 ? 3 : 4));

    return FutureBuilder<List<ProductItem>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 0.72,
            ),
            itemCount: 8,
            itemBuilder: (context, index) => const AppShimmerLoader(height: 280),
          );
        }

        var products = snapshot.data ?? [];
        if (_searchQuery.isNotEmpty) {
          products = products
              .where(
                (p) =>
                    p.name.toLowerCase().contains(_searchQuery) ||
                    (p.description?.toLowerCase().contains(_searchQuery) ??
                        false) ||
                    (p.categoryName?.toLowerCase().contains(_searchQuery) ??
                        false),
              )
              .toList();
        }
        if (products.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.flash_off_rounded,
                      size: 48,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Flash Deals Available',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Next flash harvest drops at midnight. Turn on notifications to get alerted!',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 0.84,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            return _WebFlashSaleCard(
              product: products[index],
              onAddToCart: () => _addToCart(products[index]),
            );
          },
        );
      },
    );
  }
}

class _WebFlashSaleCard extends StatefulWidget {
  final ProductItem product;
  final VoidCallback onAddToCart;

  const _WebFlashSaleCard({required this.product, required this.onAddToCart});

  @override
  State<_WebFlashSaleCard> createState() => _WebFlashSaleCardState();
}

class _WebFlashSaleCardState extends State<_WebFlashSaleCard> {
  bool _isHovered = false;

  int _stableSeed(String? id) {
    if (id == null) return 0;
    int hash = 0;
    for (int i = 0; i < id.length; i++) {
      hash = 31 * hash + id.codeUnitAt(i);
    }
    return hash.abs();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final int seed = _stableSeed(product.productId);

    final double discount = 15.0 + (seed % 36); // 15% to 50% off
    final rawPrice = product.price.replaceAll(RegExp(r'[^0-9.]'), '');
    final double salePrice = double.tryParse(rawPrice) ?? 100.0;
    final double originalPrice = salePrice / (1 - (discount / 100));

    final double stockClaimed = 35.0 + (seed % 60);
    final bool isAlmostGone = stockClaimed > 80;

    final String unitLabel = product.unit.isNotEmpty
        ? ' / ${product.unit}'
        : '';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          if (product.productId != null) {
            context.push('/product/${product.productId}');
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _isHovered ? -6 : 0, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: _isHovered ? 20 : 10,
                offset: Offset(0, _isHovered ? 8 : 3),
              ),
            ],
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFFDC2626).withValues(alpha: 0.35)
                  : const Color(0xFFF1F5F9),
              width: _isHovered ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 155,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                      color: Color(0xFFF8FAFC),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: product.imageUrls.isNotEmpty
                            ? product.imageUrls.first
                            : product.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(
                            Icons.eco_rounded,
                            size: 40,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Discount Badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFDC2626,
                            ).withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          Text(
                            '-${discount.toInt()}%',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Location & Rating
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 11,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              (product.farmerName != null && product.farmerName!.isNotEmpty)
                                  ? product.farmerName!
                                  : 'Direct Farm Harvest',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: Color(0xFFF59E0B),
                          ),
                          Text(
                            ' 4.9',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Price section
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₱${salePrice.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                          Text(
                            unitLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '₱${originalPrice.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Progress Bar for claimed stock
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${stockClaimed.toInt()}% claimed',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          if (isAlmostGone)
                            Text(
                              'Almost Gone!',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: stockClaimed / 100,
                          minHeight: 5,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isAlmostGone
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Add to Cart Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.onAddToCart,
                          icon: const Icon(Icons.flash_on_rounded, size: 14),
                          label: const Text('Buy Deal'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
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
      ),
    );
  }
}
