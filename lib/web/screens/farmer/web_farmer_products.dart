import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/commerce/product_service.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../widgets/animated_components.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../widgets/web_consumer_nav_bar.dart';
import '../../widgets/web_hamburger_menu_button.dart';

class WebFarmerProducts extends StatefulWidget {
  final Function(int) onNavigate;
  final int currentIndex;

  const WebFarmerProducts({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
  });

  @override
  State<WebFarmerProducts> createState() => _WebFarmerProductsState();
}

class _WebFarmerProductsState extends State<WebFarmerProducts>
    with TickerProviderStateMixin {
  late AnimationController _fadeInController;
  int _hoveredNav = -1;
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';
  String _selectedStockFilter = 'All';
  String _sortBy = 'Default';
  bool _isGridView = true;

  final TextEditingController _searchController = TextEditingController();
  Future<List<Map<String, dynamic>>>? _productsFuture;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _primaryDark = Color(0xFF15803D);
  static const Color _primaryLight = Color(0xFFDCFCE7);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _productsFuture = SupabaseDataService().getFarmerProducts();
  }

  void _refreshProducts() {
    setState(() {
      _productsFuture = SupabaseDataService().getFarmerProducts();
    });
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openProduct(Map<String, dynamic> productMap) {
    _showEditProductDialog(productMap);
  }

  void _showEditProductDialog(Map<String, dynamic> product) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _EditProductDialog(
        product: product,
        onSaved: _refreshProducts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;

    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          // Subtle background pattern
          Positioned.fill(
            child: CustomPaint(
              painter: DotPatternPainter(
                opacity: 0.02,
                color: const Color(0xFF10B981),
              ),
            ),
          ),
          const Positioned.fill(
            child: FloatingParticles(
              count: 12,
              maxSize: 2.0,
              color: Color(0xFF10B981),
            ),
          ),
          Column(
            children: [
              _buildNavBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 40,
                    12,
                    isMobile ? 16 : 40,
                    48,
                  ),
                  child: FadeTransition(
                    opacity: _fadeInController,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 24),
                            _buildMainContent(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 900;
    final isCompact = sw < 1100;

    if (!AuthService().isViewingAsFarmer) {
      return WebConsumerNavBar(
        currentIndex: widget.currentIndex,
        onNavigate: widget.onNavigate,
        onCartTap: () => context.go(AppRoutes.cart),
        margin: isMobile
            ? const EdgeInsets.fromLTRB(16, 12, 16, 8)
            : const EdgeInsets.fromLTRB(32, 16, 32, 12),
      );
    }

    final navItems = [
      'Dashboard',
      'Products',
      'Orders',
      'Community',
      'Pre-Orders',
    ];
    return Container(
      margin: isMobile
          ? const EdgeInsets.fromLTRB(16, 12, 16, 8)
          : (isCompact
              ? const EdgeInsets.fromLTRB(20, 14, 20, 8)
              : const EdgeInsets.fromLTRB(32, 16, 32, 12)),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : (isCompact ? 16 : 28),
        vertical: isMobile ? 10 : (isCompact ? 10 : 12),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _dark.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(0),
              child: BrandLogo(
                size: (isMobile || isCompact)
                    ? BrandLogoSize.small
                    : BrandLogoSize.medium,
              ),
            ),
          ),
          if (!isMobile) ...[
            SizedBox(width: isCompact ? 16 : 40),
            ...List.generate(navItems.length, (i) {
              final isActive = i == widget.currentIndex;
              final isHovered = _hoveredNav == i;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 4),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hoveredNav = i),
                  onExit: (_) => setState(() => _hoveredNav = -1),
                  child: GestureDetector(
                    onTap: () => widget.onNavigate(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 12 : 18,
                        vertical: isCompact ? 8 : 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isActive
                            ? _primaryLight
                            : isHovered
                                ? const Color(0xFFF1F5F9)
                                : Colors.transparent,
                      ),
                      child: Text(
                        navItems[i],
                        style: GoogleFonts.inter(
                          fontSize: isCompact ? 13 : 14,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                          color: isActive ? _primaryDark : (isHovered ? _dark : _muted),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(5),
              child: Container(
                width: (isMobile || isCompact) ? 38 : 42,
                height: (isMobile || isCompact) ? 38 : 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: (isMobile || isCompact) ? 20 : 22,
                ),
              ),
            ),
          ),
          if (isMobile) ...[
            const SizedBox(width: 8),
            WebHamburgerMenuButton(
              currentIndex: widget.currentIndex,
              onNavigate: widget.onNavigate,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    'Inventory & Products',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isMobile ? 22 : 28,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Live Catalog',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Monitor stock levels, set prices, and publish fresh farm offerings.',
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 13 : 14,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
        if (!isMobile)
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.addProduct),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(
              'Add New Product',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              shadowColor: _primary.withValues(alpha: 0.4),
            ),
          ),
      ],
    );
  }

  Widget _buildKpiMetricsSummary(List<Map<String, dynamic>> allProducts) {
    int totalProducts = allProducts.length;
    double totalValuation = 0;
    int lowStockCount = 0;
    int preorderCount = 0;

    for (final p in allProducts) {
      final price = double.tryParse(p['price']?.toString() ?? '0') ?? 0;
      final qty = double.tryParse(
            (p['available_quantity'] ?? p['available'] ?? 0).toString(),
          ) ??
          0;
      totalValuation += (price * qty);

      if (qty <= 10) lowStockCount++;
      if (p['is_preorder'] == true) preorderCount++;
    }

    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    Widget buildKpiCard({
      required String title,
      required String value,
      required String badgeText,
      required IconData icon,
      required Color color,
      required Color bgColor,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badgeText,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
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

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              buildKpiCard(
                title: 'Total Items',
                value: '$totalProducts',
                badgeText: 'Active Listings',
                icon: Icons.inventory_2_rounded,
                color: _primary,
                bgColor: _primaryLight,
              ),
              const SizedBox(width: 12),
              buildKpiCard(
                title: 'Total Value',
                value: '₱${totalValuation.toStringAsFixed(0)}',
                badgeText: 'Estimated Revenue',
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF2563EB),
                bgColor: const Color(0xFFDBEAFE),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              buildKpiCard(
                title: 'Low Stock',
                value: '$lowStockCount items',
                badgeText: lowStockCount > 0 ? 'Needs Restock' : 'Healthy Stock',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFEF3C7),
              ),
              const SizedBox(width: 12),
              buildKpiCard(
                title: 'Pre-Orders',
                value: '$preorderCount items',
                badgeText: 'Upcoming Harvest',
                icon: Icons.eco_rounded,
                color: const Color(0xFF9333EA),
                bgColor: const Color(0xFFF3E8FF),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        buildKpiCard(
          title: 'Total Products',
          value: '$totalProducts',
          badgeText: 'Active Listings',
          icon: Icons.inventory_2_rounded,
          color: _primary,
          bgColor: _primaryLight,
        ),
        const SizedBox(width: 16),
        buildKpiCard(
          title: 'Stock Valuation',
          value: '₱${totalValuation.toStringAsFixed(2)}',
          badgeText: 'Estimated Revenue',
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFF2563EB),
          bgColor: const Color(0xFFDBEAFE),
        ),
        const SizedBox(width: 16),
        buildKpiCard(
          title: 'Low Stock Alerts',
          value: '$lowStockCount items',
          badgeText: lowStockCount > 0 ? 'Needs Restock' : 'Healthy Inventory',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFFEF3C7),
        ),
        const SizedBox(width: 16),
        buildKpiCard(
          title: 'Active Pre-Orders',
          value: '$preorderCount items',
          badgeText: 'Upcoming Harvest',
          icon: Icons.eco_rounded,
          color: const Color(0xFF9333EA),
          bgColor: const Color(0xFFF3E8FF),
        ),
      ],
    );
  }

  Widget _buildControlToolbar() {
    final categories = ['All', 'Vegetables', 'Fruits', 'Grains', 'Poultry', 'Pre-Orders'];
    final stockOptions = ['All', 'In Stock', 'Low Stock', 'Out of Stock'];
    final sortOptions = ['Default', 'Name', 'Price: Low to High', 'Price: High to Low', 'Stock Level'];
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Primary Actions row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.inter(fontSize: 14, color: _dark),
                    decoration: InputDecoration(
                      hintText: 'Search products by name...',
                      hintStyle: GoogleFonts.inter(color: _muted, fontSize: 14),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _muted,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: _muted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),
              if (isMobile) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => context.push(AppRoutes.addProduct),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              // View Switcher (Grid vs Table)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _isGridView = true),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isGridView ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: _isGridView
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          Icons.grid_view_rounded,
                          size: 18,
                          color: _isGridView ? _primary : _muted,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _isGridView = false),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: !_isGridView ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: !_isGridView
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          Icons.format_list_bulleted_rounded,
                          size: 18,
                          color: !_isGridView ? _primary : _muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Filters and Sorting Row
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Category filter pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) {
                    final isSelected = _selectedCategoryFilter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          cat,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : _dark,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: _primary,
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (val) {
                          if (val) setState(() => _selectedCategoryFilter = cat);
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Dropdowns: Stock Filter & Sort By
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  // Stock filter
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStockFilter,
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: _muted),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _dark,
                        ),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedStockFilter = val);
                        },
                        items: stockOptions.map((opt) {
                          return DropdownMenuItem(value: opt, child: Text('Stock: $opt'));
                        }).toList(),
                      ),
                    ),
                  ),

                  // Sort dropdown
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        icon: const Icon(Icons.sort_rounded, size: 16, color: _muted),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _dark,
                        ),
                        onChanged: (val) {
                          if (val != null) setState(() => _sortBy = val);
                        },
                        items: sortOptions.map((opt) {
                          return DropdownMenuItem(value: opt, child: Text('Sort: $opt'));
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const GridShimmer();
        }

        final allProducts = snapshot.data ?? [];

        var filteredProducts = allProducts.where((p) {
          final name = p['name']?.toString().toLowerCase() ?? '';
          final matchesSearch = name.contains(_searchQuery.toLowerCase());

          bool matchesCategory = true;
          if (_selectedCategoryFilter == 'Pre-Orders') {
            matchesCategory = p['is_preorder'] == true;
          } else if (_selectedCategoryFilter != 'All') {
            final catName =
                p['category_name']?.toString() ?? p['category']?.toString() ?? '';
            matchesCategory = catName
                .toLowerCase()
                .contains(_selectedCategoryFilter.toLowerCase());
          }

          bool matchesStock = true;
          final qty = double.tryParse(
                (p['available_quantity'] ?? p['available'] ?? 0).toString(),
              ) ??
              0;
          if (_selectedStockFilter == 'In Stock') {
            matchesStock = qty > 10;
          } else if (_selectedStockFilter == 'Low Stock') {
            matchesStock = qty > 0 && qty <= 10;
          } else if (_selectedStockFilter == 'Out of Stock') {
            matchesStock = qty == 0;
          }

          return matchesSearch && matchesCategory && matchesStock;
        }).toList();

        // Sort items
        if (_sortBy == 'Name') {
          filteredProducts.sort(
            (a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()),
          );
        } else if (_sortBy == 'Price: Low to High') {
          filteredProducts.sort((a, b) {
            final pa = double.tryParse(a['price']?.toString() ?? '0') ?? 0;
            final pb = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
            return pa.compareTo(pb);
          });
        } else if (_sortBy == 'Price: High to Low') {
          filteredProducts.sort((a, b) {
            final pa = double.tryParse(a['price']?.toString() ?? '0') ?? 0;
            final pb = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
            return pb.compareTo(pa);
          });
        } else if (_sortBy == 'Stock Level') {
          filteredProducts.sort((a, b) {
            final qa = double.tryParse((a['available_quantity'] ?? 0).toString()) ?? 0;
            final qb = double.tryParse((b['available_quantity'] ?? 0).toString()) ?? 0;
            return qb.compareTo(qa);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildKpiMetricsSummary(allProducts),
            const SizedBox(height: 20),
            _buildControlToolbar(),
            const SizedBox(height: 20),
            if (filteredProducts.isEmpty)
              _buildEmptyState()
            else if (_isGridView)
              _buildProductGridView(filteredProducts)
            else
              _buildProductTableView(filteredProducts),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: _primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: _primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No matching products found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try clearing your search query or selecting a different stock filter.',
            style: GoogleFonts.inter(fontSize: 14, color: _muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedCategoryFilter = 'All';
                _selectedStockFilter = 'All';
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'Reset Filters',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: const BorderSide(color: _primary),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGridView(List<Map<String, dynamic>> products) {
    final sw = MediaQuery.of(context).size.width;
    int crossAxisCount = 4;
    double childAspectRatio = 1.35;
    if (sw < 600) {
      crossAxisCount = 1;
      childAspectRatio = 1.6;
    } else if (sw < 900) {
      crossAxisCount = 2;
      childAspectRatio = 1.35;
    } else if (sw < 1250) {
      crossAxisCount = 3;
      childAspectRatio = 1.30;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) => ScrollReveal(
        delay: Duration(milliseconds: index * 30),
        duration: const Duration(milliseconds: 400),
        child: _buildProductCard(products[index]),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['name'] ?? 'Product';
    final price = '₱${product['price'] ?? 0}';
    final stock = double.tryParse((product['available_quantity'] ?? 0).toString()) ?? 0;
    final imageUrl = product['image_url'] ?? product['image'];
    final unit = product['unit'] ?? 'kg';
    final isPreorder = product['is_preorder'] == true;

    Color statusColor;
    String statusLabel;
    if (isPreorder) {
      statusColor = const Color(0xFF9333EA);
      statusLabel = 'Pre-Order';
    } else if (stock > 10) {
      statusColor = _primary;
      statusLabel = 'In Stock';
    } else if (stock > 0) {
      statusColor = const Color(0xFFD97706);
      statusLabel = 'Low Stock';
    } else {
      statusColor = Colors.red;
      statusLabel = 'Out of Stock';
    }

    return GestureDetector(
      onTap: () => _openProduct(product),
      child: HoverScaleCard(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact Image Header Container
              SizedBox(
                height: 125,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: imageUrl != null && imageUrl.toString().isNotEmpty
                            ? SafeNetworkImage(
                                imageUrl: imageUrl.toString(),
                                defaultBucket: 'uploads',
                                fit: BoxFit.cover,
                                placeholder: Container(color: _surface),
                                errorWidget: Container(
                                  color: _surface,
                                  child: const Icon(
                                    Icons.broken_image_rounded,
                                    color: _muted,
                                  ),
                                ),
                              )
                            : Container(
                                color: const Color(0xFFF1F5F9),
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: _muted,
                                  size: 28,
                                ),
                              ),
                      ),
                    ),

                    // Status pill overlay
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
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

              // Compact Content Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'Stock: ',
                                style: GoogleFonts.inter(fontSize: 11, color: _muted),
                              ),
                              Text(
                                '${stock.toStringAsFixed(stock % 1 == 0 ? 0 : 1)} $unit',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _dark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            price,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _primary,
                            ),
                          ),
                          InkWell(
                            onTap: () => _openProduct(product),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.edit_outlined,
                                    size: 13,
                                    color: _dark,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Edit',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _dark,
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

  Widget _buildProductTableView(List<Map<String, dynamic>> products) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 900),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              dataRowMaxHeight: 68,
              horizontalMargin: 20,
              columnSpacing: 24,
              columns: [
                DataColumn(
                  label: Text(
                    'Product',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: _dark,
                      fontSize: 13,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Stock Available',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: _dark,
                      fontSize: 13,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Unit Price',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: _dark,
                      fontSize: 13,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Status',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: _dark,
                      fontSize: 13,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Action',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: _dark,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              rows: products.map((product) {
                final name = product['name'] ?? 'Product';
                final price = '₱${product['price'] ?? 0}';
                final stock = double.tryParse(
                      (product['available_quantity'] ?? 0).toString(),
                    ) ??
                    0;
                final imageUrl = product['image_url'] ?? product['image'];
                final unit = product['unit'] ?? 'kg';
                final isPreorder = product['is_preorder'] == true;

                Color statusBg;
                Color statusFg;
                String statusLabel;
                if (isPreorder) {
                  statusBg = const Color(0xFFF3E8FF);
                  statusFg = const Color(0xFF9333EA);
                  statusLabel = 'Pre-Order';
                } else if (stock > 10) {
                  statusBg = _primaryLight;
                  statusFg = _primaryDark;
                  statusLabel = 'In Stock';
                } else if (stock > 0) {
                  statusBg = const Color(0xFFFEF3C7);
                  statusFg = const Color(0xFFD97706);
                  statusLabel = 'Low Stock';
                } else {
                  statusBg = const Color(0xFFFEE2E2);
                  statusFg = Colors.red;
                  statusLabel = 'Out of Stock';
                }

                return DataRow(
                  onSelectChanged: (_) => _openProduct(product),
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: imageUrl != null && imageUrl.toString().isNotEmpty
                                  ? SafeNetworkImage(
                                      imageUrl: imageUrl.toString(),
                                      defaultBucket: 'uploads',
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: const Color(0xFFF1F5F9),
                                      child: const Icon(
                                        Icons.image_outlined,
                                        size: 20,
                                        color: _muted,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: _dark,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        '${stock.toStringAsFixed(stock % 1 == 0 ? 0 : 1)} $unit',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: _dark,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        price,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: _primary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusFg,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      OutlinedButton.icon(
                        onPressed: () => _openProduct(product),
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: Text(
                          'Manage',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _dark,
                          side: const BorderSide(color: _border),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class GridShimmer extends StatelessWidget {
  const GridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.05,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: 8,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
      ),
    );
  }
}

class _EditProductDialog extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onSaved;

  const _EditProductDialog({required this.product, required this.onSaved});

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _descriptionController;
  late TextEditingController _harvestDaysController;
  bool _isPreorder = false;
  bool _isFreeShipping = false;
  bool _isWholesale = false;
  bool _isFlashSale = false;
  bool _isLoading = false;
  bool _isLoadingDropdowns = true;

  String? _selectedCategory;
  String? _selectedUnit;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _units = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.product['name']?.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: widget.product['price']?.toString() ?? '0',
    );
    _stockController = TextEditingController(
      text:
          (widget.product['available_quantity'] ??
                  widget.product['available'] ??
                  0)
              .toString()
              .replaceAll(RegExp(r'\.0$'), ''),
    );
    _descriptionController = TextEditingController(
      text: widget.product['description']?.toString() ?? '',
    );

    final harvestVal = widget.product['harvest']?.toString() ?? '';
    _harvestDaysController = TextEditingController(
      text: harvestVal.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    _isPreorder = widget.product['is_preorder'] == true;
    _isFreeShipping = widget.product['is_free_shipping'] == true;
    _isWholesale = widget.product['is_wholesale'] == true;
    _isFlashSale = widget.product['is_flash_sale'] == true;
    _loadProductDetailsAndDropdowns();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _harvestDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadProductDetailsAndDropdowns() async {
    try {
      final client = Supabase.instance.client;
      final productData = await client
          .from('products')
          .select('category_id, unit_id, harvest_days, is_preorder, is_free_shipping, is_wholesale, is_flash_sale')
          .eq('product_id', widget.product['id'])
          .single();

      final service = ProductService();
      final cats = await service.getCategories();
      final unts = await service.getUnits();

      if (mounted) {
        setState(() {
          _selectedCategory = productData['category_id']?.toString();
          _selectedUnit = productData['unit_id']?.toString();
          _isPreorder = productData['is_preorder'] ?? false;
          _isFreeShipping = productData['is_free_shipping'] ?? false;
          _isWholesale = productData['is_wholesale'] ?? false;
          _isFlashSale = productData['is_flash_sale'] ?? false;
          if (productData['harvest_days'] != null) {
            _harvestDaysController.text = productData['harvest_days']
                .toString();
          }

          _categories = cats
              .map<Map<String, dynamic>>((c) => {'id': c.categoryId, 'name': c.name})
              .toList();
          _units = unts.map<Map<String, dynamic>>((u) => {'id': u.unitId, 'name': u.name}).toList();
          _isLoadingDropdowns = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading categories/units: $e');
      if (mounted) {
        setState(() => _isLoadingDropdowns = false);
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final description = _descriptionController.text.trim();
      final harvestDays = int.tryParse(_harvestDaysController.text.trim()) ?? 0;
      final stock = double.tryParse(_stockController.text.trim()) ?? 0.0;

      final client = Supabase.instance.client;

      // Update basic product details
      await client
          .from('products')
          .update({
            'name': name,
            'price': price,
            'description': description,
            'harvest_days': harvestDays,
            'is_preorder': _isPreorder,
            'is_free_shipping': _isFreeShipping,
            'is_wholesale': _isWholesale,
            'is_flash_sale': _isFlashSale,
            if (_selectedCategory != null) 'category_id': _selectedCategory,
            if (_selectedUnit != null) 'unit_id': _selectedUnit,
          })
          .eq('product_id', widget.product['id']);

      await client.from('product_inventory').upsert({
        'product_id': widget.product['id'],
        'available_quantity': stock,
      }, onConflict: 'product_id');

      widget.onSaved();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product updated successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Product?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${widget.product['name']}"? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final success = await SupabaseDataService().deleteProduct(
        widget.product['id'],
      );
      if (success) {
        widget.onSaved();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product deleted successfully!'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
        }
      } else {
        throw 'Database deletion failed';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Product',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          'Edit listing details and inventory status',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F4F6),
                      iconSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Content Form
            Expanded(
              child: _isLoadingDropdowns
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF16A34A),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Name
                            _buildFieldLabel('Product Name'),
                            TextFormField(
                              controller: _nameController,
                              style: GoogleFonts.inter(fontSize: 14),
                              decoration: _buildInputDecoration(
                                'e.g. Organic Tomatoes',
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                  ? 'Product name is required'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // Row: Category & Unit
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('Category'),
                                      DropdownButtonFormField<String>(
                                        initialValue: _selectedCategory,
                                        items: _categories
                                            .map(
                                              (c) => DropdownMenuItem<String>(
                                                value: c['id'],
                                                child: Text(
                                                  c['name'],
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) => setState(
                                          () => _selectedCategory = val,
                                        ),
                                        decoration: _buildInputDecoration(
                                          'Select Category',
                                        ),
                                        validator: (val) =>
                                            val == null ? 'Required' : null,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('Unit'),
                                      DropdownButtonFormField<String>(
                                        initialValue: _selectedUnit,
                                        items: _units
                                            .map(
                                              (u) => DropdownMenuItem<String>(
                                                value: u['id'],
                                                child: Text(
                                                  u['name'],
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) =>
                                            setState(() => _selectedUnit = val),
                                        decoration: _buildInputDecoration(
                                          'Select Unit',
                                        ),
                                        validator: (val) =>
                                            val == null ? 'Required' : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Row: Price & Stock
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('Price (₱)'),
                                      TextFormField(
                                        controller: _priceController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        style: GoogleFonts.inter(fontSize: 14),
                                        decoration: _buildInputDecoration(
                                          '0.00',
                                        ),
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) {
                                            return 'Required';
                                          }
                                          if (double.tryParse(val) == null) {
                                            return 'Invalid price';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('Stock Quantity'),
                                      TextFormField(
                                        controller: _stockController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        style: GoogleFonts.inter(fontSize: 14),
                                        decoration: _buildInputDecoration('0'),
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) {
                                            return 'Required';
                                          }
                                          if (double.tryParse(val) == null) {
                                            return 'Invalid stock';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Preorder details
                            Row(
                              children: [
                                Checkbox(
                                  value: _isPreorder,
                                  activeColor: const Color(0xFF16A34A),
                                  onChanged: (val) => setState(
                                    () => _isPreorder = val ?? false,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'This is a pre-order product',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                            if (_isPreorder) ...[
                              const SizedBox(height: 12),
                              _buildFieldLabel('Days to Harvest'),
                              TextFormField(
                                controller: _harvestDaysController,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.inter(fontSize: 14),
                                decoration: _buildInputDecoration('e.g. 30'),
                                validator: (val) {
                                  if (_isPreorder &&
                                      (val == null || val.trim().isEmpty)) {
                                    return 'Harvest days required for pre-orders';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            _buildFieldLabel('Promotions & Offers'),
                            Text(
                              'Boost your sales by opting into marketplace promotions.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Checkbox(
                                  value: _isFreeShipping,
                                  activeColor: const Color(0xFF16A34A),
                                  onChanged: (val) => setState(() => _isFreeShipping = val ?? false),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Free Shipping (Cover delivery costs)',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Checkbox(
                                  value: _isWholesale,
                                  activeColor: const Color(0xFF16A34A),
                                  onChanged: (val) => setState(() => _isWholesale = val ?? false),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Wholesale Pricing (Offer bulk discounts)',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Checkbox(
                                  value: _isFlashSale,
                                  activeColor: const Color(0xFF16A34A),
                                  onChanged: (val) => setState(() => _isFlashSale = val ?? false),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Flash Sale (Join next flash sale)',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Description
                            _buildFieldLabel('Description'),
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 4,
                              style: GoogleFonts.inter(fontSize: 14),
                              decoration: _buildInputDecoration(
                                'Product description...',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const Divider(height: 1),

            // Actions
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _deleteProduct,
                    icon: const Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.red,
                      size: 18,
                    ),
                    label: Text(
                      'Delete',
                      style: GoogleFonts.inter(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isLoading ? null : _saveProduct,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Save Changes',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
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

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF374151),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
      ),
    );
  }
}
