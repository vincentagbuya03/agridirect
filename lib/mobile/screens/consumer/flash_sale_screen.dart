import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/data/app_data.dart';

/// Flash Sale Screen - Modern High-Impact Harvest & Flash Deals
class FlashSaleScreen extends StatefulWidget {
  const FlashSaleScreen({super.key});

  @override
  State<FlashSaleScreen> createState() => _FlashSaleScreenState();
}

class _FlashSaleScreenState extends State<FlashSaleScreen> {
  late Future<List<ProductItem>> _productsFuture;
  late Timer _timer;
  Duration _timeLeft = const Duration();
  String _selectedCategory = 'All Deals';

  final List<String> _categories = [
    'All Deals',
    '🔥 50%+ Off',
    '🥬 Vegetables',
    '🍎 Fruits',
    '🥩 Meat & Poultry',
    '🍚 Rice & Grains',
  ];

  static const Color _primary = Color(0xFF059669);
  static const Color _crimson = Color(0xFFE11D48);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _bg = Color(0xFFF8FAFC);

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
    HapticFeedback.lightImpact();
    final result = await CartService().addItem(product);
    if (!mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Added ${product.name} to cart!'),
            ],
          ),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
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
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildHeroBanner()),
          SliverToBoxAdapter(child: _buildCategoryPills()),
          _buildProductGrid(),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: const Color(0xFF881337), // Deep Rose / Garnet
      iconTheme: const IconThemeData(color: Colors.white),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24), size: 18),
            const SizedBox(width: 4),
            Text(
              'AgriDirect Flash Deals',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
      centerTitle: true,
      actions: [
        ListenableBuilder(
          listenable: CartService(),
          builder: (context, _) {
            final count = CartService().itemCount;
            return IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                  ),
                  if (count > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFBBF24),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Center(
                          child: Text(
                            '$count',
                            style: GoogleFonts.inter(
                              color: _dark,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () => context.push('/cart'),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HERO BANNER WITH COUNTDOWN
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeroBanner() {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(_timeLeft.inHours);
    final minutes = twoDigits(_timeLeft.inMinutes.remainder(60));
    final seconds = twoDigits(_timeLeft.inSeconds.remainder(60));

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF881337), // Deep Rose
            Color(0xFFBE123C), // Rose 700
            Color(0xFFE11D48), // Rose 600
            Color(0xFFEA580C), // Orange 600
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          children: [
            // Top Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, size: 14, color: Color(0xFFFBBF24)),
                  const SizedBox(width: 5),
                  Text(
                    '100% FARMER DIRECT SAVINGS',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Headline
            Text(
              'HARVEST FLASH DEALS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Up to 70% off peak-season farm produce, delivered fresh.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),

            // Countdown Timer Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 18, color: Color(0xFFFBBF24)),
                  const SizedBox(width: 8),
                  Text(
                    'Ends in',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildTimePill(hours, 'H'),
                  _buildTimeDivider(),
                  _buildTimePill(minutes, 'M'),
                  _buildTimeDivider(),
                  _buildTimePill(seconds, 'S'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePill(String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF881337),
            ),
          ),
          const SizedBox(width: 2),
          Text(
            unit,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF881337),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CATEGORY FILTER PILLS
  // ─────────────────────────────────────────────────────────────
  Widget _buildCategoryPills() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final isSelected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = cat);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _crimson : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _crimson : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    cat,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PRODUCT GRID
  // ─────────────────────────────────────────────────────────────
  Widget _buildProductGrid() {
    return FutureBuilder<List<ProductItem>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.62,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildSkeletonCard(),
                childCount: 4,
              ),
            ),
          );
        }

        final allProducts = snapshot.data ?? [];
        final filteredProducts = allProducts.where((p) {
          if (_selectedCategory == '🔥 50%+ Off') {
            final seed = p.productId.hashCode;
            final disc = 40.0 + (seed % 35);
            if (disc < 50) return false;
          } else if (_selectedCategory != 'All Deals') {
            final cleanCategory = _selectedCategory
                .replaceAll(RegExp(r'[^\w\s]'), '')
                .trim()
                .toLowerCase();
            final matches = p.name.toLowerCase().contains(cleanCategory) ||
                (p.categoryName ?? '').toLowerCase().contains(cleanCategory);
            if (!matches) return false;
          }
          return true;
        }).toList();

        if (filteredProducts.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFE4E6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_offer_outlined, size: 36, color: _crimson),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No deals in this category right now',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check back soon for freshly discounted harvest batches!',
                    style: GoogleFonts.inter(fontSize: 12.5, color: _muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.62,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildModernDealCard(filteredProducts[index]),
              childCount: filteredProducts.length,
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MODERN FLASH DEAL CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildModernDealCard(ProductItem product) {
    final stableSeed = product.productId.hashCode;
    final double discountPct = 40.0 + (stableSeed % 35);
    final double salePrice = double.tryParse(product.price) ?? 100;
    final double originalPrice = salePrice / (1 - (discountPct / 100));
    final double stockClaimed = 65.0 + (stableSeed % 32);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (product.productId != null) {
              context.push('/product/${product.productId}');
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image with Badges ──
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrls.isNotEmpty
                          ? product.imageUrls.first
                          : product.imageUrl,
                      height: 135,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 135,
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 135,
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(Icons.broken_image_rounded, color: _muted),
                      ),
                    ),
                  ),

                  // Discount Badge (Top Right)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '-${discountPct.toInt()}%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Farm Fresh Tag (Bottom Left Overlay)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.spa_rounded, size: 10, color: Color(0xFF34D399)),
                          const SizedBox(width: 3),
                          Text(
                            'Farm Direct',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Card Body ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Original Price
                      Text(
                        '₱${originalPrice.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: _muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),

                      // Sale Price + Cart Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '₱${salePrice.toStringAsFixed(0)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _crimson,
                            ),
                          ),
                          InkWell(
                            onTap: () => _addToCart(product),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _crimson,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.add_shopping_cart_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Progress Bar
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          children: [
                            FractionallySizedBox(
                              widthFactor: (stockClaimed / 100).clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            Center(
                              child: Text(
                                stockClaimed > 85 ? '🔥 ALMOST GONE' : '⚡ SELLING FAST',
                                style: GoogleFonts.inter(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
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
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 135,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 90, height: 12, color: const Color(0xFFF1F5F9)),
                const SizedBox(height: 6),
                Container(width: 50, height: 10, color: const Color(0xFFF8FAFC)),
                const SizedBox(height: 8),
                Container(width: 70, height: 16, color: const Color(0xFFF1F5F9)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}