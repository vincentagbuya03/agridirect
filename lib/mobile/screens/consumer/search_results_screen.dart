import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../shared/data/app_data.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';
import 'product_view_screen.dart';
import 'farmer_public_profile_screen.dart';
import 'cart_screen.dart';
import 'search_screen.dart';

/// Modern AgriDirect Search Results Screen - Dedicated to San Carlos City, Pangasinan
class SearchResultsScreen extends StatefulWidget {
  final String query;
  final String? initialCategory;

  const SearchResultsScreen({
    super.key,
    required this.query,
    this.initialCategory,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late String _activeQuery;
  bool _isLoading = true;
  String _selectedSort = 'relevance';
  String _selectedFilter = 'all';
  String? _selectedLocation;

  List<ProductItem> _allProducts = [];
  List<Map<String, dynamic>> _allFarmers = [];

  // Authentic San Carlos City, Pangasinan Barangays and Agrarian Zones
  final List<String> _sanCarlosBarangays = [
    'All San Carlos City',
    'Pulong',
    'Magtaking',
    'Talang',
    'Ano',
    'Balococ',
    'Capaoay',
    'Bocboc',
    'Turac',
    'Coliling',
    'Mabalbalino',
    'Poblacion',
    'Ilian',
    'Malacañang',
    'Pangasinan District',
  ];

  @override
  void initState() {
    super.initState();
    _activeQuery = widget.query;
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseDataService().getNearbyProducts(),
        SupabaseDataService().getPreOrderProducts(),
        SupabaseDataService().getFeaturedFarmers(),
      ]);

      final nearby = results[0] as List<ProductItem>;
      final preorders = results[1] as List<ProductItem>;
      final farmers = results[2] as List<Map<String, dynamic>>;

      final Map<String, ProductItem> merged = {};
      for (final p in nearby) {
        if (p.productId != null) merged[p.productId!] = p;
      }
      for (final p in preorders) {
        if (p.productId != null && !merged.containsKey(p.productId)) {
          merged[p.productId!] = p;
        }
      }

      if (mounted) {
        setState(() {
          _allProducts = merged.values.toList();
          _allFarmers = farmers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _parsePrice(String raw) {
    final cleaned = raw.replaceAll('₱', '').replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  List<ProductItem> get _filteredProducts {
    final q = _activeQuery.toLowerCase().trim();

    var list = _allProducts.where((p) {
      if (q.isEmpty) return true;
      final name = p.name.toLowerCase();
      final farm = p.farm.toLowerCase();
      final cat = (p.categoryName ?? '').toLowerCase();
      final desc = (p.description ?? '').toLowerCase();
      return name.contains(q) || farm.contains(q) || cat.contains(q) || desc.contains(q);
    }).toList();

    // Secondary Filter
    if (_selectedFilter == 'verified_farm') {
      list = list.where((p) => p.isFeatured).toList();
    } else if (_selectedFilter == 'pre_order') {
      list = list.where((p) => p.isPreorder).toList();
    } else if (_selectedFilter == 'free_shipping') {
      list = list.where((p) => p.isFreeShipping).toList();
    }

    // Location filter
    if (_selectedLocation != null && _selectedLocation != 'All San Carlos City') {
      final locQuery = _selectedLocation!.toLowerCase();
      list = list.where((p) {
        final farmLower = p.farm.toLowerCase();
        return farmLower.contains(locQuery) ||
            locQuery.contains(farmLower) ||
            farmLower.contains('san carlos');
      }).toList();
    }

    // Sort
    if (_selectedSort == 'price_asc') {
      list.sort((a, b) => _parsePrice(a.price).compareTo(_parsePrice(b.price)));
    } else if (_selectedSort == 'price_desc') {
      list.sort((a, b) => _parsePrice(b.price).compareTo(_parsePrice(a.price)));
    } else if (_selectedSort == 'top_sales') {
      list.sort((a, b) => (b.soldCount ?? 0).compareTo(a.soldCount ?? 0));
    } else if (_selectedSort == 'rating') {
      list.sort((a, b) => (double.tryParse(b.rating ?? '0') ?? 0)
          .compareTo(double.tryParse(a.rating ?? '0') ?? 0));
    }

    return list;
  }

  Map<String, dynamic>? get _matchingSpotlightFarmer {
    final q = _activeQuery.toLowerCase().trim();
    if (q.isEmpty || _allFarmers.isEmpty) return null;

    try {
      return _allFarmers.firstWhere((f) {
        final name = (f['full_name'] ?? f['name'] ?? '').toString().toLowerCase();
        final farmName = (f['farm_name'] ?? '').toString().toLowerCase();
        final specialty = (f['specialty'] ?? '').toString().toLowerCase();
        final city = (f['city'] ?? f['address'] ?? '').toString().toLowerCase();
        return farmName.contains(q) || name.contains(q) || specialty.contains(q) || city.contains(q);
      });
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;
    final spotlightFarmer = _matchingSpotlightFarmer;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildResultsHeader(),
            _buildFilterPillsBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: AppShimmerLoader())
                  : products.isEmpty && spotlightFarmer == null
                      ? _buildEmptyResultsView()
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _fetchResults,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 36),
                            children: [
                              if (spotlightFarmer != null) ...[
                                _buildFarmerSpotlightCard(spotlightFarmer),
                                const SizedBox(height: 16),
                              ],
                              _buildCountAndSortRow(products.length),
                              const SizedBox(height: 12),
                              _buildProductsGrid(products),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1. CLEAN RESULTS TOP BAR ───────────────────────────────────────────────
  Widget _buildResultsHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textHeadline,
              size: 22,
            ),
            tooltip: 'Go back',
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final newQuery = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SearchScreen(initialQuery: _activeQuery),
                  ),
                );
                if (newQuery != null && newQuery.isNotEmpty && newQuery != _activeQuery) {
                  setState(() {
                    _activeQuery = newQuery;
                  });
                }
              },
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _activeQuery.isNotEmpty
                            ? _activeQuery
                            : 'Search fresh produce in San Carlos...',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHeadline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
              tooltip: 'Sort options',
              padding: EdgeInsets.zero,
              onPressed: _showSortBottomSheet,
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. FILTER PILLS BAR ──────────────────────────────────────────────────
  Widget _buildFilterPillsBar() {
    final hasLocFilter = _selectedLocation != null && _selectedLocation != 'All San Carlos City';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildDropdownPill(
              label: hasLocFilter ? '📍 $_selectedLocation' : '📍 Barangay Location',
              isActive: hasLocFilter,
              onTap: _showLocationPicker,
            ),
            const SizedBox(width: 8),
            _buildFilterTogglePill(
              label: '🌿 Verified Farms',
              isActive: _selectedFilter == 'verified_farm',
              onTap: () {
                setState(() {
                  _selectedFilter = _selectedFilter == 'verified_farm' ? 'all' : 'verified_farm';
                });
              },
            ),
            const SizedBox(width: 8),
            _buildFilterTogglePill(
              label: '🌾 Pre-Orders',
              isActive: _selectedFilter == 'pre_order',
              onTap: () {
                setState(() {
                  _selectedFilter = _selectedFilter == 'pre_order' ? 'all' : 'pre_order';
                });
              },
            ),
            const SizedBox(width: 8),
            _buildFilterTogglePill(
              label: '🚚 Free Delivery',
              isActive: _selectedFilter == 'free_shipping',
              onTap: () {
                setState(() {
                  _selectedFilter = _selectedFilter == 'free_shipping' ? 'all' : 'free_shipping';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownPill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? Colors.white : AppColors.textBody,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isActive ? Colors.white : AppColors.textSubtle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTogglePill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: isActive ? Colors.white : AppColors.textBody,
          ),
        ),
      ),
    );
  }

  Widget _buildCountAndSortRow(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(
              Icons.grid_view_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '$count fresh produce listed',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeadline,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: _showSortBottomSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Text(
                  _getSortLabel(_selectedSort),
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.unfold_more_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getSortLabel(String sortKey) {
    switch (sortKey) {
      case 'price_asc':
        return 'Price: Low to High';
      case 'price_desc':
        return 'Price: High to Low';
      case 'top_sales':
        return 'Top Sales';
      case 'rating':
        return 'Top Rated';
      default:
        return 'Best Match';
    }
  }

  // ── 3. OVERFLOW-PROOF & REFINED FARMER SPOTLIGHT CARD ─────────────────────
  Widget _buildFarmerSpotlightCard(Map<String, dynamic> farmer) {
    final name = farmer['farm_name']?.toString() ??
        farmer['full_name']?.toString() ??
        'Official Farm';
    final location = farmer['city']?.toString() ??
        farmer['address']?.toString() ??
        'San Carlos City, Pangasinan';
    final avatarUrl = farmer['avatar_url']?.toString() ?? '';
    final rating = farmer['rating']?.toString() ?? '5.0';
    final farmProducts = _allProducts
        .where((p) => p.farm.toLowerCase() == name.toLowerCase())
        .take(3)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Name/Location + Visit Button (Guaranteed Overflow Safe)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFECFDF5),
                  backgroundImage: avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? const Icon(
                          Icons.agriculture_rounded,
                          color: AppColors.primary,
                          size: 20,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textHeadline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: const Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.accent,
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHeadline,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '• $location',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSubtle,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FarmerPublicProfileScreen(farmer: farmer),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront_rounded, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Visit Farm',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Middle: Voucher / Direct Deal Strip
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_offer_rounded,
                    size: 14,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Direct Harvest Discount: Fresh farm-gate prices in San Carlos',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF92400E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Product Mini-Gallery
            if (farmProducts.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),
              Row(
                children: farmProducts.map((p) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductViewScreen(product: p),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: p.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, _) =>
                                    Container(color: const Color(0xFFF1F5F9)),
                                errorWidget: (_, _, _) => Container(
                                  color: const Color(0xFFF1F5F9),
                                  child: const Icon(
                                    Icons.agriculture_rounded,
                                    size: 20,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  color: Colors.black.withValues(alpha: 0.65),
                                  child: Text(
                                    p.price,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── 4. E-COMMERCE 2-COLUMN PRODUCT GRID ───────────────────────────────────
  Widget _buildProductsGrid(List<ProductItem> products) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.63,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        return _buildProductCard(p);
      },
    );
  }

  Widget _buildProductCard(ProductItem product) {
    final ratingNum = double.tryParse(product.rating ?? '0') ?? 0.0;
    final hasRating = ratingNum > 0.0;
    final sold = product.soldCount ?? 0;
    final location = product.farm.isNotEmpty ? product.farm : 'San Carlos City';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductViewScreen(product: product),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with Badges
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(15)),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: const Color(0xFFF1F5F9)),
                      errorWidget: (_, _, _) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(
                          Icons.agriculture_rounded,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  if (product.isPreorder)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PRE-ORDER',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (product.isFreeShipping)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_shipping_rounded,
                              size: 9,
                              color: Colors.white,
                            ),
                            SizedBox(width: 2),
                            Text(
                              'FREE',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Product Meta Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHeadline,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),

                  // Origin Farm
                  Row(
                    children: [
                      const Icon(
                        Icons.store_rounded,
                        size: 11,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          location,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSubtle,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Price & Quick Cart Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          product.price,
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(context);
                          final err = await CartService().addItem(product);
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.shopping_bag_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      err ?? 'Added ${product.name} to Cart',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                              action: SnackBarAction(
                                label: 'VIEW CART',
                                textColor: const Color(0xFFFEF08A),
                                onPressed: () => nav.push(
                                  MaterialPageRoute(
                                    builder: (_) => const CartScreen(),
                                  ),
                                ),
                              ),
                              backgroundColor: err == null
                                  ? AppColors.primaryDark
                                  : AppColors.error,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFA7F3D0),
                            ),
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
                  const SizedBox(height: 6),

                  // Rating & Sales Count
                  Row(
                    children: [
                      if (hasRating) ...[
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.accent,
                          size: 13,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          product.rating!,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHeadline,
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '🌱 Fresh',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                      if (sold > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '• $sold sold',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textSubtle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. ZERO RESULTS STATE ─────────────────────────────────────────────────
  Widget _buildEmptyResultsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 42,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No produce found for "$_activeQuery"',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeadline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Try searching with popular San Carlos crops like Carabao Mango, Organic Rice, Native Tomatoes, or Sweet Corn.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSubtle,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back to Search Hub'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 6. SORT & SAN CARLOS BARANGAY LOCATION MODAL ─────────────────────────
  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sort Agricultural Produce',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHeadline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSortTile(
                    'Best Match (Relevance)',
                    'relevance',
                    setModal,
                  ),
                  _buildSortTile('Top Sales', 'top_sales', setModal),
                  _buildSortTile('Highest Rated', 'rating', setModal),
                  _buildSortTile('Price: Low to High', 'price_asc', setModal),
                  _buildSortTile('Price: High to Low', 'price_desc', setModal),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortTile(String title, String value, StateSetter setModal) {
    final isSelected = _selectedSort == value;
    return ListTile(
      dense: true,
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 13.5,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppColors.primary : AppColors.textHeadline,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 20)
          : null,
      onTap: () {
        setState(() => _selectedSort = value);
        Navigator.pop(context);
      },
    );
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'San Carlos City Farm Locations',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHeadline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Filter fresh produce by San Carlos City Barangay or zone',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppColors.textSubtle,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _sanCarlosBarangays.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF8FAFC)),
                      itemBuilder: (context, index) {
                        final loc = _sanCarlosBarangays[index];
                        final isSelected = _selectedLocation == loc ||
                            (_selectedLocation == null && loc == 'All San Carlos City');

                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          leading: Icon(
                            Icons.location_on_rounded,
                            size: 18,
                            color: isSelected ? AppColors.primary : const Color(0xFF94A3B8),
                          ),
                          title: Text(
                            loc == 'All San Carlos City' ? loc : 'Brgy. $loc',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.primary : AppColors.textHeadline,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                  )
                              : null,
                          onTap: () {
                            setState(() => _selectedLocation =
                                loc == 'All San Carlos City' ? null : loc);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
