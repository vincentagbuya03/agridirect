import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/services/supabase_data_service.dart';
import '../../widgets/animated_components.dart';

/// Web Shop Screen — Fresh Produce Marketplace
/// Dark navbar, left sidebar filters, product grid with badges
class WebShopScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final int currentIndex;

  const WebShopScreen({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
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
  String _selectedCategory = 'All';
  String _sortBy = 'Newest';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  double _priceRange = 100.0;
  bool _organicOnly = false;
  int _currentPage = 1;
  final int _itemsPerPage = 12;

  final List<String> _categories = [
    'All',
    'Vegetables',
    'Fruits',
    'Grains',
    'Dairy',
    'Eggs',
    'Honey',
    'Meat',
    'Herbs',
  ];

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
    _loadProducts();
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
      final products = await _dataService.getAllProducts();
      setState(() {
        _allProducts = products;
        _filteredProducts = products;
        _isLoading = false;
      });
      _createProductAnimations();
    } catch (e) {
      setState(() => _isLoading = false);
    }
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
        final matchesCategory = _selectedCategory == 'All' ||
            p.name.toLowerCase().contains(_selectedCategory.toLowerCase());
        final matchesSearch = _searchQuery.isEmpty ||
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.farm.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
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
                    color: AgriColors.emerald400.withValues(alpha: 0.03),
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
                    color: AgriColors.teal400.withValues(alpha: 0.02),
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
            opacity: CurvedAnimation(parent: _fadeInController, curve: Curves.easeOut),
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
                          padding: EdgeInsets.all(sw < 480 ? 16 : sw < 768 ? 20 : 32),
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
                              if (!_isLoading && _filteredProducts.isNotEmpty) ...[
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
    final tabs = ['Produce', 'Dairy', 'Grains', 'Organic'];
    final sw = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sw < 768 ? 12 : 24,
        vertical: 12,
      ),
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: sw < 768 ? 16 : 24,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Logo
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => widget.onNavigate(0),
                child: Row(
                  children: [
                    PulsingGlow(
                      color: _primary,
                      radius: 16,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: AgriColors.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: AnimatedLeafIcon(size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AgriDirect',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 40),
            // Category tabs - hidden on mobile
            if (sw >= 768)
              ...tabs.map((t) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedCategory = t == 'Produce' ? 'Vegetables' : t);
                          _filterProducts();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: (_selectedCategory == t ||
                                    (t == 'Produce' && _selectedCategory == 'Vegetables'))
                                ? _primaryLight
                                : Colors.transparent,
                          ),
                          child: Text(
                            t,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: (_selectedCategory == t ||
                                      (t == 'Produce' && _selectedCategory == 'Vegetables'))
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: (_selectedCategory == t ||
                                      (t == 'Produce' && _selectedCategory == 'Vegetables'))
                                  ? _primary
                                  : _muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )),
            const Spacer(),
            // Search bar
            if (sw >= 600)
              Container(
                width: 240,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 16, color: _mutedLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) {
                          _searchQuery = v;
                          _filterProducts();
                        },
                        style: GoogleFonts.inter(fontSize: 13, color: _dark),
                        decoration: InputDecoration(
                          hintText: 'Search produce...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 13,
                            color: _mutedLight,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (sw >= 600) const SizedBox(width: 16),
            // Cart
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Stack(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _primary.withValues(alpha: 0.2)),
                    ),
                    child: Icon(Icons.shopping_bag_outlined, size: 18, color: _primary),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: _primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '3',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Profile avatar
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => widget.onNavigate(3),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _primary,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(Icons.person_rounded, size: 20, color: _primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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
                                ? const Icon(Icons.check, size: 12, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            cat,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
                  colors: [
                    _border,
                    _border.withValues(alpha: 0),
                  ],
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
                overlayColor: _primary.withValues(alpha: 0.15),
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
                onChanged: (v) => setState(() => _priceRange = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('\$0', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: _mutedLight)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _primary.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      '\$${_priceRange.toInt()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                  ),
                  Text('\$500+', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: _mutedLight)),
                ],
              ),
            ),

            const SizedBox(height: 28),
            Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _border,
                    _border.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Attributes
            Text(
              'Attributes',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _dark,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 16),
            _buildAttributeToggle('Organic Certified', _organicOnly, (v) {
              setState(() => _organicOnly = v);
            }),

            const SizedBox(height: 28),
            Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _border,
                    _border.withValues(alpha: 0),
                  ],
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
                border: Border.all(color: _primary.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.08),
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
                          color: _primary,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.local_shipping_rounded, size: 16, color: Colors.white),
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
                      color: _primary.withValues(alpha: 0.7),
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

  Widget _buildAttributeToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.eco_rounded, size: 16, color: value ? _primary : _muted),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: value ? _dark : _muted,
                  ),
                ),
              ],
            ),
            // Toggle switch
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 22,
              decoration: BoxDecoration(
                color: value ? _primary : _border,
                borderRadius: BorderRadius.circular(11),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
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
              style: GoogleFonts.inter(fontSize: 13, color: _primary, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.chevron_right, size: 16, color: _muted),
        ),
        Text(
          _selectedCategory == 'All' ? 'Fresh Produce' : _selectedCategory,
          style: GoogleFonts.inter(fontSize: 13, color: _muted),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // TOOLBAR (modern)
  // ─────────────────────────────────────────────
  Widget _buildFeaturedSection() {
    final featuredProducts = _filteredProducts.take(4).toList();
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
                color: _primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '⭐ Featured This Week',
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
                childAspectRatio: 0.68,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: featuredProducts.take(crossAxisCount == 4 ? 4 : crossAxisCount == 3 ? 3 : 2).length,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        transform: Matrix4.translationValues(0, isHovered ? -8 : 0, 0),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isHovered ? _primary.withValues(alpha: 0.4) : _border,
            width: isHovered ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: isHovered ? 0.15 : 0),
              blurRadius: isHovered ? 32 : 0,
              offset: const Offset(0, 0),
              spreadRadius: isHovered ? 4 : 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isHovered ? 0.08 : 0.03),
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
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                          color: _surface,
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                          child: product.imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: product.imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => _buildImagePlaceholder(),
                                  errorWidget: (_, _, _) => _buildImagePlaceholder(),
                                )
                              : _buildImagePlaceholder(),
                        ),
                      ),
                      // Featured badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFF59E0B),
                                const Color(0xFFF59E0B).withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _primaryLight,
                                    _primaryLight.withValues(alpha: 0.6),
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
                                  Icon(Icons.store_rounded, size: 12, color: _primary),
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
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ...List.generate(5, (s) {
                                  final rating = double.tryParse(product.rating ?? '0') ?? 0;
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
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: isHovered
                                        ? LinearGradient(
                                            colors: [
                                              _primary,
                                              _primary.withValues(alpha: 0.85),
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
                                              color: _primary.withValues(alpha: 0.3),
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
    );
  }

  Widget _buildToolbar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heading with gradient effect
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  _dark,
                  _primary,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds),
              child: Text(
                _selectedCategory == 'All' ? "Today's Harvest" : _selectedCategory,
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
                  '${_filteredProducts.length} fresh items available',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            // Grid/List toggle with premium style
            Container(
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primaryLight,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(Icons.grid_view_rounded, size: 17, color: _primary),
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.view_list_rounded, size: 17, color: _mutedLight),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Sort dropdown with premium styling
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
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
                      items: ['Newest', 'Price: Low to High', 'Price: High to Low', 'Popular']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _sortBy = val);
                      },
                    ),
                  ),
                  Icon(Icons.unfold_more, size: 16, color: _muted),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // PRODUCT GRID (enhanced with animations)
  // ─────────────────────────────────────────────
  Widget _buildProductGrid() {
    final products = _paginatedProducts;
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
            childAspectRatio: 0.68,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
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

  Widget _buildAnimatedProductCard(ProductItem product, AnimationController controller) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
        ),
        child: _buildProductCard(product),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        transform: Matrix4.translationValues(0, isHovered ? -8 : 0, 0),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isHovered ? _border.withValues(alpha: 0.8) : _border,
            width: isHovered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: isHovered ? 0.12 : 0),
              blurRadius: isHovered ? 32 : 0,
              offset: const Offset(0, 0),
              spreadRadius: isHovered ? 4 : 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isHovered ? 0.08 : 0.03),
              blurRadius: isHovered ? 20 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with overlay
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      color: _surface,
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      child: Stack(
                        children: [
                          product.imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: product.imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => _buildImagePlaceholder(),
                                  errorWidget: (_, _, _) => _buildImagePlaceholder(),
                                )
                              : _buildImagePlaceholder(),
                          // Overlay on hover - inspired by home screen
                          if (isHovered)
                            AnimatedOpacity(
                              opacity: isHovered ? 0.1 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                color: _primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Badge with premium styling
                  Positioned(
                    top: 12,
                    left: 12,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: (badge['color'] as Color).withValues(alpha: isHovered ? 1 : 0.95),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: (badge['color'] as Color).withValues(alpha: isHovered ? 0.4 : 0.25),
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
                  // Favorite button with glass effect
                  Positioned(
                    top: 12,
                    right: 12,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _white.withValues(alpha: isHovered ? 0.95 : 0.85),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: _border.withValues(alpha: isHovered ? 0.4 : 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isHovered ? 0.1 : 0.04),
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
            // Details section with better spacing
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
                        // Farm badge - glassmorphism style
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _primaryLight,
                                _primaryLight.withValues(alpha: 0.6),
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
                              Icon(Icons.store_rounded, size: 12, color: _primary),
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
                        if (product.rating != null) ...[
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              ...List.generate(5, (s) {
                                final rating = double.tryParse(product.rating!) ?? 0;
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
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
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 11),
                        // Premium gradient button
                        SizedBox(
                          width: double.infinity,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                gradient: isHovered
                                    ? LinearGradient(
                                        colors: [
                                          _primary,
                                          _primary.withValues(alpha: 0.85),
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
                                          color: _primary.withValues(alpha: 0.3),
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
                      border: Border.all(
                        color: isActive ? _primary : _border,
                      ),
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    color: Colors.grey[100],
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_primary.withValues(alpha: 0.3)),
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
              child: const Icon(Icons.search_off_rounded, size: 40, color: _primary),
            ),
            const SizedBox(height: 24),
            Text(
              'No products found',
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                          child: const Icon(Icons.eco_rounded, color: Colors.white, size: 16),
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
                    Text('Support', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _white)),
                    const SizedBox(height: 12),
                    ...[
                      'Help Center',
                      'Delivery Info',
                      'Returns',
                      'Contact Us',
                    ].map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(t, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9CA3AF))),
                        )),
                  ],
                ),
              ),
              // Newsletter
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stay Updated', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _white)),
                    const SizedBox(height: 8),
                    Text(
                      'Subscribe for weekly harvest updates.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9CA3AF)),
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
                              border: Border.all(color: const Color(0xFF374151)),
                            ),
                            child: TextField(
                              style: GoogleFonts.inter(fontSize: 12, color: _white),
                              decoration: InputDecoration(
                                hintText: 'Email',
                                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 9),
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
                          child: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
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
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
