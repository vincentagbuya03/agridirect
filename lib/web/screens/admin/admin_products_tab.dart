import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/admin/admin_service.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/widgets/image_widgets.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'admin_ui.dart';

class AdminProductsTab extends StatefulWidget {
  final AdminService adminService;
  const AdminProductsTab({super.key, required this.adminService});

  @override
  State<AdminProductsTab> createState() => _AdminProductsTabState();
}

class _AdminProductsTabState extends State<AdminProductsTab> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  late Future<Map<String, dynamic>> _metricsFuture;

  String _searchQuery = '';
  String _selectedTab = 'all'; // all, instant, preorder, featured, low_stock
  String _selectedCategory = 'All Categories';
  String _sortBy = 'newest'; // newest, price_asc, price_desc, stock_asc, rating
  int _currentPage = 1;
  static const int _rowsPerPage = 10;

  final TextEditingController _searchController = TextEditingController();
  late VoidCallback _dataRefreshListener;

  @override
  void initState() {
    super.initState();
    _dataRefreshListener = () {
      if (!mounted) return;
      _loadData();
    };
    widget.adminService.dataVersionListenable.addListener(_dataRefreshListener);
    _loadData();
  }

  @override
  void dispose() {
    widget.adminService.dataVersionListenable.removeListener(_dataRefreshListener);
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _productsFuture = widget.adminService.getAllProducts();
      _metricsFuture = widget.adminService.getProductMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: SingleChildScrollView(
        padding: AdminUi.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Hero Header & Metric Cards ──
            _buildHeroAndMetrics(),
            const SizedBox(height: 24),

            // ── 2. Segmented Mode Switcher (All / Instant / Pre-Order / Featured / Restock) ──
            _buildSegmentedFilterTabs(),
            const SizedBox(height: 16),

            // ── 3. Main Data Table with Toolbar ──
            _buildMainTableContainer(),
            const SizedBox(height: 32),

            // ── 4. Bottom Supply & Harvest Intelligence ──
            _buildBottomInsights(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. HERO HEADER & 2x2 METRIC CARDS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeroAndMetrics() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _metricsFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final total = data['total'] ?? 0;
        final preorder = data['preorder'] ?? 0;
        final active = data['active'] ?? 0;
        final outOfStock = data['out_of_stock'] ?? 0;
        final instant = (total - preorder).clamp(0, total);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminDashboardHeader(
              title: 'Product & Pre-Order Catalog',
              subtitle: 'Oversee inventory, live harvest campaigns, and marketplace produce quotas.',
              actions: [
                OutlinedButton.icon(
                  onPressed: _exportProductsCSV,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminUi.brand,
                    side: const BorderSide(color: Color(0xFFD3DFD7)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: Text('Export CSV', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminUi.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: Text('Sync Catalog', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isMobile = width < 640;
                final isTablet = width >= 640 && width < 1100;
                final double metricWidth;
                if (isMobile) {
                  metricWidth = (width - 12) / 2;
                } else if (isTablet) {
                  metricWidth = (width - 16) / 2;
                } else {
                  metricWidth = (width - 48) / 4;
                }

                return Wrap(
                  spacing: isMobile ? 12 : 16,
                  runSpacing: isMobile ? 12 : 16,
                  children: [
                    SizedBox(
                      width: metricWidth,
                      child: _metricCard(
                        'TOTAL PRODUCTS',
                        '$total',
                        Icons.inventory_2_rounded,
                        '$active Active',
                        AdminUi.brand,
                        onTap: () => setState(() => _selectedTab = 'all'),
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      child: _metricCard(
                        'PRE-ORDER HARVESTS',
                        '$preorder',
                        Icons.eco_rounded,
                        preorder > 0 ? 'Live Campaigns' : 'None',
                        AdminUi.brandSecondary,
                        onTap: () => setState(() => _selectedTab = 'preorder'),
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      child: _metricCard(
                        'INSTANT DISPATCH',
                        '$instant',
                        Icons.bolt_rounded,
                        'Ready to Ship',
                        AdminUi.info,
                        onTap: () => setState(() => _selectedTab = 'instant'),
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      child: _metricCard(
                        'RESTOCK QUEUE',
                        '$outOfStock',
                        Icons.warning_amber_rounded,
                        outOfStock > 0 ? 'Needs Attention' : 'Optimal',
                        outOfStock > 0 ? AdminUi.danger : AdminUi.success,
                        onTap: () => setState(() => _selectedTab = 'low_stock'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _metricCard(
    String label,
    String value,
    IconData icon,
    String badgeText,
    Color color, {
    VoidCallback? onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 240;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(isCompact ? 14 : 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E9E4), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: isCompact ? 32 : 36,
                        height: isCompact ? 32 : 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: isCompact ? 18 : 20, color: color),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isCompact ? 9 : 10,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 10 : 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isCompact ? 9 : 10,
                          fontWeight: FontWeight.w800,
                          color: AdminUi.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isCompact ? 19 : 24,
                          fontWeight: FontWeight.w800,
                          color: AdminUi.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. HORIZONTALLY SCROLLABLE SEGMENTED FILTER TABS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSegmentedFilterTabs() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        final products = snapshot.data ?? [];
        final totalCount = products.length;
        final instantCount = products.where((p) => p['is_preorder'] != true).length;
        final preorderCount = products.where((p) => p['is_preorder'] == true).length;
        final featuredCount = products.where((p) => p['is_featured'] == true).length;
        final restockCount = products.where((p) => (p['stock_quantity'] ?? 0) <= 0).length;

        final tabs = [
          {'id': 'all', 'label': 'All Products', 'count': totalCount, 'icon': Icons.grid_view_rounded},
          {'id': 'instant', 'label': '⚡ Instant Inventory', 'count': instantCount, 'icon': Icons.bolt_rounded},
          {'id': 'preorder', 'label': '🌱 Pre-Order Campaigns', 'count': preorderCount, 'icon': Icons.eco_rounded},
          {'id': 'featured', 'label': '⭐ Featured Items', 'count': featuredCount, 'icon': Icons.star_rounded},
          {'id': 'low_stock', 'label': '⚠️ Restock Queue', 'count': restockCount, 'icon': Icons.warning_amber_rounded},
        ];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: tabs.map((t) {
              final isSelected = _selectedTab == t['id'];
              final count = t['count'] as int;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() {
                    _selectedTab = t['id'] as String;
                    _currentPage = 1;
                  }),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected ? AdminUi.brand : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AdminUi.brand : const Color(0xFFE2E9E4),
                      ),
                      boxShadow: isSelected
                          ? const [BoxShadow(color: Color(0x1A1B5E20), blurRadius: 8, offset: Offset(0, 2))]
                          : const [BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          t['icon'] as IconData,
                          size: 15,
                          color: isSelected ? Colors.white : AdminUi.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          t['label'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Colors.white : AdminUi.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : const Color(0xFFF0F4F1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : AdminUi.brandDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. MAIN TABLE CONTAINER WITH ADAPTIVE TOOLBAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMainTableContainer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < 980 ? 980.0 : constraints.maxWidth;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E9E4), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAdaptiveToolbar(),
              const Divider(height: 1, color: Color(0xFFE6EDE8)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      _buildTableHeader(),
                      const Divider(height: 1, color: Color(0xFFE6EDE8)),
                      _buildTableBody(),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE6EDE8)),
              _buildPaginationRow(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdaptiveToolbar() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        final products = snapshot.data ?? [];
        final categories = <String>{'All Categories'};
        for (final p in products) {
          final cat = (p['category_name'] ?? '').toString().trim();
          if (cat.isNotEmpty) categories.add(cat);
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search input
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360, minWidth: 240),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search title, farm, category...',
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: AdminUi.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, color: AdminUi.textMuted, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF7FAF8),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E9E4)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E9E4)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AdminUi.brand, width: 1.5),
                    ),
                  ),
                  onChanged: (v) => setState(() {
                    _searchQuery = v.trim().toLowerCase();
                    _currentPage = 1;
                  }),
                ),
              ),

              // Filter Dropdowns
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Category Filter Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAF8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E9E4)),
                    ),
                    child: DropdownButton<String>(
                      value: categories.contains(_selectedCategory) ? _selectedCategory : 'All Categories',
                      underline: const SizedBox(),
                      icon: const Icon(Icons.tune_rounded, size: 16, color: AdminUi.textSecondary),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AdminUi.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      onChanged: (v) => setState(() {
                        _selectedCategory = v ?? 'All Categories';
                        _currentPage = 1;
                      }),
                      items: categories.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                    ),
                  ),

                  // Sort Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAF8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E9E4)),
                    ),
                    child: DropdownButton<String>(
                      value: _sortBy,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.sort_rounded, size: 16, color: AdminUi.textSecondary),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AdminUi.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      onChanged: (v) => setState(() => _sortBy = v ?? 'newest'),
                      items: const [
                        DropdownMenuItem(value: 'newest', child: Text('Sort: Newest First')),
                        DropdownMenuItem(value: 'price_asc', child: Text('Price: Low to High')),
                        DropdownMenuItem(value: 'price_desc', child: Text('Price: High to Low')),
                        DropdownMenuItem(value: 'stock_asc', child: Text('Stock Level')),
                        DropdownMenuItem(value: 'rating', child: Text('Highest Rated')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: const Color(0xFFF7FAF8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          _headerCell('PRODUCE & FARM ORIGIN', flex: 3),
          _headerCell('LISTING MODE', flex: 2),
          _headerCell('PRICE / UNIT', flex: 2),
          _headerCell('INVENTORY GAUGE', flex: 2),
          _headerCell('VISIBILITY', flex: 2),
          _headerCell('ACTIONS', flex: 2, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          color: AdminUi.textMuted,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTableBody() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(60),
            child: Center(child: AppShimmerLoader(color: AdminUi.brand)),
          );
        }

        var products = snapshot.data ?? [];
        products = _filterAndSortProducts(products);

        if (products.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(60),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: AdminUi.border),
                  const SizedBox(height: 14),
                  Text(
                    'No produce listings found matching the current criteria.',
                    style: AdminUi.body(color: AdminUi.textMuted),
                  ),
                ],
              ),
            ),
          );
        }

        final paginated = _getPaginatedProducts(products);

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: paginated.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEBEFEA)),
          itemBuilder: (context, index) => _buildProductRow(paginated[index]),
        );
      },
    );
  }

  Widget _buildProductRow(Map<String, dynamic> product) {
    final productId = product['product_id']?.toString() ?? '';
    final name = product['name'] ?? 'Unnamed Produce';
    final farmName = product['farm_name'] ?? 'Local Farm';
    final category = product['category_name'] ?? 'Fresh Produce';
    final price = (product['price'] as num? ?? 0.0).toDouble();
    final stock = (product['stock_quantity'] as num? ?? 0).toInt();
    final unit = product['unit_abbr']?.toString() ?? 'kg';
    final isPreorder = product['is_preorder'] == true;
    final isFeatured = product['is_featured'] == true;
    final isActive = product['is_active'] != false;
    final imageUrl = product['image_url']?.toString();

    // Stock gauge color
    final Color stockColor;
    final String stockLabel;
    if (stock <= 0) {
      stockColor = AdminUi.danger;
      stockLabel = isPreorder ? '0 Slots Available' : 'Out of Stock';
    } else if (stock < 10) {
      stockColor = AdminUi.warning;
      stockLabel = isPreorder ? '$stock Slots Left' : '$stock $unit (Low)';
    } else {
      stockColor = AdminUi.success;
      stockLabel = isPreorder ? '$stock Pre-Order Slots' : '$stock $unit in Stock';
    }

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _showProductInspectorDialog(product),
        hoverColor: const Color(0xFFF7FAF8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              // 1. Produce & Farm Origin
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    SafeCircleAvatar(
                      radius: 22,
                      backgroundColor: AdminUi.brandSoft,
                      imageUrl: imageUrl,
                      defaultBucket: 'products',
                      child: Icon(
                        isPreorder ? Icons.eco_rounded : Icons.inventory_2_rounded,
                        color: AdminUi.brand,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: AdminUi.label(size: 13, color: AdminUi.textPrimary, weight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isFeatured) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$farmName • $category',
                            style: AdminUi.body(size: 11, color: AdminUi.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Listing Mode (Instant vs Pre-Order)
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPreorder
                          ? AdminUi.brandSecondary.withValues(alpha: 0.12)
                          : AdminUi.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isPreorder
                            ? AdminUi.brandSecondary.withValues(alpha: 0.3)
                            : AdminUi.info.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPreorder ? Icons.eco_rounded : Icons.bolt_rounded,
                          size: 12,
                          color: isPreorder ? AdminUi.brandDark : AdminUi.info,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPreorder ? 'PRE-ORDER' : 'INSTANT',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isPreorder ? AdminUi.brandDark : AdminUi.info,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Price / Unit
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '₱${price.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AdminUi.textPrimary,
                      ),
                    ),
                    Text(
                      'per $unit',
                      style: GoogleFonts.inter(fontSize: 10, color: AdminUi.textMuted),
                    ),
                  ],
                ),
              ),

              // 4. Inventory Gauge
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      stockLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: stockColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (stock / 100.0).clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: const Color(0xFFEAEFEA),
                        valueColor: AlwaysStoppedAnimation<Color>(stockColor),
                      ),
                    ),
                  ],
                ),
              ),

              // 5. Visibility / Status Switch
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: isActive,
                        activeThumbColor: AdminUi.brand,
                        activeTrackColor: AdminUi.brand.withValues(alpha: 0.3),
                        onChanged: (val) async {
                          final ok = await widget.adminService.toggleProductActiveStatus(productId, val);
                          if (!mounted || !context.mounted) return;
                          if (ok) {
                            _loadData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AdminUi.brand,
                                content: Text(val ? '✅ Product activated' : '⚠️ Product deactivated'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    Text(
                      isActive ? 'LIVE' : 'HIDDEN',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isActive ? AdminUi.success : AdminUi.danger,
                      ),
                    ),
                  ],
                ),
              ),

              // 6. Actions Menu
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        isFeatured ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isFeatured ? Colors.amber : AdminUi.textMuted,
                        size: 20,
                      ),
                      tooltip: isFeatured ? 'Unfeature Produce' : 'Feature on Marketplace',
                      onPressed: () async {
                        final ok = await widget.adminService.toggleFeaturedProduct(productId, !isFeatured);
                        if (!mounted || !context.mounted) return;
                        if (ok) {
                          _loadData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AdminUi.brand,
                              content: Text(isFeatured ? 'Product removed from featured' : '⭐ Product featured!'),
                            ),
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded, color: AdminUi.textSecondary, size: 20),
                      tooltip: 'View Full Product Details',
                      onPressed: () => _showProductInspectorDialog(product),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGINATION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPaginationRow() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        final products = _filterAndSortProducts(snapshot.data ?? []);
        final total = products.length;
        final totalPages = total <= 0 ? 1 : ((total - 1) ~/ _rowsPerPage) + 1;
        final safeCurrentPage = _currentPage.clamp(1, totalPages);
        final start = total == 0 ? 0 : ((safeCurrentPage - 1) * _rowsPerPage) + 1;
        final end = safeCurrentPage * _rowsPerPage > total ? total : safeCurrentPage * _rowsPerPage;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Showing $start to $end of $total produce items',
                style: AdminUi.body(size: 12, color: AdminUi.textMuted),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pageButton(
                    '<',
                    false,
                    enabled: safeCurrentPage > 1,
                    onTap: () => setState(() => _currentPage = safeCurrentPage - 1),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AdminUi.brandSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Page $safeCurrentPage of $totalPages',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminUi.brandDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _pageButton(
                    '>',
                    false,
                    enabled: safeCurrentPage < totalPages,
                    onTap: () => setState(() => _currentPage = safeCurrentPage + 1),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pageButton(String label, bool active, {VoidCallback? onTap, bool enabled = true}) {
    final canTap = enabled && onTap != null;
    return InkWell(
      onTap: canTap ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: active ? AdminUi.brand : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E9E4)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: active ? Colors.white : (canTap ? AdminUi.textPrimary : AdminUi.textMuted),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. BOTTOM SUPPLY & HARVEST INTELLIGENCE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBottomInsights() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < 860;

        final preOrderTimelineCard = Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF092B1D), Color(0xFF0E3D2A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF1E523A), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('🌱 Pre-Order Harvest Pipeline', style: AdminUi.title(size: 15, color: Colors.white)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AdminUi.brandSecondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ACTIVE HARVESTS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Monitor seasonal crops, reserved batch allocations, and estimated harvest delivery fulfillment.',
                style: AdminUi.body(size: 11, color: Colors.white.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => setState(() => _selectedTab = 'preorder'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF388E3C)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.visibility_rounded, size: 14),
                label: Text(
                  'INSPECT HARVEST CAMPAIGNS',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );

        final lowStockCard = Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E9E4), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('⚠️ Critical Stock Alerts', style: AdminUi.title(size: 15)),
                  InkWell(
                    onTap: () => setState(() => _selectedTab = 'low_stock'),
                    child: Text(
                      'VIEW ALL →',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AdminUi.brand,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Listings with low or zero remaining inventory quotas.',
                style: AdminUi.body(size: 11, color: AdminUi.textSecondary),
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  final lowStock = (snapshot.data ?? [])
                      .where((p) => (p['stock_quantity'] ?? 0) < 10)
                      .toList();

                  if (lowStock.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAF8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, color: AdminUi.success, size: 16),
                          const SizedBox(width: 8),
                          Text('All products have adequate stock quotas.', style: AdminUi.body(size: 12)),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: lowStock.take(2).map((p) {
                      final stock = p['stock_quantity'] ?? 0;
                      final unit = p['unit_abbr'] ?? "units";
                      final name = p['name'] ?? 'Product';
                      final color = stock == 0 ? AdminUi.danger : AdminUi.warning;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AdminUi.label(size: 12, color: AdminUi.textPrimary, weight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              stock == 0 ? 'Out of Stock' : '$stock $unit left',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );

        return isStacked
            ? Column(
                children: [
                  preOrderTimelineCard,
                  const SizedBox(height: 16),
                  lowStockCard,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: preOrderTimelineCard),
                  const SizedBox(width: 20),
                  Expanded(child: lowStockCard),
                ],
              );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRODUCT DETAILS & DEEP HARVEST INSPECTOR DIALOG
  // ═══════════════════════════════════════════════════════════════════════════
  void _showProductInspectorDialog(Map<String, dynamic> product) {
    final productId = product['product_id']?.toString() ?? '';
    final name = product['name'] ?? 'Unnamed Product';
    final farmName = product['farm_name'] ?? 'Local Farm';
    final category = product['category_name'] ?? 'Fresh Produce';
    final price = (product['price'] as num? ?? 0.0).toDouble();
    final stock = (product['stock_quantity'] as num? ?? 0).toInt();
    final unit = product['unit_abbr']?.toString() ?? 'kg';
    final unitName = product['unit_name']?.toString() ?? 'Kilogram';
    final isPreorder = product['is_preorder'] == true;
    final isFeatured = product['is_featured'] == true;
    final isActive = product['is_active'] != false;
    final isFreeShipping = product['is_free_shipping'] == true;
    final isWholesale = product['is_wholesale'] == true;
    final isFlashSale = product['is_flash_sale'] == true;
    final discountPercent = (product['discount_percent'] as num? ?? 0).toInt();
    final harvestDays = (product['harvest_days'] as num? ?? 30).toInt();
    final totalSold = (product['sold_count'] as num? ?? product['total_sold'] as num? ?? 0).toDouble();
    final grossVolume = totalSold * price;
    final description = (product['description'] ?? '').toString().trim().isEmpty
        ? 'Fresh from farm to table! Grown with sustainable and organic farming practices.'
        : product['description'].toString().trim();
    final rating = product['average_rating']?.toString() ?? '5.0';
    final reviews = product['review_count']?.toString() ?? '0';
    final imageUrl = product['image_url']?.toString();
    final createdAtStr = product['created_at'] != null
        ? DateFormat('MMMM d, yyyy').format(DateTime.parse(product['created_at']))
        : 'N/A';

    final shortSku = productId.length > 12
        ? '${productId.substring(0, 8)}...${productId.substring(productId.length - 4)}'
        : productId;

    DateTime? estHarvestDate;
    if (isPreorder && product['created_at'] != null) {
      final baseDate = DateTime.tryParse(product['created_at']) ?? DateTime.now();
      estHarvestDate = baseDate.add(Duration(days: harvestDays));
    }

    void navigateToStorefront() {
      Navigator.of(context).pop();
      final routePath = isPreorder ? AppRoutes.preorderDetails : AppRoutes.productDetails;
      final productItem = ProductItem(
        productId: productId,
        farmerId: product['farmer_id']?.toString(),
        farmerName: farmName,
        name: name,
        farm: farmName,
        price: price.toString(),
        unit: unit,
        imageUrl: imageUrl ?? '',
        categoryName: category,
        rating: rating,
        reviews: reviews,
        isFeatured: isFeatured,
        description: description,
      );
      context.push('$routePath?id=$productId', extra: productItem);
    }

    showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isMobile = screenWidth < 740;

        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Container(
            width: isMobile ? screenWidth * 0.96 : 840,
            constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── 1. Top Header Bar ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                    border: Border(bottom: BorderSide(color: Color(0xFFE6EDE8))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isPreorder
                                    ? AdminUi.brandSecondary.withValues(alpha: 0.15)
                                    : AdminUi.brandSoft,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isPreorder
                                      ? AdminUi.brandSecondary.withValues(alpha: 0.3)
                                      : AdminUi.brand.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPreorder ? Icons.eco_rounded : Icons.bolt_rounded,
                                    size: 13,
                                    color: isPreorder ? AdminUi.brandDark : AdminUi.brand,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isPreorder ? 'PRE-ORDER HARVEST CAMPAIGN' : 'INSTANT DISPATCH PRODUCE',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isPreorder ? AdminUi.brandDark : AdminUi.brand,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isFeatured)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      'FEATURED IN STORE',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (isFreeShipping)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  '🚚 FREE SHIPPING',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            if (isWholesale)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AdminUi.brand.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AdminUi.brand.withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  '🏷️ WHOLESALE AVAILABLE',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AdminUi.brandDark,
                                  ),
                                ),
                              ),
                            if (isFlashSale)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  '⚡ FLASH SALE ($discountPercent% OFF)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.deepOrange.shade900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: AdminUi.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close Modal',
                      ),
                    ],
                  ),
                ),

                // ── 2. Scrollable Body (2-Column on Desktop / 1-Column on Mobile) ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProductVisualCard(imageUrl, isPreorder, category),
                              const SizedBox(height: 16),
                              _buildTitleAndFarmHeader(name, farmName, category, shortSku, productId, createdAtStr),
                              const SizedBox(height: 16),
                              _buildPricingAndInventoryCard(price, unit, unitName, stock, isPreorder),
                              const SizedBox(height: 16),
                              _buildFourBentoMetrics(totalSold, unit, grossVolume, rating, reviews, isPreorder, isFreeShipping),
                              if (isPreorder) ...[
                                const SizedBox(height: 16),
                                _buildPreorderTimelineBanner(harvestDays, estHarvestDate),
                              ],
                              const SizedBox(height: 16),
                              _buildDescriptionNotes(description),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Pane (Image showcase + Pricing + Live storefront button)
                              SizedBox(
                                width: 280,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildProductVisualCard(imageUrl, isPreorder, category),
                                    const SizedBox(height: 14),
                                    _buildPricingAndInventoryCard(price, unit, unitName, stock, isPreorder),
                                    const SizedBox(height: 14),
                                    ElevatedButton.icon(
                                      onPressed: navigateToStorefront,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AdminUi.brand,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      icon: const Icon(Icons.storefront_rounded, size: 18),
                                      label: Text(
                                        'View on Live Storefront',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),

                              // Right Pane (Title + Bento metrics + Harvest timeline + Description)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTitleAndFarmHeader(name, farmName, category, shortSku, productId, createdAtStr),
                                    const SizedBox(height: 16),
                                    _buildFourBentoMetrics(totalSold, unit, grossVolume, rating, reviews, isPreorder, isFreeShipping),
                                    if (isPreorder) ...[
                                      const SizedBox(height: 14),
                                      _buildPreorderTimelineBanner(harvestDays, estHarvestDate),
                                    ],
                                    const SizedBox(height: 14),
                                    _buildDescriptionNotes(description),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                // ── 3. Bottom Footer Actions ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
                    border: Border(top: BorderSide(color: Color(0xFFE6EDE8))),
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Active/Hidden Status Indicator
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive ? AdminUi.success : AdminUi.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isActive ? 'Live on Storefront' : 'Hidden from Storefront',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isActive ? AdminUi.success : AdminUi.danger,
                            ),
                          ),
                        ],
                      ),

                      // Actions
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (isMobile)
                            OutlinedButton.icon(
                              onPressed: navigateToStorefront,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                side: const BorderSide(color: Color(0xFFD3DFD7)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.storefront_rounded, size: 15),
                              label: Text('View in Store', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              side: const BorderSide(color: Color(0xFFD3DFD7)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Close', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final ok = await widget.adminService.toggleFeaturedProduct(productId, !isFeatured);
                              if (!mounted || !context.mounted) return;
                              Navigator.of(context).pop();
                              if (ok) {
                                _loadData();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AdminUi.brand,
                                    content: Text(isFeatured ? 'Product unfeatured from home' : '⭐ Product featured on home!'),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFeatured ? Colors.orange.shade800 : AdminUi.brand,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: Icon(isFeatured ? Icons.star_border_rounded : Icons.star_rounded, size: 16),
                            label: Text(
                              isFeatured ? 'Unfeature' : 'Feature Product',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800),
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
        );
      },
    );
  }

  Widget _buildProductVisualCard(String? imageUrl, bool isPreorder, String category) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E9E4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _fallbackImagePlaceholder(isPreorder),
            )
          else
            _fallbackImagePlaceholder(isPreorder),
          // Category tag overlay
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.category_outlined, size: 12, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    category,
                    style: GoogleFonts.plusJakartaSans(
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
    );
  }

  Widget _fallbackImagePlaceholder(bool isPreorder) {
    return Center(
      child: Icon(
        isPreorder ? Icons.eco_rounded : Icons.inventory_2_rounded,
        size: 54,
        color: AdminUi.brand.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildTitleAndFarmHeader(
    String name,
    String farmName,
    String category,
    String shortSku,
    String productId,
    String createdAtStr,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AdminUi.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AdminUi.brandSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.agriculture_rounded, size: 14, color: AdminUi.brand),
                  const SizedBox(width: 5),
                  Text(
                    farmName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AdminUi.brandDark,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: productId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied Product ID to clipboard!')),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E9E4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SKU: $shortSku',
                      style: GoogleFonts.robotoMono(fontSize: 10, color: AdminUi.textMuted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.copy_rounded, size: 11, color: AdminUi.textMuted),
                  ],
                ),
              ),
            ),
            Text(
              '• Listed $createdAtStr',
              style: GoogleFonts.inter(fontSize: 11, color: AdminUi.textMuted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPricingAndInventoryCard(double price, String unit, String unitName, int stock, bool isPreorder) {
    final stockColor = stock <= 0 ? AdminUi.danger : (stock < 10 ? AdminUi.warning : AdminUi.success);
    final stockText = stock <= 0
        ? (isPreorder ? '0 Slots Available' : 'Out of Stock')
        : (isPreorder ? '$stock Pre-Order Slots' : '$stock $unit in Stock');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E9E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COMMERCIAL PRICING', style: AdminUi.label(size: 9, color: AdminUi.textMuted, weight: FontWeight.w800)),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₱${price.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AdminUi.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'per $unit ($unitName)',
                style: GoogleFonts.inter(fontSize: 11, color: AdminUi.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE6EDE8)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPreorder ? 'ALLOCATED CAPACITY' : 'INVENTORY HEALTH',
                style: AdminUi.label(size: 9, color: AdminUi.textMuted, weight: FontWeight.w800),
              ),
              Text(
                stockText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: stockColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (stock / 100.0).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: const Color(0xFFEAEFEA),
              valueColor: AlwaysStoppedAnimation<Color>(stockColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourBentoMetrics(
    double totalSold,
    String unit,
    double grossVolume,
    String rating,
    String reviews,
    bool isPreorder,
    bool isFreeShipping,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: _bentoTile(
                Icons.trending_up_rounded,
                'PLATFORM SALES VOLUME',
                '${totalSold.toStringAsFixed(0)} $unit Sold',
                '₱${grossVolume.toStringAsFixed(2)} Gross Sales',
                AdminUi.brand,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _bentoTile(
                Icons.star_rounded,
                'CUSTOMER RATING',
                '★ $rating / 5.0',
                '$reviews verified reviews',
                Colors.amber.shade800,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _bentoTile(
                isPreorder ? Icons.eco_rounded : Icons.bolt_rounded,
                'FULFILLMENT MODE',
                isPreorder ? 'Seasonal Harvest' : 'Same-Day Dispatch',
                isPreorder ? 'Batch campaign' : 'Direct from storage',
                isPreorder ? AdminUi.brandSecondary : AdminUi.info,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _bentoTile(
                Icons.local_shipping_rounded,
                'LOGISTICS & DELIVERY',
                isFreeShipping ? 'Free Farm Shipping' : 'Standard Courier',
                'Farm-to-Door Delivery',
                isFreeShipping ? Colors.blue.shade800 : AdminUi.textSecondary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bentoTile(IconData icon, String label, String value, String subvalue, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6EDE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AdminUi.textMuted,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AdminUi.textPrimary,
            ),
          ),
          Text(
            subvalue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 10, color: AdminUi.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPreorderTimelineBanner(int harvestDays, DateTime? estHarvestDate) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF092B1D), Color(0xFF134E37)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E523A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    'Harvest Lifecycle Timeline',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$harvestDays Days Duration',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            estHarvestDate != null
                ? 'Target Batch Delivery Date: ${DateFormat('MMMM d, yyyy').format(estHarvestDate)}'
                : 'Batch pre-order crop cycle is active.',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionNotes(String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Agricultural Description & Quality Notes',
          style: AdminUi.label(size: 11, color: AdminUi.textPrimary, weight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFCFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEAEFEA)),
          ),
          child: Text(
            description,
            style: GoogleFonts.inter(fontSize: 12, height: 1.45, color: AdminUi.textSecondary),
          ),
        ),
      ],
    );
  }

  void _exportProductsCSV() {
    _productsFuture.then((products) {
      if (!mounted) return;
      if (products.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No products available to export.')),
        );
        return;
      }

      final csvContent = StringBuffer();
      csvContent.writeln('ID,Product Name,Farm,Category,Mode,Price,Stock,Status');
      for (final p in products) {
        final mode = p['is_preorder'] == true ? 'Pre-Order' : 'Instant';
        final status = p['is_active'] != false ? 'Active' : 'Hidden';
        csvContent.writeln(
          '"${p['product_id']}","${p['name']}","${p['farm_name']}","${p['category_name']}","$mode","${p['price']}","${p['stock_quantity']}","$status"',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AdminUi.brand,
          content: Text('📥 Exported ${products.length} products to CSV buffer!'),
        ),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILTERING & PAGINATION HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  List<Map<String, dynamic>> _filterAndSortProducts(List<Map<String, dynamic>> products) {
    var filtered = products.where((p) {
      // 1. Tab filter
      if (_selectedTab == 'instant' && p['is_preorder'] == true) return false;
      if (_selectedTab == 'preorder' && p['is_preorder'] != true) return false;
      if (_selectedTab == 'featured' && p['is_featured'] != true) return false;
      if (_selectedTab == 'low_stock' && (p['stock_quantity'] ?? 0) > 0) return false;

      // 2. Category filter
      if (_selectedCategory != 'All Categories') {
        final cat = (p['category_name'] ?? '').toString().toLowerCase();
        if (cat != _selectedCategory.toLowerCase()) return false;
      }

      // 3. Search query
      if (_searchQuery.isNotEmpty) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final farm = (p['farm_name'] ?? '').toString().toLowerCase();
        final cat = (p['category_name'] ?? '').toString().toLowerCase();
        if (!name.contains(_searchQuery) && !farm.contains(_searchQuery) && !cat.contains(_searchQuery)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sorting
    if (_sortBy == 'price_asc') {
      filtered.sort((a, b) => ((a['price'] as num?) ?? 0).compareTo((b['price'] as num?) ?? 0));
    } else if (_sortBy == 'price_desc') {
      filtered.sort((a, b) => ((b['price'] as num?) ?? 0).compareTo((a['price'] as num?) ?? 0));
    } else if (_sortBy == 'stock_asc') {
      filtered.sort((a, b) => ((a['stock_quantity'] as num?) ?? 0).compareTo((b['stock_quantity'] as num?) ?? 0));
    } else if (_sortBy == 'rating') {
      filtered.sort((a, b) => ((b['average_rating'] as num?) ?? 0).compareTo((a['average_rating'] as num?) ?? 0));
    } else {
      // newest
      filtered.sort((a, b) {
        final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });
    }

    return filtered;
  }

  List<Map<String, dynamic>> _getPaginatedProducts(List<Map<String, dynamic>> all) {
    final start = (_currentPage - 1) * _rowsPerPage;
    var end = start + _rowsPerPage;
    if (end > all.length) end = all.length;
    if (start >= all.length) return all.take(_rowsPerPage).toList();
    return all.sublist(start, end);
  }
}
