import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/services/supabase_data_service.dart';

/// Web Shop Screen — Full product browsing experience
/// Categories sidebar, filters, product grid with search
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

class _WebShopScreenState extends State<WebShopScreen> with TickerProviderStateMixin {
  // ─── Colors ───
  static const Color _primary = Color(0xFF10B981);
  static const Color _accent = Color(0xFF00D45F);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFFAFAFA);
  static const Color _white = Color(0xFFFFFFFF);

  // ─── Animations ───
  late AnimationController _fadeInController;
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
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _loadProducts();
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    for (final controller in _productControllers) {
      controller.dispose();
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
      // Create staggered controllers for products
      _productControllers = List.generate(
        _filteredProducts.length,
        (i) => AnimationController(
          duration: const Duration(milliseconds: 500),
          vsync: this,
        ),
      );
      // Stagger the animations
      for (int i = 0; i < _productControllers.length; i++) {
        Future.delayed(Duration(milliseconds: 100 * i), () {
          if (mounted) {
            _productControllers[i].forward();
          }
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
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
    });
    for (final controller in _productControllers) {
      controller.dispose();
    }
    _productControllers = List.generate(
      _filteredProducts.length,
      (i) => AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      ),
    );
    for (int i = 0; i < _productControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 100 * i), () {
        if (mounted) {
          _productControllers[i].forward();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Left Sidebar: Categories & Filters ───
                Container(
                  width: 260,
                  decoration: BoxDecoration(
                    color: _white,
                    border: Border(right: BorderSide(color: _border)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCategorySidebar(),
                        const SizedBox(height: 32),
                        _buildPriceFilter(),
                        const SizedBox(height: 32),
                        _buildRatingFilter(),
                      ],
                    ),
                  ),
                ),
                // ─── Main Content: Products Grid ───
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildToolbar(),
                        const SizedBox(height: 24),
                        _isLoading
                            ? _buildLoadingGrid()
                            : _filteredProducts.isEmpty
                                ? _buildEmptyState()
                                : _buildProductGrid(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
      color: _white,
      child: Row(
        children: [
          // Logo
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(0),
              child: Row(
                children: [
                  Image.asset(
                    'assets/icon/logo.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AGRIDIRECT',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 48),
          // Navigation
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderNavItem('Home', onTap: () => widget.onNavigate(0)),
              const SizedBox(width: 32),
              _buildHeaderNavItem('Shop', isActive: true, onTap: () => widget.onNavigate(1)),
              const SizedBox(width: 32),
              _buildHeaderNavItem('Community', onTap: () => widget.onNavigate(2)),
              const SizedBox(width: 32),
              _buildHeaderNavItem('About Us', onTap: () {}),
            ],
          ),
          const Spacer(),
          // Search bar
          Container(
            width: 280,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: _muted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      _searchQuery = value;
                      _filterProducts();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: TextStyle(color: _muted, fontSize: 13),
                      border: InputBorder.none,
                    ),
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Cart icon
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(Icons.shopping_bag_outlined, size: 20, color: _dark),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Profile icon
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(3),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: _border),
                ),
                child: Icon(Icons.person_outline_rounded, size: 20, color: _dark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderNavItem(String text, {bool isActive = false, required VoidCallback onTap}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? _primary : _dark,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 16,
              height: 2,
              decoration: BoxDecoration(
                color: isActive ? _primary : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CATEGORY SIDEBAR
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCategorySidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _dark,
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
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? _primary.withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? _primary.withValues(alpha: 0.3) : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getCategoryIcon(cat),
                        size: 18,
                        color: isSelected ? _primary : _muted,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        cat,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? _primary : _dark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'All':
        return Icons.grid_view_rounded;
      case 'Vegetables':
        return Icons.eco_rounded;
      case 'Fruits':
        return Icons.apple_rounded;
      case 'Grains':
        return Icons.grass_rounded;
      case 'Dairy':
        return Icons.water_drop_rounded;
      case 'Eggs':
        return Icons.egg_rounded;
      case 'Honey':
        return Icons.local_florist_rounded;
      case 'Meat':
        return Icons.restaurant_rounded;
      case 'Herbs':
        return Icons.spa_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // PRICE FILTER
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPriceFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price Range',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPriceChip('Under ₱50'),
            _buildPriceChip('₱50 - ₱100'),
            _buildPriceChip('₱100 - ₱500'),
            _buildPriceChip('₱500+'),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceChip(String label) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _dark,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // RATING FILTER
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildRatingFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rating',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(4, (index) {
          final stars = 5 - index;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                children: [
                  ...List.generate(
                    5,
                    (i) => Icon(
                      i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16,
                      color: i < stars ? const Color(0xFFF59E0B) : _border,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '& up',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TOOLBAR (results count + sort)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildToolbar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedCategory == 'All' ? 'All Products' : _selectedCategory,
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_filteredProducts.length} product${_filteredProducts.length == 1 ? '' : 's'} found',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _muted,
              ),
            ),
          ],
        ),
        Row(
          children: [
            // View toggle
            Container(
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(Icons.grid_view_rounded, size: 18, color: _primary),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.view_list_rounded, size: 18, color: _muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Sort dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sort: ',
                    style: GoogleFonts.inter(fontSize: 13, color: _muted),
                  ),
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
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PRODUCT GRID
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildProductGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.72,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: _filteredProducts.length,
          itemBuilder: (context, index) {
            return _productControllers.length > index
                ? _buildAnimatedProductCard(
                    index,
                    _filteredProducts[index],
                    _productControllers[index],
                  )
                : _buildProductCard(_filteredProducts[index]);
          },
        );
      },
    );
  }

  Widget _buildAnimatedProductCard(
      int index, ProductItem product, AnimationController controller) {
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

  Widget _buildProductCard(ProductItem product) {
    final isHovered = _hoveredProducts.contains(product.hashCode);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredProducts.add(product.hashCode)),
      onExit: (_) => setState(() => _hoveredProducts.remove(product.hashCode)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHovered ? _primary : _border,
            width: isHovered ? 2 : 1,
          ),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      color: Colors.grey[100],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
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
                  // Favorite button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.favorite_border_rounded, size: 16, color: _dark),
                      ),
                    ),
                  ),
                  // Organic badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.eco_rounded, size: 10, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Organic',
                            style: GoogleFonts.inter(
                              fontSize: 10,
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
            ),
            // Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.storefront_rounded, size: 12, color: _muted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                product.farm,
                                style: GoogleFonts.inter(fontSize: 11, color: _muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (product.rating != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 4),
                              Text(
                                product.rating!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _dark,
                                ),
                              ),
                              if (product.reviews != null) ...[
                                Text(
                                  ' (${product.reviews})',
                                  style: GoogleFonts.inter(fontSize: 11, color: _muted),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.price,
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _dark,
                              ),
                            ),
                            Text(
                              product.unit,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: _muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_rounded, size: 20, color: _dark),
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
        child: Icon(
          Icons.image_rounded,
          size: 48,
          color: Colors.grey[300],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // LOADING & EMPTY STATES
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildLoadingGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.72,
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
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(14),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded, size: 40, color: _primary),
            ),
            const SizedBox(height: 24),
            Text(
              'No products found',
              style: GoogleFonts.manrope(
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
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _muted,
              ),
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
}
