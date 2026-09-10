import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../constants/web_design_tokens.dart';
import '../../widgets/ecom/web_ecom_header.dart';
import '../../widgets/web_footer.dart';

/// Flagship Pre-Order Harvest Reservation Hub for AgriDirect Web
class WebPreOrderHub extends StatefulWidget {
  const WebPreOrderHub({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
  });

  final Function(int) onNavigate;
  final int currentIndex;

  @override
  State<WebPreOrderHub> createState() => _WebPreOrderHubState();
}

class _WebPreOrderHubState extends State<WebPreOrderHub> {
  final SupabaseDataService _dataService = SupabaseDataService();

  List<ProductItem> _allProducts = [];
  List<ProductItem> _filteredProducts = [];
  bool _isLoading = true;

  String _selectedCategory = 'All';
  String _sortBy = 'Earliest Harvest';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Vegetables',
    'Fruits',
    'Grains',
    'Root Crops',
    'Organic',
  ];

  @override
  void initState() {
    super.initState();
    _loadPreOrders();
  }

  Future<void> _loadPreOrders() async {
    setState(() => _isLoading = true);
    try {
      final products = await _dataService.getPreOrderProducts();
      if (!mounted) return;
      setState(() {
        _allProducts = products;
        _applyFilters();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<ProductItem> results = List.from(_allProducts);

    // Search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      results = results.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.farm.toLowerCase().contains(q) ||
            (p.farmerName?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // Category
    if (_selectedCategory != 'All') {
      results = results.where((p) {
        return (p.categoryName?.toLowerCase() ?? '') ==
            _selectedCategory.toLowerCase();
      }).toList();
    }

    // Sort
    if (_sortBy == 'Earliest Harvest') {
      results.sort((a, b) {
        final daysA = int.tryParse(a.harvestDays ?? '') ?? 999;
        final daysB = int.tryParse(b.harvestDays ?? '') ?? 999;
        return daysA.compareTo(daysB);
      });
    }

    double parsePrice(ProductItem p) =>
        double.tryParse(p.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;

    if (_sortBy == 'Price: Low to High') {
      results.sort((a, b) => parsePrice(a).compareTo(parsePrice(b)));
    } else if (_sortBy == 'Price: High to Low') {
      results.sort((a, b) => parsePrice(b).compareTo(parsePrice(a)));
    }

    setState(() {
      _filteredProducts = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Scaffold(
      backgroundColor: WebDesignTokens.bg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── Header ───
            WebEcomHeader(
              currentIndex: widget.currentIndex,
              onNavigate: (index, [route]) {
                if (route != null) {
                  context.go(route);
                } else {
                  context.go(AppRoutes.webTabRoute(index));
                }
              },
              onSearch: (q) {
                setState(() {
                  _searchQuery = q.trim();
                  _applyFilters();
                });
              },
            ),

            // ─── Hero Banner ───
            _buildHeroBanner(sw, isMobile),

            const SizedBox(height: 28),

            // ─── Main Content Container ───
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1350),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Filter & Search Bar
                      _buildFilterBar(isMobile),
                      const SizedBox(height: 24),

                      // Pre-Order Grid
                      _buildProductGrid(sw, isMobile),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Footer ───
            const AgriDirectWebFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(double sw, bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF064E3B),
            Color(0xFF065F46),
            Color(0xFF0F172A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF064E3B).withValues(alpha: 0.3),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: isMobile ? 28 : 44,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1350),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.eco_rounded, size: 14, color: Color(0xFF34D399)),
                    const SizedBox(width: 6),
                    Text(
                      'FARM-TO-TABLE RESERVATION PROGRAM',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF34D399),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Seasonal Harvest Pre-Orders',
                style: GoogleFonts.rubik(
                  fontSize: isMobile ? 26 : 38,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                  'Reserve crops directly from verified Pangasinan growers before harvest. Lock in farmgate rates and receive guaranteed fresh produce straight from the field.',
                  style: GoogleFonts.nunitoSans(
                    fontSize: isMobile ? 13.5 : 16,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFD1FAE5),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3 Value Pillars
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _buildPillarBadge(Icons.shield_outlined, '100% AgriDirect Escrow Protected'),
                  _buildPillarBadge(Icons.local_shipping_outlined, 'Direct Farmgate Dispatch'),
                  _buildPillarBadge(Icons.monetization_on_outlined, 'Zero Middleman Markups'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillarBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF6EE7B7)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WebDesignTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebDesignTokens.border),
        boxShadow: WebDesignTokens.cardRest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with Category Chips and Sort
          Row(
            children: [
              // Categories (scrollable horizontally)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = cat;
                                _applyFilters();
                              });
                            }
                          },
                          labelStyle: GoogleFonts.nunitoSans(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? Colors.white : WebDesignTokens.dark,
                          ),
                          backgroundColor: WebDesignTokens.bg,
                          selectedColor: WebDesignTokens.primary,
                          side: BorderSide(
                            color: isSelected
                                ? WebDesignTokens.primary
                                : WebDesignTokens.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Sort Dropdown
              if (!isMobile)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: WebDesignTokens.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: WebDesignTokens.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: WebDesignTokens.slate500),
                      style: GoogleFonts.nunitoSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: WebDesignTokens.dark,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Earliest Harvest',
                          child: Text('⏳ Earliest Harvest'),
                        ),
                        DropdownMenuItem(
                          value: 'Price: Low to High',
                          child: Text('₱ Price: Low to High'),
                        ),
                        DropdownMenuItem(
                          value: 'Price: High to Low',
                          child: Text('₱ Price: High to Low'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _sortBy = val;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(double sw, bool isMobile) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: CircularProgressIndicator(color: WebDesignTokens.primary),
        ),
      );
    }

    if (_filteredProducts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        decoration: BoxDecoration(
          color: WebDesignTokens.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: WebDesignTokens.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: WebDesignTokens.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                size: 44,
                color: WebDesignTokens.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Pre-Order Harvests Found',
              style: GoogleFonts.rubik(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: WebDesignTokens.dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing your category filter or search terms.',
              style: GoogleFonts.nunitoSans(
                fontSize: 14,
                color: WebDesignTokens.slate500,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: WebDesignTokens.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                setState(() {
                  _selectedCategory = 'All';
                  _searchQuery = '';
                  _applyFilters();
                });
              },
              child: const Text('Clear All Filters'),
            ),
          ],
        ),
      );
    }

    int crossAxisCount = 4;
    if (sw < 640) {
      crossAxisCount = 1;
    } else if (sw < 960) {
      crossAxisCount = 2;
    } else if (sw < 1200) {
      crossAxisCount = 3;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = 20.0 * (crossAxisCount - 1);
        final itemWidth = (constraints.maxWidth - totalSpacing) / crossAxisCount;

        return Wrap(
          spacing: 20,
          runSpacing: 24,
          children: _filteredProducts
              .map((p) => SizedBox(
                    width: itemWidth,
                    child: _buildPreorderCard(p),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildPreorderCard(ProductItem product) {
    final totalDays = int.tryParse(product.harvestDays ?? '') ?? 0;
    final remainingDays = product.createdAt == null
        ? totalDays
        : product.createdAt!
                .add(Duration(days: totalDays))
                .difference(DateTime.now())
                .inDays +
            1;

    final harvestLabel = remainingDays > 0
        ? 'Harvest in $remainingDays days'
        : (remainingDays == 0 ? 'Harvesting today' : 'Ready for Dispatch');

    final isHarvestingSoon = remainingDays <= 3;

    return Container(
      decoration: BoxDecoration(
        color: WebDesignTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WebDesignTokens.border),
        boxShadow: WebDesignTokens.cardRest,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(AppRoutes.preorderDetails, extra: product),
          hoverColor: WebDesignTokens.primary.withValues(alpha: 0.02),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Stack with Countdown Badge
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.15,
                    child: product.imageUrl.isNotEmpty
                        ? SafeNetworkImage(
                            imageUrl: product.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: Container(color: WebDesignTokens.bg),
                            errorWidget: Container(
                              color: WebDesignTokens.bg,
                              child: const Icon(Icons.eco,
                                  size: 32, color: WebDesignTokens.primary),
                            ),
                          )
                        : Container(
                            color: WebDesignTokens.bg,
                            child: const Icon(Icons.eco,
                                size: 32, color: WebDesignTokens.primary),
                          ),
                  ),

                  // Top Left: Pre-Order Badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: WebDesignTokens.dark.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pending_actions_rounded,
                              size: 11, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'PRE-ORDER',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Pill: Harvest Countdown
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isHarvestingSoon
                            ? WebDesignTokens.dealAmber
                            : WebDesignTokens.primaryDark,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isHarvestingSoon
                                ? Icons.timer_rounded
                                : Icons.calendar_today_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            harvestLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11,
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

              // Details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Farm name & verified
                    Row(
                      children: [
                        const Icon(Icons.storefront_rounded,
                            size: 13, color: WebDesignTokens.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.farm.isNotEmpty
                                ? product.farm
                                : 'Local San Carlos Grower',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunitoSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: WebDesignTokens.slate600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Product Title
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.rubik(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: WebDesignTokens.dark,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Price & Unit
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          product.price.startsWith('₱')
                              ? product.price
                              : '₱${product.price}',
                          style: GoogleFonts.rubik(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: WebDesignTokens.primaryDark,
                          ),
                        ),
                        if (product.unit.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            '/ ${product.unit}',
                            style: GoogleFonts.nunitoSans(
                              fontSize: 12,
                              color: WebDesignTokens.slate500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),

                    // CTA Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WebDesignTokens.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => context.push(
                          AppRoutes.preorderDetails,
                          extra: product,
                        ),
                        icon: const Icon(Icons.shopping_bag_outlined, size: 15),
                        label: Text(
                          'Reserve Harvest',
                          style: GoogleFonts.rubik(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
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
    );
  }
}
