import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/web_consumer_nav_bar.dart';
import '../../widgets/web_footer.dart';

/// Web Shop Screen — Fresh Produce Marketplace
/// Dark navbar, left sidebar filters, product grid with badges
class WebShopScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final int currentIndex;
  final bool initialShowPreOrders;
  final String? initialCategory;

  const WebShopScreen({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
    this.initialShowPreOrders = false,
    this.initialCategory,
  });

  @override
  State<WebShopScreen> createState() => _WebShopScreenState();
}

class _WebShopScreenState extends State<WebShopScreen>
    with TickerProviderStateMixin {
  // ─── Color Palette (Modern) ───
  static const Color _primary = Color(0xFF16A34A);
  static const Color _primaryLight = Color(0xFFECF4EE);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _mutedLight = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _white = Colors.white;
  static const Color _bg = Color(0xFFFAFAFA);

  // ─── Animations ───
  late AnimationController _fadeInController;
  late AnimationController _blobController;
  late List<AnimationController> _productControllers;
  final Set<int> _hoveredProducts = {};

  // ─── State ───
  final _dataService = SupabaseDataService();
  String? _currentFarmerId;
  List<ProductItem> _allProducts = [];
  List<ProductItem> _filteredProducts = [];
  bool _isLoading = true;
  bool _isGridView = true;
  bool _showPreOrders = false;
  String _selectedCategory = 'All';
  String _sortBy = 'Newest';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  double _priceRange = 500.0;
  bool _verifiedOnly = false;
  int _currentPage = 1;
  final int _itemsPerPage = 12;

  List<String> _categories = ['All'];

  bool get _hasActiveFilters =>
      _selectedCategory != 'All' ||
      _priceRange < 500 ||
      _searchQuery.isNotEmpty ||
      _verifiedOnly;

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedCategory != 'All') count++;
    if (_priceRange < 500) count++;
    if (_searchQuery.isNotEmpty) count++;
    if (_verifiedOnly) count++;
    return count;
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = 'All';
      _priceRange = 500.0;
      _searchQuery = '';
      _searchController.clear();
      _verifiedOnly = false;
    });
    _filterProducts();
  }

  @override
  void initState() {
    super.initState();
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..forward();
    _blobController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    _productControllers = [];
    _showPreOrders = widget.initialShowPreOrders;
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    _loadProducts();
  }

  @override
  void didUpdateWidget(covariant WebShopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialShowPreOrders != widget.initialShowPreOrders) {
      _showPreOrders = widget.initialShowPreOrders;
      _selectedCategory = widget.initialCategory ?? 'All';
      _searchQuery = '';
      _searchController.clear();
      _currentPage = 1;
      _loadProducts();
    } else if (oldWidget.initialCategory != widget.initialCategory) {
      setState(() {
        _selectedCategory = widget.initialCategory ?? 'All';
      });
      _filterProducts();
    }
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    _blobController.dispose();
    for (final c in _productControllers) {
      c.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      _currentFarmerId = await _dataService.getCurrentFarmerId();
      final products = await _dataService.getAllProducts(
        excludeCurrentFarmer: true,
      );
      final currentUserId = SupabaseConfig.currentUser?.id;
      final filteredList = products.where((p) {
        if (currentUserId != null && p.farmerId == currentUserId) return false;
        if (_currentFarmerId != null && p.farmerId == _currentFarmerId) {
          return false;
        }
        return true;
      }).toList();
      final categories = _deriveCategories(filteredList);
      if (!mounted) return;

      setState(() {
        _allProducts = filteredList;
        _categories = categories;
        _isLoading = false;
      });
      if (!mounted) return;
      _filterProducts();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<String> _deriveCategories(List<ProductItem> products) {
    final categories =
        products
            .map((product) => product.categoryName?.trim())
            .where((category) => category != null && category.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...categories];
  }

  void _createProductAnimations() {
    for (final c in _productControllers) {
      c.dispose();
    }
    _productControllers = List.generate(
      _filteredProducts.length,
      (i) => AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      ),
    );
    for (int i = 0; i < _productControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 80 * i), () {
        if (mounted && i < _productControllers.length) {
          _productControllers[i].forward();
        }
      });
    }
  }

  void _filterProducts() {
    final currentUserId = SupabaseConfig.currentUser?.id;
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        if (currentUserId != null && p.farmerId == currentUserId) {
          return false;
        }
        if (_currentFarmerId != null && p.farmerId == _currentFarmerId) {
          return false;
        }

        final isPreorderItem = p.isPreorder;
        final diff = DateTime.now().difference(p.createdAt ?? DateTime.now());
        final harvestDays = int.tryParse(p.harvestDays ?? '') ?? 0;
        final remainingDays = harvestDays - diff.inDays;

        if (_showPreOrders) {
          if (!isPreorderItem || remainingDays < 0) {
            return false;
          }
        } else {
          if (isPreorderItem && remainingDays >= 0) {
            return false;
          }
        }

        final matchesCategory =
            _selectedCategory == 'All' ||
            (p.categoryName?.toLowerCase() == _selectedCategory.toLowerCase());

        final matchesSearch =
            _searchQuery.isEmpty ||
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.farm.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (p.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

        final priceVal =
            double.tryParse(p.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        final matchesPrice =
            _priceRange >= 500 || priceVal <= _priceRange;

        final matchesVerified =
            !_verifiedOnly ||
            (p.farmerName != null && p.farmerName!.isNotEmpty) ||
            (p.farm.isNotEmpty && p.farm != 'Farm');

        return matchesCategory &&
            matchesSearch &&
            matchesPrice &&
            matchesVerified;
      }).toList();

      // Sort logic
      if (_sortBy == 'Price: Low to High') {
        _filteredProducts.sort((a, b) {
          final pa =
              double.tryParse(a.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
          final pb =
              double.tryParse(b.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
          return pa.compareTo(pb);
        });
      } else if (_sortBy == 'Price: High to Low') {
        _filteredProducts.sort((a, b) {
          final pa =
              double.tryParse(a.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
          final pb =
              double.tryParse(b.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
          return pb.compareTo(pa);
        });
      } else if (_sortBy == 'Popular') {
        _filteredProducts.sort((a, b) {
          final ra = double.tryParse(a.rating ?? '0') ?? 0.0;
          final rb = double.tryParse(b.rating ?? '0') ?? 0.0;
          return rb.compareTo(ra);
        });
      }

      _currentPage = 1;
    });
    _createProductAnimations();
  }

  List<ProductItem> get _paginatedProducts {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    if (start >= _filteredProducts.length) return [];
    return _filteredProducts.sublist(
      start,
      end > _filteredProducts.length ? _filteredProducts.length : end,
    );
  }

  int get _totalPages => (_filteredProducts.length / _itemsPerPage).ceil();

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Animated background blobs (inspired by home screen)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _blobController,
              builder: (context, _) {
                return CustomPaint(
                  painter: BlobPainter(
                    animationValue: _blobController.value,
                    color: AgriColors.emerald400.withValues(alpha: 0.05),
                    center: const Offset(0.85, 0.15),
                    radius: 200,
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _blobController,
              builder: (context, _) {
                return CustomPaint(
                  painter: BlobPainter(
                    animationValue: 1 - _blobController.value,
                    color: AgriColors.teal400.withValues(alpha: 0.05),
                    center: const Offset(0.15, 0.85),
                    radius: 250,
                  ),
                );
              },
            ),
          ),
          // Floating particles
          const Positioned.fill(
            child: FloatingParticles(
              count: 20,
              maxSize: 2,
              color: Color(0xFF34D399),
              height: 1000,
            ),
          ),
          // Main content
FadeTransition(
            opacity: CurvedAnimation(
              parent: _fadeInController,
              curve: Curves.easeOut,
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: sw < 768 ? 12 : 32,
                    vertical: 16,
                  ),
                  child: _buildNavBar(),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sw >= 768) _buildSidebar(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(
                            sw < 480
                                ? 16
                                : sw < 768
                                ? 20
                                : 32,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildBreadcrumb(),
                              const SizedBox(height: 16),
                              _buildToolbar(),
                              if (sw < 768) ...[
                                const SizedBox(height: 14),
                                _buildMobileCategoryChips(),
                              ],
                              if (_hasActiveFilters) ...[
                                const SizedBox(height: 14),
                                _buildActiveFilterChips(),
                              ],
                              const SizedBox(height: 24),
                              // Featured section on home category
                              if (_selectedCategory == 'All' && _searchQuery.isEmpty) ...[
                                _buildFeaturedSection(),
                                const SizedBox(height: 36),
                              ],
                              _isLoading
                                  ? _buildLoadingGrid()
                                  : _filteredProducts.isEmpty
                                  ? _buildEmptyState()
                                  : _buildProductGrid(),
                              if (!_isLoading &&
                                  _filteredProducts.isNotEmpty) ...[
                                const SizedBox(height: 40),
                                _buildPagination(),
                              ],
                              const SizedBox(height: 56),
                              const AgriDirectWebFooter(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // NAV BAR (modern floating)
  // ─────────────────────────────────────────────
  Widget _buildNavBar() {
    return WebConsumerNavBar(
      currentIndex: widget.currentIndex,
      onNavigate: widget.onNavigate,
      onCartTap: () => context.go(AppRoutes.cart),
      margin: EdgeInsets.zero,
    );
  }

  void _openFarmerProfile(String? farmerId) {
    if (farmerId == null || farmerId.isEmpty) return;
    context.go(AppRoutes.farmerProfile(farmerId));
  }

  Future<void> _addToCart(ProductItem product) async {
    final errorMsg = await CartService().addItem(product);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errorMsg ?? '${product.name} added to cart')));
  }

  void _openProduct(ProductItem product) {
    context.push(
      _showPreOrders ? AppRoutes.preorderDetails : AppRoutes.productDetails,
      extra: product,
    );
  }

  void _setShopMode(bool showPreOrders) {
    final target = showPreOrders
        ? '${AppRoutes.shop}?mode=preorders'
        : AppRoutes.shop;
    context.go(target);
  }

  // ─────────────────────────────────────────────
  // SIDEBAR (modern & rich)
  // ─────────────────────────────────────────────
  Widget _buildSidebar() {
    final sw = MediaQuery.of(context).size.width;
    if (sw < 768) {
      return const SizedBox.shrink(); // Hide on mobile
    }
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: _white,
        border: Border(right: BorderSide(color: _border, width: 1)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input inside sidebar
            Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(fontSize: 13, color: _dark),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                  _filterProducts();
                },
                decoration: InputDecoration(
                  hintText: 'Search produce or farms...',
                  hintStyle: GoogleFonts.inter(fontSize: 12.5, color: _mutedLight),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _muted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16, color: _muted),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _filterProducts();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category section header with Reset
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Categories',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                    letterSpacing: -0.2,
                  ),
                ),
                if (_hasActiveFilters)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _resetFilters,
                      child: Text(
                        'Reset All',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ..._categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              final catCount = cat == 'All'
                  ? _allProducts.length
                  : _allProducts.where((p) => p.categoryName == cat).length;

              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = cat);
                      _filterProducts();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        vertical: 7,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryLight : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 17,
                                height: 17,
                                decoration: BoxDecoration(
                                  color: isSelected ? _primary : _white,
                                  borderRadius: BorderRadius.circular(4.5),
                                  border: Border.all(
                                    color: isSelected ? _primary : _border,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 11,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 9),
                              Text(
                                cat,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected ? _primary : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _primary.withValues(alpha: 0.15)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$catCount',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? _primary : _muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),
            const Divider(height: 1, color: _border),
            const SizedBox(height: 20),

            // Price Range
            Text(
              'Price Range',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _dark,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 14),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _primary,
                inactiveTrackColor: _border,
                thumbColor: _primary,
                overlayColor: _primary.withValues(alpha: 0.1),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7,
                  elevation: 3,
                ),
              ),
              child: Slider(
                value: _priceRange,
                min: 0,
                max: 500,
                onChanged: (v) {
                  setState(() => _priceRange = v);
                  _filterProducts();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₱0',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: _mutedLight,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      _priceRange >= 500 ? 'All Prices' : 'Up to ₱${_priceRange.toInt()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                  ),
                  Text(
                    '₱500+',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: _mutedLight,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(height: 1, color: _border),
            const SizedBox(height: 20),

            // Verified Farmers Only Toggle
            InkWell(
              onTap: () {
                setState(() => _verifiedOnly = !_verifiedOnly);
                _filterProducts();
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: _verifiedOnly ? _primary : _white,
                        borderRadius: BorderRadius.circular(4.5),
                        border: Border.all(
                          color: _verifiedOnly ? _primary : _border,
                          width: 1.5,
                        ),
                      ),
                      child: _verifiedOnly
                          ? const Icon(
                              Icons.check,
                              size: 11,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 9),
                    const Icon(Icons.verified_rounded, size: 14, color: _primary),
                    const SizedBox(width: 4),
                    Text(
                      'Verified Farms Only',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: _verifiedOnly ? FontWeight.w700 : FontWeight.w500,
                        color: _verifiedOnly ? _primary : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Farm-to-Table Assurance Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _primary.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Direct Farm Delivery',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF14532D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Harvested and packed fresh from verified local growers. 100% freshness guarantee.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: const Color(0xFF166534),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // MOBILE CATEGORY CHIPS
  // ─────────────────────────────────────────────
  Widget _buildMobileCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = cat);
                _filterProducts();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? _primary : _white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _primary : _border,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  cat,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ACTIVE FILTER CHIPS
  // ─────────────────────────────────────────────
  Widget _buildActiveFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Active Filters:',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _muted),
        ),
        if (_selectedCategory != 'All')
          _buildFilterChip('Category: $_selectedCategory', () {
            setState(() => _selectedCategory = 'All');
            _filterProducts();
          }),
        if (_priceRange < 500)
          _buildFilterChip('Max: ₱${_priceRange.toInt()}', () {
            setState(() => _priceRange = 500.0);
            _filterProducts();
          }),
        if (_searchQuery.isNotEmpty)
          _buildFilterChip('Search: "$_searchQuery"', () {
            _searchController.clear();
            setState(() => _searchQuery = '');
            _filterProducts();
          }),
        if (_verifiedOnly)
          _buildFilterChip('Verified Only', () {
            setState(() => _verifiedOnly = false);
            _filterProducts();
          }),
        GestureDetector(
          onTap: _resetFilters,
          child: Text(
            'Clear All',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFDC2626),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _primary),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 13, color: _primary),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // MOBILE FILTER BOTTOM SHEET
  // ─────────────────────────────────────────────
  void _showMobileFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter Products',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Categories',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _dark),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((c) {
                        final isSel = _selectedCategory == c;
                        return ChoiceChip(
                          label: Text(c),
                          selected: isSel,
                          onSelected: (selected) {
                            setModalState(() => _selectedCategory = c);
                            setState(() => _selectedCategory = c);
                            _filterProducts();
                          },
                          selectedColor: _primaryLight,
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel ? _primary : _muted,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Max Price: ${_priceRange >= 500 ? 'All Prices' : '₱${_priceRange.toInt()}'}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _dark),
                    ),
                    Slider(
                      value: _priceRange,
                      min: 0,
                      max: 500,
                      activeColor: _primary,
                      onChanged: (val) {
                        setModalState(() => _priceRange = val);
                        setState(() => _priceRange = val);
                        _filterProducts();
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Verified Farmers Only',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _dark),
                      ),
                      value: _verifiedOnly,
                      activeThumbColor: _primary,
                      onChanged: (val) {
                        setModalState(() => _verifiedOnly = val);
                        setState(() => _verifiedOnly = val);
                        _filterProducts();
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _resetFilters();
                              Navigator.pop(modalContext);
                            },
                            child: const Text('Reset All'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(modalContext),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Apply (${_filteredProducts.length})'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // FEATURED SECTION (dynamic spotlight & grid)
  // ─────────────────────────────────────────────
  Widget _buildFeaturedSection() {
    if (_showPreOrders) return const SizedBox.shrink();
    final currentUserId = SupabaseConfig.currentUser?.id;
    final available = _allProducts.where((p) {
      if (currentUserId != null && p.farmerId == currentUserId) return false;
      if (_currentFarmerId != null && p.farmerId == _currentFarmerId) {
        return false;
      }
      if (p.isPreorder) return false;
      return true;
    }).toList();
    var featuredProducts = available.where((p) => p.isFeatured).toList();
    if (featuredProducts.isEmpty) {
      featuredProducts = List<ProductItem>.from(available);
      featuredProducts.sort((a, b) {
        final ra = double.tryParse(a.rating ?? '0') ?? 0.0;
        final rb = double.tryParse(b.rating ?? '0') ?? 0.0;
        return rb.compareTo(ra);
      });
    }
    featuredProducts = featuredProducts.take(4).toList();
    if (featuredProducts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Featured header with icon
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: AgriColors.goldGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: AgriColors.goldGradient,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: AgriColors.gold400.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Featured This Week',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, size: 12, color: Color(0xFFD97706)),
                  const SizedBox(width: 4),
                  Text(
                    'Handpicked',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Top-rated produce handpicked from our verified local partner farms',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: _muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobileView = constraints.maxWidth < 600;
            if (isMobileView) {
              return SizedBox(
                height: 250,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: featuredProducts.length,
                  itemBuilder: (context, index) {
                    return SizedBox(
                      width: constraints.maxWidth * 0.78,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: _buildFeaturedCard(featuredProducts[index]),
                      ),
                    );
                  },
                ),
              );
            }

            if (featuredProducts.length == 1) {
              return _buildFeaturedSpotlight(featuredProducts.first);
            }

            final count = constraints.maxWidth > 1100
                ? featuredProducts.length.clamp(2, 4)
                : (constraints.maxWidth > 700 ? featuredProducts.length.clamp(2, 3) : 2);

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.84,
              ),
              itemCount: featuredProducts.length,
              itemBuilder: (context, index) {
                return _buildFeaturedCard(featuredProducts[index]);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeaturedSpotlight(ProductItem product) {
    final rawPrice = product.price.replaceAll(RegExp(r'[^0-9.]'), '');
    final double price = double.tryParse(rawPrice) ?? 0.0;
    final String formattedPrice = '₱${price.toStringAsFixed(0)}';
    final String unitLabel = product.unit.isNotEmpty ? ' / ${product.unit}' : '';
    final farmDisplayName = (product.farm.isNotEmpty && product.farm != 'Farm')
        ? product.farm
        : 'Verified Local Farm';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openProduct(product),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFDF5), Color(0xFFFEF3C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 220,
                  height: 150,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      product.imageUrl.isNotEmpty
                          ? SafeNetworkImage(
                              imageUrl: product.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: _buildImagePlaceholder(),
                              errorWidget: _buildImagePlaceholder(),
                            )
                          : _buildImagePlaceholder(),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: AgriColors.goldGradient,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            '⭐ TOP PICK',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.categoryName ?? 'Fresh Produce',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                        Text(
                          ' ${product.rating ?? '5.0'}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _dark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.storefront_rounded, size: 14, color: _primary),
                        const SizedBox(width: 4),
                        Text(
                          farmDisplayName,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              formattedPrice,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: _primary,
                              ),
                            ),
                            Text(
                              unitLabel,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _mutedLight,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _addToCart(product),
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 15),
                          label: const Text('Add to Cart'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5),
                          ),
                        ),
                      ],
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

  Widget _buildBreadcrumb() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, '/'),
          child: Text(
            'Home',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
        ),
        Icon(Icons.chevron_right, size: 14, color: _mutedLight),
        Text(
          _selectedCategory == 'All' ? 'Shop' : _selectedCategory,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _primary,
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _selectedCategory == 'All'
                  ? (_showPreOrders ? "Upcoming Harvests" : "Today's Harvest")
                  : _selectedCategory,
              style: GoogleFonts.plusJakartaSans(
                fontSize: isMobile ? 22 : 26,
                fontWeight: FontWeight.w800,
                color: _dark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _primary.withValues(alpha: 0.2)),
              ),
              child: Text(
                '${_filteredProducts.length} items',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _showPreOrders
              ? 'Reserve early directly from farmers before harvest'
              : 'Direct-from-farm produce harvested in the last 24-48 hours',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: _muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    final controls = [
      // Available Now / Pre-orders switcher
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeToggle(
              label: 'Available Now',
              isSelected: !_showPreOrders,
              onTap: () {
                if (_showPreOrders) {
                  _setShopMode(false);
                }
              },
            ),
            _buildModeToggle(
              label: 'Pre-Orders',
              isSelected: _showPreOrders,
              onTap: () {
                if (!_showPreOrders) {
                  _setShopMode(true);
                }
              },
            ),
          ],
        ),
      ),
      if (isMobile)
        ElevatedButton.icon(
          onPressed: () => _showMobileFilterSheet(context),
          icon: const Icon(Icons.tune_rounded, size: 15),
          label: Text(_activeFiltersCount > 0 ? 'Filters ($_activeFiltersCount)' : 'Filters'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _activeFiltersCount > 0 ? _primary : _white,
            foregroundColor: _activeFiltersCount > 0 ? Colors.white : _dark,
            elevation: 0,
            side: BorderSide(color: _activeFiltersCount > 0 ? _primary : _border),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      // Grid/List toggle
      Container(
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _isGridView = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isGridView ? _primaryLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.grid_view_rounded,
                    size: 16,
                    color: _isGridView ? _primary : _mutedLight,
                  ),
                ),
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _isGridView = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: !_isGridView ? _primaryLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.view_list_rounded,
                    size: 16,
                    color: !_isGridView ? _primary : _mutedLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // Sort dropdown
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert_rounded, size: 16, color: _muted),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                isDense: true,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _dark,
                ),
                items: [
                  'Newest',
                  'Price: Low to High',
                  'Price: High to Low',
                  'Popular',
                ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _sortBy = val);
                    _filterProducts();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    ];

    return isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleColumn,
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: controls,
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              titleColumn,
              Row(
                children: [
                  controls[0],
                  const SizedBox(width: 12),
                  controls[1],
                  const SizedBox(width: 12),
                  controls[2],
                ],
              ),
            ],
          );
  }

  Widget _buildModeToggle({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected ? _primary : _muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(ProductItem product) {
    final productKey = product.hashCode;
    final isHovered = _hoveredProducts.contains(productKey);
    final rawPrice = product.price.replaceAll(RegExp(r'[^0-9.]'), '');
    final double price = double.tryParse(rawPrice) ?? 0.0;
    final String formattedPrice = '₱${price.toStringAsFixed(0)}';
    final String unitLabel = product.unit.isNotEmpty ? ' / ${product.unit}' : '';
    final farmDisplayName = (product.farm.isNotEmpty && product.farm != 'Farm') ? product.farm : 'Local Farm';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredProducts.add(productKey)),
      onExit: (_) => setState(() => _hoveredProducts.remove(productKey)),
      child: GestureDetector(
        onTap: () => _openProduct(product),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          transform: Matrix4.translationValues(0, isHovered ? -5 : 0, 0),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered ? const Color(0xFFF59E0B).withValues(alpha: 0.4) : const Color(0xFFFDE68A),
              width: isHovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: isHovered ? 0.12 : 0.04),
                blurRadius: isHovered ? 18 : 8,
                offset: Offset(0, isHovered ? 6 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.50,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                        color: _surface,
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        child: product.imageUrl.isNotEmpty
                            ? SafeNetworkImage(
                                imageUrl: product.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: _buildImagePlaceholder(),
                                errorWidget: _buildImagePlaceholder(),
                              )
                            : _buildImagePlaceholder(),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          gradient: AgriColors.goldGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '⭐ Featured',
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
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 8, 11, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.storefront_rounded, size: 11, color: _primary),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  farmDisplayName,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: _muted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                formattedPrice,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: _primary,
                                ),
                              ),
                              Text(
                                unitLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: _mutedLight,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => _addToCart(product),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: _primary,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_shopping_cart_rounded, size: 12, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Add',
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

  // ─────────────────────────────────────────────
  // PRODUCT GRID (responsive & modern)
  // ─────────────────────────────────────────────
  Widget _buildProductGrid() {
    final products = _paginatedProducts;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_isGridView) {
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final globalIndex = (_currentPage - 1) * _itemsPerPage + index;
              return globalIndex < _productControllers.length
                  ? _buildAnimatedProductListCard(
                      products[index],
                      _productControllers[globalIndex],
                    )
                  : _buildProductListCard(products[index]);
            },
          );
        }

        final crossAxisCount = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 850
            ? 3
            : 2;

        final double childAspectRatio = constraints.maxWidth < 480
            ? (_showPreOrders ? 0.70 : 0.78)
            : (constraints.maxWidth < 700
                ? (_showPreOrders ? 0.74 : 0.82)
                : (constraints.maxWidth < 1100
                    ? (_showPreOrders ? 0.78 : 0.86)
                    : (_showPreOrders ? 0.80 : 0.88)));

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final globalIndex = (_currentPage - 1) * _itemsPerPage + index;
            return globalIndex < _productControllers.length
                ? _buildAnimatedProductCard(
                    products[index],
                    _productControllers[globalIndex],
                  )
                : _buildProductCard(products[index]);
          },
        );
      },
    );
  }

  Widget _buildAnimatedProductCard(
    ProductItem product,
    AnimationController controller,
  ) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0,
        end: 1,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
            ),
        child: _buildProductCard(product),
      ),
    );
  }

  Widget _buildAnimatedProductListCard(
    ProductItem product,
    AnimationController controller,
  ) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0,
        end: 1,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
            ),
        child: _buildProductListCard(product),
      ),
    );
  }

  Widget _buildProductListCard(ProductItem product) {
    final isHovered = _hoveredProducts.contains(product.hashCode);
    final badgeIndex = product.hashCode.abs() % _badgeData.length;
    final badge = _badgeData[badgeIndex];
    final farmDisplayName = (product.farm.isNotEmpty && product.farm != 'Farm')
        ? product.farm
        : 'Local Farm';

    final rawPrice = product.price.replaceAll(RegExp(r'[^0-9.]'), '');
    final double price = double.tryParse(rawPrice) ?? 0.0;
    final String formattedPrice = '₱${price.toStringAsFixed(0)}';
    final String unitLabel = product.unit.isNotEmpty ? ' / ${product.unit}' : '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredProducts.add(product.hashCode)),
      onExit: (_) => setState(() => _hoveredProducts.remove(product.hashCode)),
      child: GestureDetector(
        onTap: () => _openProduct(product),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          transform: Matrix4.translationValues(isHovered ? 4 : 0, 0, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered ? _primary.withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
              width: isHovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isHovered ? _primary.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.03),
                blurRadius: isHovered ? 16 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _surface,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      product.imageUrl.isNotEmpty
                          ? SafeNetworkImage(
                              imageUrl: product.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: _buildImagePlaceholder(),
                              errorWidget: _buildImagePlaceholder(),
                            )
                          : _buildImagePlaceholder(),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: (badge['color'] as Color).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge['label'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.storefront_rounded, size: 12, color: _primary),
                        const SizedBox(width: 4),
                        Text(
                          farmDisplayName,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                        ),
                        if (product.rating != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                          Text(
                            ' ${product.rating!}',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _dark),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        formattedPrice,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _primary,
                        ),
                      ),
                      Text(
                        unitLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _mutedLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _addToCart(product),
                    icon: Icon(
                      _showPreOrders ? Icons.calendar_today_rounded : Icons.add_shopping_cart_rounded,
                      size: 13,
                    ),
                    label: Text(_showPreOrders ? 'Reserve' : 'Add to Cart'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Badge colors per product index
  static const _badgeData = [
    {'label': 'ORGANIC', 'color': Color(0xFF16A34A)},
    {'label': 'LOCAL', 'color': Color(0xFF2563EB)},
    {'label': 'PREMIUM', 'color': Color(0xFF9333EA)},
    {'label': 'ECO-PACK', 'color': Color(0xFF0891B2)},
    {'label': 'NUTRIENT RICH', 'color': Color(0xFFEA580C)},
    {'label': 'FRESH', 'color': Color(0xFFF59E0B)},
  ];

  Widget _buildProductCard(ProductItem product) {
    final isHovered = _hoveredProducts.contains(product.hashCode);
    final badgeIndex = product.hashCode.abs() % _badgeData.length;
    final badge = _badgeData[badgeIndex];
    final farmDisplayName = (product.farm.isNotEmpty && product.farm != 'Farm')
        ? product.farm
        : 'Local Farm';

    final rawPrice = product.price.replaceAll(RegExp(r'[^0-9.]'), '');
    final double price = double.tryParse(rawPrice) ?? 0.0;
    final String formattedPrice = '₱${price.toStringAsFixed(0)}';
    final String unitLabel = product.unit.isNotEmpty ? ' / ${product.unit}' : '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredProducts.add(product.hashCode)),
      onExit: (_) => setState(() => _hoveredProducts.remove(product.hashCode)),
      child: GestureDetector(
        onTap: () => _openProduct(product),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          transform: Matrix4.translationValues(0, isHovered ? -5 : 0, 0),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered ? _primary.withValues(alpha: 0.35) : const Color(0xFFF1F5F9),
              width: isHovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isHovered
                    ? _primary.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: isHovered ? 20 : 10,
                offset: Offset(0, isHovered ? 8 : 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Image
              AspectRatio(
                aspectRatio: 1.35,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                        color: _surface,
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        child: product.imageUrl.isNotEmpty
                            ? SafeNetworkImage(
                                imageUrl: product.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: _buildImagePlaceholder(),
                                errorWidget: _buildImagePlaceholder(),
                              )
                            : _buildImagePlaceholder(),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: (badge['color'] as Color).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: (badge['color'] as Color).withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          badge['label'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.favorite_border_rounded,
                          size: 14,
                          color: isHovered ? _primary : _muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Bottom Details - Balanced Compact Spacing
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _dark,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFE2E8F0),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.storefront_rounded,
                                size: 9.5,
                                color: _primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _openFarmerProfile(product.farmerId),
                              child: Text(
                                farmDisplayName,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _muted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (product.rating != null) ...[
                            const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                            Text(
                              ' ${product.rating!}',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: _dark,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      if (_showPreOrders) ...[
                        Builder(
                          builder: (context) {
                            final totalDays = int.tryParse(product.harvestDays ?? '') ?? 0;
                            final remainingDays = product.createdAt == null
                                ? totalDays
                                : product.createdAt!.add(Duration(days: totalDays)).difference(DateTime.now()).inDays + 1;
                            final harvestLabel = remainingDays > 0
                                ? 'Harvest in $remainingDays d'
                                : (remainingDays == 0 ? 'Harvesting today' : 'Harvested');
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFFEA580C)),
                                  const SizedBox(width: 4),
                                  Text(
                                    harvestLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFEA580C),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formattedPrice,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: _primary,
                            ),
                          ),
                          Text(
                            unitLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _mutedLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _addToCart(product),
                          icon: Icon(
                            _showPreOrders ? Icons.calendar_today_rounded : Icons.add_shopping_cart_rounded,
                            size: 13,
                          ),
                          label: Text(_showPreOrders ? 'Reserve' : 'Add to Cart'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Icon(Icons.image_rounded, size: 40, color: Colors.grey[300]),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // PAGINATION
  // ─────────────────────────────────────────────
  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Previous
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _currentPage > 1
                  ? () => setState(() => _currentPage--)
                  : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: Icon(
                  Icons.chevron_left,
                  size: 18,
                  color: _currentPage > 1 ? _dark : _border,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Page numbers
          ...List.generate(_totalPages > 5 ? 5 : _totalPages, (i) {
            final page = i + 1;
            final isActive = page == _currentPage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _currentPage = page),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isActive ? _primary : _white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isActive ? _primary : _border),
                    ),
                    child: Center(
                      child: Text(
                        '$page',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive ? _white : _dark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          // Next
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _currentPage < _totalPages
                  ? () => setState(() => _currentPage++)
                  : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: _currentPage < _totalPages ? _dark : _border,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // LOADING & EMPTY STATES
  // ─────────────────────────────────────────────
  Widget _buildLoadingGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 900
            ? 3
            : constraints.maxWidth > 600
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            mainAxisExtent: _showPreOrders ? 360 : 330,
          ),
          itemCount: 8,
          itemBuilder: (context, index) => const AppShimmerCard(),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: _primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _showPreOrders ? 'No pre-orders found' : 'No products found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search or filters.'
                  : _showPreOrders
                  ? 'No pre-orders in this category yet.'
                  : 'No products in this category yet.',
              style: GoogleFonts.inter(fontSize: 14, color: _muted),
            ),
            const SizedBox(height: 24),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = 'All';
                    _searchQuery = '';
                    _searchController.clear();
                  });
                  _filterProducts();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Clear Filters',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

