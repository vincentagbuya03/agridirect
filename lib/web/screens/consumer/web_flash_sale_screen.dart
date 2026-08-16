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
  String _selectedCategory = 'All Deals';
  String _sortBy = 'highest_discount';

  final List<String> _categories = [
    'All Deals',
    '🔥 30%+ Off',
    'Vegetables',
    'Fruits',
    'Meat & Poultry',
    'Rice & Grains',
  ];

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

  void _addToCart(ProductItem product, double salePrice) async {
    final discountedProduct = product.copyWith(
      price: '₱${salePrice.toStringAsFixed(0)}',
    );
    final result = await CartService().addItem(discountedProduct);
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
              Expanded(
                child: Text(
                  'Added ${product.name} (Flash Deal ₱${salePrice.toStringAsFixed(0)}) to Cart!',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

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
            const SizedBox(height: 24),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1350),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(),
                      const SizedBox(height: 16),
                      _buildFilterBar(),
                      const SizedBox(height: 20),
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
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

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
            Color(0xFF7F1D1D),
            Color(0xFF991B1B),
            Color(0xFFDC2626),
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
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 32,
                  vertical: isMobile ? 20 : 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    InkWell(
                      onTap: () => context.pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2)),
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
                    SizedBox(height: isMobile ? 16 : 28),

                    // Main Titles + Timer Block
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.flash_on_rounded,
                                      size: 14,
                                      color: Color(0xFFB45309),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'LIMITED TIME HARVEST SALE',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFB45309),
                                        fontSize: isMobile ? 9.5 : 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Flash Harvest Deals ⚡',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: isMobile ? 26 : 38,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Live countdown badge
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 12 : 16,
                                  vertical: isMobile ? 6 : 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: const Color(0xFFFBBF24),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.timer_outlined,
                                      size: 16,
                                      color: Color(0xFFFBBF24),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'ENDS IN ',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFFBBF24),
                                        fontSize: isMobile ? 11 : 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    Text(
                                      '$hours : $minutes : $seconds',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: isMobile ? 13 : 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 620,
                                ),
                                child: Text(
                                  'Snag farm fresh crops and surplus harvest at live discounted flash prices before midnight!',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: isMobile ? 12.5 : 14.5,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isMobile) ...[
                          const SizedBox(width: 48),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hot Deals Right Now',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Discounted farm harvests with live remaining claim stock',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategory = cat),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFDC2626) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFDC2626)
                                      .withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        cat,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (!isMobile) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                icon: const Icon(Icons.arrow_drop_down,
                    color: Color(0xFF64748B)),
                style: GoogleFonts.inter(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _sortBy = val);
                  }
                },
                items: const [
                  DropdownMenuItem(
                      value: 'highest_discount',
                      child: Text('Highest Discount')),
                  DropdownMenuItem(
                      value: 'price_low', child: Text('Price: Low to High')),
                  DropdownMenuItem(
                      value: 'price_high', child: Text('Price: High to Low')),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductGrid() {
    final sw = MediaQuery.of(context).size.width;
    int crossAxisCount = sw < 600 ? 2 : (sw < 960 ? 3 : (sw < 1200 ? 4 : 5));
    double childAspectRatio = sw < 480
        ? 0.58
        : (sw < 640
            ? 0.63
            : (sw < 960
                ? 0.68
                : 0.72));

    return FutureBuilder<List<ProductItem>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: 6,
            itemBuilder: (context, index) =>
                const AppShimmerLoader(height: 260),
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
                        false) ||
                    p.farm.toLowerCase().contains(_searchQuery),
              )
              .toList();
        }

        if (_selectedCategory == '🔥 30%+ Off') {
          products = products.where((p) {
            final discount = p.discountPercent ?? 30.0;
            return discount >= 30.0;
          }).toList();
        } else if (_selectedCategory != 'All Deals') {
          products = products
              .where((p) =>
                  p.categoryName?.toLowerCase().contains(_selectedCategory.toLowerCase()) ??
                  false)
              .toList();
        }

        if (_sortBy == 'highest_discount') {
          products.sort((a, b) {
            final dA = a.discountPercent ?? 0.0;
            final dB = b.discountPercent ?? 0.0;
            return dB.compareTo(dA);
          });
        } else if (_sortBy == 'price_low') {
          products.sort((a, b) {
            final pA = double.tryParse(
                    a.price.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                0;
            final pB = double.tryParse(
                    b.price.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                0;
            return pA.compareTo(pB);
          });
        } else if (_sortBy == 'price_high') {
          products.sort((a, b) {
            final pA = double.tryParse(
                    a.price.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                0;
            final pB = double.tryParse(
                    b.price.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                0;
            return pB.compareTo(pA);
          });
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
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final double discount = product.discountPercent ?? 30.0;
            final rawPrice = product.price.replaceAll(RegExp(r'[^0-9.]'), '');
            final double salePrice = double.tryParse(rawPrice) ?? 100.0;
            final double originalPrice = double.tryParse(
                  product.originalPrice?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
                ) ??
                (salePrice / (1.0 - (discount / 100.0)));

            final double claimPercentage = product.claimPercentage ?? 65.0;

            return _WebFlashSaleCard(
              product: product,
              discount: discount,
              originalPrice: originalPrice,
              salePrice: salePrice,
              claimPercentage: claimPercentage,
              onAddToCart: () => _addToCart(product, salePrice),
            );
          },
        );
      },
    );
  }
}

