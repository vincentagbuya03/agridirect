import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';
import '../../widgets/web_promo_header.dart';

class WebFreshProduceScreen extends StatefulWidget {
  const WebFreshProduceScreen({super.key});

  @override
  State<WebFreshProduceScreen> createState() => _WebFreshProduceScreenState();
}

class _WebFreshProduceScreenState extends State<WebFreshProduceScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<ProductItem>> _productsFuture;
  String _selectedCategory = 'All Categories';
  String _sortBy = 'featured';
  String _searchQuery = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _productsFuture = SupabaseDataService().getNearbyProducts();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Added ${product.name} to Cart!',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              activeTab: 'fresh_produce',
              searchPlaceholder: 'Search fresh vegetables, fruits, herbs & greens...',
              onSearchChanged: (q) => setState(() => _searchQuery = q.toLowerCase()),
            ),
            _buildHeroBanner(),
            const SizedBox(height: 32),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1350),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFeatureHighlights(),
                      const SizedBox(height: 36),
                      _buildSectionHeader(),
                      _buildFilterBar(),
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
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF064E3B),
            Color(0xFF047857),
            Color(0xFF059669),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF047857).withValues(alpha: 0.35),
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
                  vertical: isMobile ? 24 : 48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 18),
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
                    SizedBox(height: isMobile ? 20 : 36),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBBF24),
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
                                    const Icon(Icons.eco_rounded,
                                        size: 14, color: Color(0xFF78350F)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'ORGANIC & SUSTAINABLE · HARVESTED DAILY',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF78350F),
                                        fontSize: isMobile ? 9.5 : 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Fresh Produce',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: isMobile ? 30 : 42,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Direct From Farm 🌾',
                                style: GoogleFonts.playfairDisplay(
                                  color: const Color(0xFF6EE7B7),
                                  fontSize: isMobile ? 32 : 48,
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.italic,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 620),
                                child: Text(
                                  'Support regional farming families and savor peak-nutrient fruits, heirloom grains, and crisp greens freshly picked at dawn.',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: isMobile ? 13 : 15,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isMobile) ...[
                          const SizedBox(width: 48),
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.25),
                                    Colors.white.withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF047857)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.eco_rounded,
                                color: Colors.white,
                                size: 64,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
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

  Widget _buildFeatureHighlights() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    final highlights = [
      {
        'icon': Icons.wb_sunny_rounded,
        'title': 'Harvested at Dawn',
        'desc': 'Picked the morning of dispatch for supreme freshness.',
        'color': const Color(0xFFD97706),
        'bg': const Color(0xFFFEF3C7),
      },
      {
        'icon': Icons.agriculture_rounded,
        'title': '100% Traceable',
        'desc': 'Meet the exact farmer behind every single harvest.',
        'color': const Color(0xFF059669),
        'bg': const Color(0xFFD1FAE5),
      },
      {
        'icon': Icons.health_and_safety_rounded,
        'title': 'Pesticide Safe',
        'desc': 'Strict quality screening for clean and nutritious meals.',
        'color': const Color(0xFF2563EB),
        'bg': const Color(0xFFDBEAFE),
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              children: highlights.map((h) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: h['bg'] as Color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          h['icon'] as IconData,
                          color: h['color'] as Color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h['title'] as String,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              h['desc'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
          : Row(
              children: highlights.map((h) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: h['bg'] as Color,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            h['icon'] as IconData,
                            color: h['color'] as Color,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h['title'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                h['desc'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildSectionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore Fresh Harvests',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select your favorite local farm crops and get them delivered to your home',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: FutureBuilder<List<ProductItem>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  List<String> categories = ['All Categories'];
                  if (snapshot.hasData) {
                    final dynamicCategories = snapshot.data!
                        .map((p) => p.categoryName)
                        .where((c) => c != null && c.isNotEmpty)
                        .toSet()
                        .cast<String>()
                        .toList();
                    dynamicCategories.sort();
                    categories.addAll(dynamicCategories);
                  }

                  return Row(
                    children:
                        categories.map((c) => _buildFilterChip(c)).toList(),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                icon: const Icon(Icons.swap_vert_rounded,
                    size: 18, color: Color(0xFF059669)),
                style: GoogleFonts.inter(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _sortBy = val);
                  }
                },
                items: const [
                  DropdownMenuItem(
                      value: 'featured', child: Text('Recommended')),
                  DropdownMenuItem(
                      value: 'price_low', child: Text('Price: Low to High')),
                  DropdownMenuItem(
                      value: 'price_high', child: Text('Price: High to Low')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF059669) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF059669)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF059669).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    final sw = MediaQuery.of(context).size.width;
    int crossAxisCount = sw < 480 ? 2 : (sw < 768 ? 2 : (sw < 1100 ? 3 : 4));
    double childAspectRatio = sw < 480
        ? 0.62
        : (sw < 640
            ? 0.64
            : (sw < 960
                ? 0.68
                : (sw < 1280
                    ? 0.70
                    : 0.72)));

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
            itemCount: 8,
            itemBuilder: (context, index) =>
                const AppShimmerLoader(height: 280),
          );
        }

        var products = snapshot.data ?? [];
        if (_searchQuery.isNotEmpty) {
          products = products
              .where((p) =>
                  p.name.toLowerCase().contains(_searchQuery) ||
                  (p.description?.toLowerCase().contains(_searchQuery) ?? false) ||
                  (p.categoryName?.toLowerCase().contains(_searchQuery) ?? false))
              .toList();
        }
        if (_selectedCategory != 'All Categories') {
          products = products
              .where((p) => p.categoryName == _selectedCategory)
              .toList();
        }

        if (_sortBy == 'price_low') {
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
                      color: Color(0xFFF0FDF4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.eco_outlined,
                        size: 48, color: Color(0xFF059669)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Fresh Produce Available',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try selecting another category or explore our wholesale section.',
                    style: GoogleFonts.inter(
                        color: const Color(0xFF64748B), fontSize: 13),
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
            return _WebFreshProduceCard(
              product: products[index],
              onAddToCart: () => _addToCart(products[index]),
            );
          },
        );
      },
    );
  }
}

