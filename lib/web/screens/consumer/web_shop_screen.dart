import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../widgets/animated_components.dart';
import '../../widgets/web_consumer_nav_bar.dart';

/// Web Shop Screen — Fresh Produce Marketplace
/// Dark navbar, left sidebar filters, product grid with badges
class WebShopScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final int currentIndex;
  final bool initialShowPreOrders;

  const WebShopScreen({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
    this.initialShowPreOrders = false,
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
  List<ProductItem> _allProducts = [];
  List<ProductItem> _filteredProducts = [];
  bool _isLoading = true;
  bool _isGridView = true;
  bool _showPreOrders = false;
  String _selectedCategory = 'All';
  String _sortBy = 'Newest';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  double _priceRange = 100.0;
  int _currentPage = 1;
  final int _itemsPerPage = 12;

  List<String> _categories = ['All'];

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
    _loadProducts();
  }

  @override
  void didUpdateWidget(covariant WebShopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialShowPreOrders != widget.initialShowPreOrders) {
      _showPreOrders = widget.initialShowPreOrders;
      _selectedCategory = 'All';
      _searchQuery = '';
      _searchController.clear();
      _currentPage = 1;
      _loadProducts();
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
      final products = _showPreOrders
          ? await _dataService.getPreOrderProducts()
          : await _dataService.getNearbyProducts();
      final categories = _deriveCategories(products);
      if (!mounted) return;

      setState(() {
        _allProducts = products;
        _filteredProducts = products;
        _categories = categories;
        _isLoading = false;
      });
      if (!mounted) return;
      _createProductAnimations();
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
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        final matchesCategory =
            _selectedCategory == 'All' ||
            (p.categoryName?.toLowerCase() == _selectedCategory.toLowerCase());

        final matchesSearch =
            _searchQuery.isEmpty ||
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.farm.toLowerCase().contains(_searchQuery.toLowerCase());

        final matchesPrice =
            (double.tryParse(p.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0) <=
            _priceRange;

        return matchesCategory &&
            matchesSearch &&
            (_priceRange >= 500 || matchesPrice);
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
                              const SizedBox(height: 24),
                              _buildToolbar(),
                              const SizedBox(height: 40),
                              // Featured section on home category
                              if (_selectedCategory == 'All') ...[
                                _buildFeaturedSection(),
                                const SizedBox(height: 48),
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
                              _buildFooter(),
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
    await CartService().addItem(product);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${product.name} added to cart')));
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
  // SIDEBAR (modern)
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
            // Category section
            Text(
              'Categories',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _dark,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 16),
            ..._categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = cat);
                      _filterProducts();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryLight : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          // Checkbox style
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: isSelected ? _primary : _white,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isSelected ? _primary : _border,
                                width: 1.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            cat,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected ? _primary : _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 28),
            Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_border, _border.withValues(alpha: 0.1)],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Price Range
            Text(
              'Price Range',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _dark,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 18),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _primary,
                inactiveTrackColor: _border,
                thumbColor: _primary,
                overlayColor: _primary.withValues(alpha: 0.1),
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8,
                  elevation: 4,
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
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _mutedLight,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      '₱${_priceRange.toInt()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                  ),
                  Text(
                    '₱500+',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _mutedLight,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_border, _border.withValues(alpha: 0.1)],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Farm-to-Table info card (modernized)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _primary.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: AgriColors.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Farm-to-Table',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Direct from verified farms. Fresh produce delivered within 24 hours.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _primary.withValues(alpha: 0.8),
                      height: 1.6,
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
  // BREADCRUMB
  // ─────────────────────────────────────────────
  Widget _buildBreadcrumb() {
    return Row(
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => widget.onNavigate(0),
            child: Text(
              'Home',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.chevron_right, size: 16, color: _muted),
        ),
        Text(
          _selectedCategory == 'All'
              ? (_showPreOrders ? 'Pre-Orders' : 'Fresh Produce')
              : _selectedCategory,
          style: GoogleFonts.inter(fontSize: 13, color: _muted),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // TOOLBAR (modern)
  // ─────────────────────────────────────────────
  Widget _buildFeaturedSection() {
    if (_showPreOrders) return const SizedBox.shrink();
    var featuredProducts = _allProducts.where((p) => p.isFeatured).toList();
    if (featuredProducts.isEmpty) {
      featuredProducts = List<ProductItem>.from(_allProducts);
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
          children: [
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                gradient: AgriColors.goldGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 28,
              height: 28,
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
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Featured This Week',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _dark,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Top-rated picks handpicked from our finest farms',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: _muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        // Featured grid (4 items)
        LayoutBuilder(
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
                mainAxisExtent: 392,
              ),
              itemCount: featuredProducts
                  .take(
                    crossAxisCount == 4
                        ? 4
                        : crossAxisCount == 3
                        ? 3
                        : 2,
                  )
                  .length,
              itemBuilder: (context, index) {
                return _buildFeaturedCard(featuredProducts[index]);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(ProductItem product) {
    final productKey = product.hashCode;
    final isHovered = _hoveredProducts.contains(productKey);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredProducts.add(productKey)),
      onExit: (_) => setState(() => _hoveredProducts.remove(productKey)),
      child: GestureDetector(
        onTap: () => _openProduct(product),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          transform: Matrix4.translationValues(0, isHovered ? -8 : 0, 0),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isHovered ? _primary.withValues(alpha: 0.3) : _border,
              width: isHovered ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.1),
                blurRadius: isHovered ? 32 : 0,
                offset: const Offset(0, 0),
                spreadRadius: isHovered ? 4 : 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: isHovered ? 20 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image with featured badge
                  Expanded(
                    flex: 3,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18),
                            ),
                            color: _surface,
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18),
                            ),
                            child: product.imageUrl.isNotEmpty
                                ? SafeNetworkImage(
                                    imageUrl: product.imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    placeholder: _buildImagePlaceholder(),
                                    errorWidget: _buildImagePlaceholder(),
                                  )
                                : _buildImagePlaceholder(),
                          ),
                        ),
                        // Featured badge
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFF59E0B),
                                  const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Text(
                              '✨ Featured',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Details section
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _dark,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              // Farm badge
                              GestureDetector(
                                onTap: () =>
                                    _openFarmerProfile(product.farmerId),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _primaryLight,
                                        _primaryLight.withValues(alpha: 0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: _primary.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.store_rounded,
                                        size: 12,
                                        color: _primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        product.farm,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _primary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ...List.generate(5, (s) {
                                    final rating =
                                        double.tryParse(
                                          product.rating ?? '0',
                                        ) ??
                                        0;
                                    return Icon(
                                      s < rating.floor()
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 13,
                                      color: s < rating.floor()
                                          ? const Color(0xFFFCA5A5)
                                          : _border,
                                    );
                                  }),
                                  const SizedBox(width: 5),
                                  Text(
                                    product.rating ?? '0',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _dark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                product.price,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: _primary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 11),
                              // Add to cart button
                              SizedBox(
                                width: double.infinity,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => _addToCart(product),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: isHovered
                                            ? LinearGradient(
                                                colors: [
                                                  _primary,
                                                  _primary.withValues(
                                                    alpha: 0.7,
                                                  ),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : LinearGradient(
                                                colors: [
                                                  _primaryLight,
                                                  _primaryLight,
                                                ],
                                              ),
                                        borderRadius: BorderRadius.circular(11),
                                        border: Border.all(
                                          color: isHovered
                                              ? _primary
                                              : _primary.withValues(alpha: 0.2),
                                          width: 1.5,
                                        ),
                                        boxShadow: isHovered
                                            ? [
                                                BoxShadow(
                                                  color: _primary.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.shopping_bag,
                                            size: 16,
                                            color: isHovered
                                                ? _white
                                                : _primary,
                                          ),
                                          const SizedBox(width: 7),
                                          Text(
                                            'Add to Cart',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: isHovered
                                                  ? _white
                                                  : _primary,
                                            ),
                                          ),
                                        ],
                                      ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 750;

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Heading with gradient effect
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [_dark, _primary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(bounds),
          child: Text(
            _selectedCategory == 'All'
                ? (_showPreOrders ? 'Upcoming Harvests' : "Today's Harvest")
                : _selectedCategory,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _showPreOrders
                  ? '${_filteredProducts.length} pre-orders available'
                  : '${_filteredProducts.length} fresh items available',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );

    final controls = [
      // Available Now / Pre-orders switcher
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
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
      // Grid/List toggle with premium style
      Container(
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _isGridView = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isGridView
                        ? _primaryLight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.grid_view_rounded,
                    size: 17,
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
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: !_isGridView
                        ? _primaryLight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.view_list_rounded,
                    size: 17,
                    color: !_isGridView ? _primary : _mutedLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // Sort dropdown with premium styling
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 17, color: _muted),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                isDense: true,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _dark,
                ),
                items:
                    [
                          'Newest',
                          'Price: Low to High',
                          'Price: High to Low',
                          'Popular',
                        ]
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e)),
                        )
                        .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _sortBy = val);
                    _filterProducts();
                  }
                },
              ),
            ),
            Icon(Icons.unfold_more, size: 16, color: _muted),
          ],
        ),
      ),
    ];

    return isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleColumn,
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
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
                  const SizedBox(width: 14),
                  controls[1],
                  const SizedBox(width: 14),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

  // ─────────────────────────────────────────────
  // PRODUCT GRID (enhanced with animations)
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
            separatorBuilder: (context, index) => const SizedBox(height: 16),
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
            mainAxisExtent: 392,
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
        position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
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
        position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredProducts.add(product.hashCode)),
      onExit: (_) => setState(() => _hoveredProducts.remove(product.hashCode)),
      child: GestureDetector(
        onTap: () => _openProduct(product),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          transform: Matrix4.translationValues(isHovered ? 8 : 0, 0, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isHovered ? _border.withValues(alpha: 0.5) : _border,
              width: isHovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.08),
                blurRadius: isHovered ? 24 : 0,
                offset: const Offset(0, 0),
                spreadRadius: isHovered ? 2 : 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: isHovered ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Image
              Container(
                width: 120,
                height: 120,
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
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (badge['color'] as Color).withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge['label'] as String,
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
              ),
              const SizedBox(width: 20),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _openFarmerProfile(product.farmerId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.store_rounded,
                              size: 12,
                              color: _primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              product.farm,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (product.rating != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ...List.generate(5, (s) {
                            final rating =
                                double.tryParse(product.rating!) ?? 0;
                            return Icon(
                              s < rating.floor()
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 13,
                              color: s < rating.floor()
                                  ? const Color(0xFFFCA5A5)
                                  : _border,
                            );
                          }),
                          const SizedBox(width: 6),
                          Text(
                            product.rating!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Price and Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product.price,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _primary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    product.unit,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _mutedLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _addToCart(product),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: isHovered
                              ? LinearGradient(
                                  colors: [
                                    _primary,
                                    _primary.withValues(alpha: 0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [_primaryLight, _primaryLight],
                                ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isHovered
                                ? _primary
                                : _primary.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_bag,
                              size: 15,
                              color: isHovered ? _white : _primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Add to Cart',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isHovered ? _white : _primary,
                              ),
                            ),
                          ],
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredProducts.add(product.hashCode)),
      onExit: (_) => setState(() => _hoveredProducts.remove(product.hashCode)),
      child: GestureDetector(
        onTap: () => _openProduct(product),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          transform: Matrix4.translationValues(0, isHovered ? -8 : 0, 0),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isHovered ? _border.withValues(alpha: 0.5) : _border,
              width: isHovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.1),
                blurRadius: isHovered ? 32 : 0,
                offset: const Offset(0, 0),
                spreadRadius: isHovered ? 4 : 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: isHovered ? 20 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        color: _surface,
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        child: Stack(
                          children: [
                            product.imageUrl.isNotEmpty
                                ? SafeNetworkImage(
                                    imageUrl: product.imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    placeholder: _buildImagePlaceholder(),
                                    errorWidget: _buildImagePlaceholder(),
                                  )
                                : _buildImagePlaceholder(),
                            if (isHovered)
                              AnimatedOpacity(
                                opacity: 0.1,
                                duration: const Duration(milliseconds: 300),
                                child: Container(color: _primary),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (badge['color'] as Color).withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                              color: (badge['color'] as Color).withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: isHovered ? 16 : 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          badge['label'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: _border.withValues(alpha: 0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: isHovered ? 12 : 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.favorite_outline,
                          size: 17,
                          color: isHovered ? _primary : _muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _dark,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          GestureDetector(
                            onTap: () => _openFarmerProfile(product.farmerId),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _primaryLight,
                                    _primaryLight.withValues(alpha: 0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: _primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.store_rounded,
                                    size: 12,
                                    color: _primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      product.farm,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _primary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (product.rating != null) ...[
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                ...List.generate(5, (s) {
                                  final rating =
                                      double.tryParse(product.rating!) ?? 0;
                                  return Icon(
                                    s < rating.floor()
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 13,
                                    color: s < rating.floor()
                                        ? const Color(0xFFFCA5A5)
                                        : _border,
                                  );
                                }),
                                const SizedBox(width: 5),
                                Text(
                                  product.rating!,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _dark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.price,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: _primary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            product.unit,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: _mutedLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 11),
                          SizedBox(
                            width: double.infinity,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => _addToCart(product),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isHovered
                                        ? LinearGradient(
                                            colors: [
                                              _primary,
                                              _primary.withValues(alpha: 0.7),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : LinearGradient(
                                            colors: [
                                              _primaryLight,
                                              _primaryLight,
                                            ],
                                          ),
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(
                                      color: isHovered
                                          ? _primary
                                          : _primary.withValues(alpha: 0.2),
                                      width: 1.5,
                                    ),
                                    boxShadow: isHovered
                                        ? [
                                            BoxShadow(
                                              color: _primary.withValues(
                                                alpha: 0.1,
                                              ),
                                              blurRadius: 16,
                                              offset: const Offset(0, 6),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.shopping_bag,
                                        size: 16,
                                        color: isHovered ? _white : _primary,
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        'Add to Cart',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isHovered ? _white : _primary,
                                        ),
                                      ),
                                    ],
                                  ),
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.68,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    color: Colors.grey[100],
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: AppShimmerLoader(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _primary.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

  // ─────────────────────────────────────────────
  // FOOTER
  // ─────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _dark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Company
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AgriDirect',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bringing fresh, organic produce\nfrom local farms directly to you.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF9CA3AF),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              // Support
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Support',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...[
                      'Help Center',
                      'Delivery Info',
                      'Returns',
                      'Contact Us',
                    ].map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          t,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Newsletter
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stay Updated',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Subscribe for weekly harvest updates.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F2937),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF374151),
                              ),
                            ),
                            child: TextField(
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _white,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Email',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF6B7280),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(height: 1, color: const Color(0xFF374151)),
          const SizedBox(height: 16),
          Text(
            '© 2025 AgriDirect. All rights reserved.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