class _WebFlashSaleCard extends StatefulWidget {
  final ProductItem product;
  final double discount;
  final double originalPrice;
  final double salePrice;
  final double claimPercentage;
  final VoidCallback onAddToCart;

  const _WebFlashSaleCard({
    required this.product,
    required this.discount,
    required this.originalPrice,
    required this.salePrice,
    required this.claimPercentage,
    required this.onAddToCart,
  });

  @override
  State<_WebFlashSaleCard> createState() => _WebFlashSaleCardState();
}

class _WebFlashSaleCardState extends State<_WebFlashSaleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final farmDisplayName = (product.farm.isNotEmpty && product.farm != 'Farm')
        ? product.farm
        : ((product.farmerName != null && product.farmerName!.isNotEmpty)
            ? product.farmerName!
            : 'Direct Farm Harvest');

    final String unitLabel =
        product.unit.isNotEmpty ? ' / ${product.unit}' : '';

    final double stockClaimed = widget.claimPercentage;
    final bool isAlmostGone = stockClaimed >= 80;

    final rawRating = double.tryParse(product.rating ?? '') ?? 5.0;
    final ratingStr = rawRating > 0 ? rawRating.toStringAsFixed(1) : '5.0';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
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
          transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
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
                    height: 125,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(15)),
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
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                        ),
                        borderRadius: BorderRadius.circular(12),
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
                            size: 11,
                            color: Colors.white,
                          ),
                          Text(
                            '-${widget.discount.toInt()}%',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (farmDisplayName.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.verified_rounded,
                            size: 12, color: Color(0xFF059669)),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Farm Name & Rating
                          Row(
                            children: [
                              const Icon(
                                Icons.storefront_rounded,
                                size: 11,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  farmDisplayName,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: Color(0xFFF59E0B),
                              ),
                              Text(
                                ' $ratingStr',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Price section
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '\u20B1${widget.salePrice.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                              Text(
                                unitLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '\u20B1${widget.originalPrice.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: const Color(0xFF94A3B8),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Progress and Button section
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${stockClaimed.toInt()}% claimed',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              if (isAlmostGone)
                                Text(
                                  'Almost Gone!',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFDC2626),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: (stockClaimed / 100).clamp(0.05, 1.0),
                              minHeight: 4,
                              backgroundColor: const Color(0xFFF1F5F9),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isAlmostGone
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Add to Cart Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: widget.onAddToCart,
                              icon: const Icon(Icons.flash_on_rounded, size: 13),
                              label: const Text('Buy Deal'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
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
      ),
    );
  }
}