class _WebFreshProduceCard extends StatefulWidget {
  final ProductItem product;
  final VoidCallback onAddToCart;

  const _WebFreshProduceCard({
    required this.product,
    required this.onAddToCart,
  });

  @override
  State<_WebFreshProduceCard> createState() => _WebFreshProduceCardState();
}

class _WebFreshProduceCardState extends State<_WebFreshProduceCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final farmDisplayName = (product.farm.isNotEmpty && product.farm != 'Farm')
        ? product.farm
        : ((product.farmerName != null && product.farmerName!.isNotEmpty)
            ? product.farmerName!
            : 'Local Farm');

    final rawPrice = product.price.replaceAll(RegExp(r'[^0-9.]'), '');
    final double price = double.tryParse(rawPrice) ?? 0.0;
    final String formattedPrice = '₱${price.toStringAsFixed(0)}';
    final String unitLabel = product.unit.isNotEmpty ? ' / ${product.unit}' : '';

    final harvestDays = int.tryParse(product.harvestDays ?? '') ?? 0;
    final daysSinceHarvest = harvestDays > 0 ? harvestDays : 1;
    final harvestedToday = daysSinceHarvest <= 0;

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
                    ? const Color(0xFF059669).withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: _isHovered ? 20 : 10,
                offset: Offset(0, _isHovered ? 8 : 3),
              ),
            ],
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFF059669).withValues(alpha: 0.35)
                  : const Color(0xFFF1F5F9),
              width: _isHovered ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.25,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(15)),
                        color: Color(0xFFF8FAFC),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(15)),
                        child: CachedNetworkImage(
                          imageUrl: product.imageUrls.isNotEmpty
                              ? product.imageUrls.first
                              : product.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(Icons.eco_rounded,
                                size: 36, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: harvestedToday
                                ? [
                                    const Color(0xFF059669),
                                    const Color(0xFF10B981)
                                  ]
                                : [
                                    const Color(0xFFD97706),
                                    const Color(0xFFF59E0B)
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: (harvestedToday
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFD97706))
                                  .withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              harvestedToday ? Icons.eco : Icons.calendar_today,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3.5),
                            Text(
                              harvestedToday
                                  ? 'Harvested Today'
                                  : 'Harvested $daysSinceHarvest d ago',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
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
                          padding: const EdgeInsets.all(4.5),
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
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 17,
                                height: 17,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFE2E8F0),
                                ),
                                child: ClipOval(
                                  child: (product.farmerAvatarUrl != null &&
                                          product.farmerAvatarUrl!.isNotEmpty)
                                      ? CachedNetworkImage(
                                          imageUrl: product.farmerAvatarUrl!,
                                          fit: BoxFit.cover,
                                          errorWidget: (context, url, error) =>
                                              const Icon(
                                            Icons.storefront_rounded,
                                            size: 10,
                                            color: Color(0xFF059669),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.storefront_rounded,
                                          size: 10,
                                          color: Color(0xFF059669),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  farmDisplayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                formattedPrice,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF059669),
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
                            ],
                          ),
                          const SizedBox(height: 7),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: widget.onAddToCart,
                              icon: const Icon(Icons.add_shopping_cart_rounded,
                                  size: 13),
                              label: const Text('Add to Cart'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
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
