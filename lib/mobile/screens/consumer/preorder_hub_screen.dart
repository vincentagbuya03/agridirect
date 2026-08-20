import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/models/cached_product.dart';
import '../../../shared/services/offline/offline_cache_service.dart';
import '../../../shared/services/offline/network_status_service.dart';
import '../../widgets/offline_browse_widget.dart';
import '../../widgets/skeleton_loaders.dart';
import '../../../shared/services/auth/auth_service.dart';

enum PreOrderSort {
  earliestHarvest('Earliest Harvest', Icons.hourglass_bottom_rounded),
  mostReserved('Most Reserved', Icons.local_fire_department_rounded),
  priceLowToHigh('Price: Low to High', Icons.arrow_upward_rounded),
  priceHighToLow('Price: High to Low', Icons.arrow_downward_rounded),
  topRated('Top Rated', Icons.star_rounded);

  final String label;
  final IconData icon;
  const PreOrderSort(this.label, this.icon);
}

/// Pre-Order Hub - Professional Farm-to-Consumer Harvest Reservation Screen
class PreOrderHubScreen extends StatefulWidget {
  const PreOrderHubScreen({super.key});

  @override
  State<PreOrderHubScreen> createState() => _PreOrderHubScreenState();
}

class _PreOrderHubScreenState extends State<PreOrderHubScreen> {
  int _selectedCategoryIndex = 0;
  List<String> _categories = ['All Crops'];
  final _searchController = TextEditingController();
  late Future<List<ProductItem>> _preOrdersFuture;
  bool _isOnline = true;
  late OfflineCacheService _cacheService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Sorting & Quick Filters
  PreOrderSort _currentSort = PreOrderSort.earliestHarvest;
  bool _filterUrgentOnly = false;
  bool _filterHotOnly = false;
  bool _showHowItWorksBanner = true;

  @override
  void initState() {
    super.initState();
    _initializeCacheService();
    _setupConnectivityListener();
    _preOrdersFuture = _loadPreOrders();
  }

  void _initializeCacheService() {
    _cacheService = OfflineCacheService();
  }

  void _setupConnectivityListener() {
    _refreshConnectivityStatus();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      _,
    ) async {
      final wasOffline = !_isOnline;
      final isOnline = await NetworkStatusService().isOnline();
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
          if (wasOffline && isOnline) {
            _preOrdersFuture = _loadPreOrders();
          }
        });
      }
    });
  }

  Future<void> _refreshConnectivityStatus() async {
    final isOnline = await NetworkStatusService().isOnline();
    if (mounted) {
      setState(() => _isOnline = isOnline);
    }
  }

  Future<List<ProductItem>> _loadPreOrders() async {
    final products = await SupabaseDataService().getPreOrderProducts();
    final categories =
        products
            .map((p) => p.categoryName?.trim())
            .where((category) => category != null && category.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (mounted) {
      setState(() {
        _categories = ['All Crops', ...categories];
        if (_selectedCategoryIndex >= _categories.length) {
          _selectedCategoryIndex = 0;
        }
      });
    }

    return products;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshPreOrders() async {
    setState(() {
      _preOrdersFuture = _loadPreOrders();
    });
    await _preOrdersFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildAppBarHeader(),
            Expanded(
              child: _isOnline ? _buildOnlineBody() : _buildOfflineBody(),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // APP BAR / HEADER
  // ===========================================================================
  Widget _buildAppBarHeader() {
    final canPop = Navigator.of(context).canPop();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action Row
              Row(
                children: [
                  if (canPop)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  // Title and badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.eco_rounded,
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'HARVEST RESERVATIONS',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pre-Order Hub',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Info / How It Works Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showHowItWorksDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.help_outline_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Guide',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Refresh Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _refreshPreOrders,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search & Filter Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFCBD5E1),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search crop, farmer, or variety...',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.cancel_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Sort Selector Button
                  PopupMenuButton<PreOrderSort>(
                    initialValue: _currentSort,
                    onSelected: (sort) => setState(() => _currentSort = sort),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    itemBuilder: (context) => PreOrderSort.values.map((sort) {
                      final isSelected = sort == _currentSort;
                      return PopupMenuItem<PreOrderSort>(
                        value: sort,
                        child: Row(
                          children: [
                            Icon(
                              sort.icon,
                              size: 18,
                              color: isSelected
                                  ? AppColors.primary
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                sort.label,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.primary
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _currentSort != PreOrderSort.earliestHarvest
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _currentSort != PreOrderSort.earliestHarvest
                              ? AppColors.primary
                              : const Color(0xFFCBD5E1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _currentSort.icon,
                            size: 18,
                            color: _currentSort != PreOrderSort.earliestHarvest
                                ? AppColors.primary
                                : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 20,
                            color: Color(0xFF475569),
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

  // ===========================================================================
  // CATEGORY PILLS BAR
  // ===========================================================================
  Widget _buildCategorySelectorBar(List<ProductItem> allProducts) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(_categories.length, (index) {
            final category = _categories[index];
            final isSelected = _selectedCategoryIndex == index;

            // Compute category count
            int count = 0;
            if (index == 0) {
              count = allProducts.length;
            } else {
              count = allProducts
                  .where(
                    (p) =>
                        (p.categoryName ?? '').trim().toLowerCase() ==
                        category.toLowerCase(),
                  )
                  .length;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedCategoryIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getCategoryIcon(category),
                        size: 15,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        category,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF334155),
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('all')) {
      return Icons.grid_view_rounded;
    }
    if (lower.contains('veg')) {
      return Icons.eco_rounded;
    }
    if (lower.contains('fruit')) {
      return Icons.apple_rounded;
    }
    if (lower.contains('grain') || lower.contains('rice')) {
      return Icons.grass_rounded;
    }
    if (lower.contains('root') || lower.contains('tuber')) {
      return Icons.yard_rounded;
    }
    if (lower.contains('herb') || lower.contains('spice')) {
      return Icons.spa_rounded;
    }
    return Icons.agriculture_rounded;
  }

  // ===========================================================================
  // BODY IMPLEMENTATIONS (ONLINE / OFFLINE)
  // ===========================================================================
  Widget _buildOnlineBody() {
    return FutureBuilder<List<ProductItem>>(
      future: _preOrdersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: PreOrderListSkeleton(itemCount: 4, enabled: true),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final rawProducts = snapshot.data ?? [];

        // Auto-cache preorder products for offline support
        _autoCacheProducts(rawProducts);

        final currentUserId = AuthService().userId;
        final filteredList = rawProducts.where((p) {
          final isNotMine =
              currentUserId.isEmpty || p.farmerId != currentUserId;
          return isNotMine && !_isHarvested(p) && _matchesCurrentFilters(p);
        }).toList();

        // Apply sorting
        final sortedList = _sortProducts(filteredList);

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refreshPreOrders,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // 1. Categories
              SliverToBoxAdapter(
                child: _buildCategorySelectorBar(rawProducts),
              ),

              // 2. Educational Hero Banner (Collapsible)
              if (_showHowItWorksBanner)
                SliverToBoxAdapter(
                  child: _buildEducationalBanner(),
                ),

              // 3. Quick Filter Tags & Results Count Bar
              SliverToBoxAdapter(
                child: _buildFilterChipsAndSummaryBar(sortedList.length),
              ),

              // 4. Products List or Empty State
              if (sortedList.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = sortedList[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _buildProfessionalPreOrderCard(product),
                        );
                      },
                      childCount: sortedList.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfflineBody() {
    final currentUserId = AuthService().userId;
    final cachedPreorders = _cacheService
        .getAllCachedProducts()
        .where((p) => p.isPreorder)
        .map(_cachedToProductItem)
        .where((p) {
          final isNotMine =
              currentUserId.isEmpty || p.farmerId != currentUserId;
          return _matchesCurrentFilters(p) && isNotMine;
        })
        .toList();

    final sortedList = _sortProducts(cachedPreorders);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: OfflineModeIndicator(cacheService: _cacheService),
        ),
        _buildCategorySelectorBar(cachedPreorders),
        Expanded(
          child: sortedList.isEmpty
              ? _buildEmptyState(isOffline: true)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  physics: const BouncingScrollPhysics(),
                  itemCount: sortedList.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _buildProfessionalPreOrderCard(sortedList[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ===========================================================================
  // BANNER & FILTER SUMMARY BAR
  // ===========================================================================
  Widget _buildEducationalBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.spa_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lock in Direct Farm-Gate Prices',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reserve crops while they grow. Guaranteed freshness dispatched directly upon harvest.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFD1FAE5),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _showHowItWorksDialog,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Learn how it works',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
            ],
          ),
          Positioned(
            top: -4,
            right: -4,
            child: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white70,
                size: 18,
              ),
              onPressed: () => setState(() => _showHowItWorksBanner = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChipsAndSummaryBar(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // Count pill
            Text(
              '$count upcoming ${count == 1 ? 'harvest' : 'harvests'}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 12),
            // Urgent filter toggle
            _buildQuickFilterPill(
              label: 'Ending Soon',
              icon: Icons.alarm_rounded,
              isActive: _filterUrgentOnly,
              onTap: () => setState(() => _filterUrgentOnly = !_filterUrgentOnly),
            ),
            const SizedBox(width: 8),
            // Hot filter toggle
            _buildQuickFilterPill(
              label: 'High Demand',
              icon: Icons.whatshot_rounded,
              isActive: _filterHotOnly,
              activeColor: const Color(0xFFEA580C),
              onTap: () => setState(() => _filterHotOnly = !_filterHotOnly),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilterPill({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    Color activeColor = AppColors.primary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.12)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? activeColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? activeColor : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PROFESSIONAL PRE-ORDER PRODUCT CARD
  // ===========================================================================
  Widget _buildProfessionalPreOrderCard(ProductItem product) {
    // Calculate Harvest Countdown
    int daysLeft = 7;
    String timeUnitLabel = 'DAYS LEFT';
    bool isUrgent = false;

    if (product.harvestDays != null) {
      final days = int.tryParse(product.harvestDays!) ?? 7;
      if (product.createdAt != null) {
        final harvestDate = product.createdAt!.add(Duration(days: days));
        final diff = harvestDate.difference(DateTime.now());
        if (diff.isNegative) {
          daysLeft = 0;
          timeUnitLabel = 'HARVESTED';
        } else {
          final remainingDays = diff.inDays;
          if (remainingDays >= 1) {
            daysLeft = remainingDays;
            timeUnitLabel = remainingDays == 1 ? 'DAY LEFT' : 'DAYS LEFT';
            isUrgent = remainingDays <= 3;
          } else {
            final remainingHours = diff.inHours;
            if (remainingHours >= 1) {
              daysLeft = remainingHours;
              timeUnitLabel = remainingHours == 1 ? 'HR LEFT' : 'HRS LEFT';
              isUrgent = true;
            } else {
              final remainingMinutes = diff.inMinutes;
              daysLeft = remainingMinutes > 0 ? remainingMinutes : 0;
              timeUnitLabel = remainingMinutes == 1 ? 'MIN LEFT' : 'MINS LEFT';
              isUrgent = true;
            }
          }
        }
      } else {
        daysLeft = days;
        isUrgent = days <= 3;
      }
    }

    final reservedQty = product.reservedQuantity ?? 0;
    final targetQty = product.targetQuantity ?? 0;
    final reservedPercent = targetQty > 0
        ? ((reservedQty / targetQty) * 100).clamp(0, 100).round()
        : 0;
    final isHot = reservedPercent >= 70;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. IMAGE HERO SECTION WITH STATUS BADGES
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(23),
                ),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: product.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: Color(0xFF94A3B8),
                                size: 40,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: Icon(
                              Icons.agriculture_rounded,
                              color: Color(0xFF94A3B8),
                              size: 44,
                            ),
                          ),
                        ),
                ),
              ),

              // Gradient Overlay for readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(23),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Top Left: Days Left Countdown Badge
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isUrgent
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF0F172A).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUrgent
                            ? Icons.alarm_rounded
                            : Icons.hourglass_top_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$daysLeft $timeUnitLabel',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Top Right: Hot Reservation Pill & Category Tag
              Positioned(
                top: 14,
                right: 14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isHot)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEA580C).withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.whatshot_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'HOT',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if ((product.categoryName ?? '').isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          product.categoryName!.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom Left on Image: Price & Unit Tag
              Positioned(
                bottom: 12,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _normalizePrice(product.price),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        ' / ${product.unit.isNotEmpty ? product.unit : 'kg'}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. PRODUCT DETAILS & FARMER CREDENTIALS
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name
                Text(
                  product.name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Farmer & Farm Row
                Builder(
                  builder: (context) {
                    final farmName = product.farm.trim();
                    final farmerName = (product.farmerName ?? '').trim();
                    final displayFarm = farmName.isNotEmpty && farmName != 'Farm'
                        ? farmName
                        : (farmerName.isNotEmpty ? farmerName : 'Local Farm');
                    final hasDistinctFarmer = farmerName.isNotEmpty && farmerName != displayFarm;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: const Color(0xFFE2E8F0),
                          backgroundImage:
                              (product.farmerAvatarUrl ?? '').isNotEmpty
                                  ? NetworkImage(product.farmerAvatarUrl!)
                                  : null,
                          child: (product.farmerAvatarUrl ?? '').isEmpty
                              ? const Icon(
                                  Icons.storefront_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayFarm,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1E293B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                              if (hasDistinctFarmer)
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Text(
                                    'by $farmerName',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (product.rating != null &&
                            double.tryParse(product.rating!) != null &&
                            double.parse(product.rating!) > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: Color(0xFFD97706),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  product.rating!,
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
                    );
                  },
                ),

                // Description (if present)
                if ((product.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    product.description!.trim(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),

                // 3. RESERVATION PROGRESS BAR & TARGET METRICS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.pie_chart_rounded,
                          size: 14,
                          color: isHot
                              ? const Color(0xFFEA580C)
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$reservedPercent% Reserved',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isHot
                                ? const Color(0xFFEA580C)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      targetQty > 0
                          ? '${reservedQty.toStringAsFixed(0)} / ${targetQty.toStringAsFixed(0)} ${product.unit.isNotEmpty ? product.unit : 'kg'}'
                          : 'Target: Flexible',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: targetQty > 0
                        ? (reservedQty / targetQty).clamp(0.0, 1.0)
                        : (reservedPercent / 100),
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isHot ? const Color(0xFFEA580C) : AppColors.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 4. ACTION CTA BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _openPreOrderDetails(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_bag_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isHarvested(product)
                              ? 'ORDER NOW'
                              : 'RESERVE HARVEST',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
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

  // ===========================================================================
  // HOW PRE-ORDER WORKS MODAL / BOTTOM SHEET
  // ===========================================================================
  void _showHowItWorksDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.spa_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How Pre-Orders Work',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Support farmers and get the freshest harvest',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildHowItWorksStep(
              number: '1',
              title: 'Reserve Before Harvest',
              description:
                  'Farmers list upcoming crops with estimated harvest timelines and target yields.',
              icon: Icons.calendar_today_rounded,
            ),
            const SizedBox(height: 16),
            _buildHowItWorksStep(
              number: '2',
              title: 'Lock In Direct Prices',
              description:
                  'Secure your share at lower farm-gate prices before open market markups occur.',
              icon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 16),
            _buildHowItWorksStep(
              number: '3',
              title: 'Track Harvest Progress',
              description:
                  'Stay informed as the farmer nurtures and ripens the crop to peak flavor.',
              icon: Icons.timeline_rounded,
            ),
            const SizedBox(height: 16),
            _buildHowItWorksStep(
              number: '4',
              title: 'Fresh Doorstep Dispatch',
              description:
                  'Produce is carefully harvested and delivered straight to your home with zero storage delay.',
              icon: Icons.local_shipping_outlined,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Got It!',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksStep({
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // EMPTY & ERROR STATES
  // ===========================================================================
  Widget _buildEmptyState({bool isOffline = false}) {
    final hasSearch = _searchController.text.trim().isNotEmpty;
    final hasCategory = _selectedCategoryIndex > 0;
    final hasQuickFilters = _filterUrgentOnly || _filterHotOnly;

    final title = isOffline
        ? 'No Cached Harvests'
        : hasSearch || hasCategory || hasQuickFilters
            ? 'No Matching Pre-Orders'
            : 'No Upcoming Harvests Yet';

    final message = isOffline
        ? 'Connect to the internet once to cache upcoming harvests for offline viewing.'
        : hasSearch || hasCategory || hasQuickFilters
            ? 'Try adjusting your search keywords, category filters, or sort criteria.'
            : 'Farmers are currently planting their next crops. Check back soon for new reservations!';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(
                isOffline
                    ? Icons.cloud_off_rounded
                    : Icons.yard_outlined,
                size: 48,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasSearch || hasCategory || hasQuickFilters) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _selectedCategoryIndex = 0;
                    _filterUrgentOnly = false;
                    _filterHotOnly = false;
                    _currentSort = PreOrderSort.earliestHarvest;
                  });
                },
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: const Text('Reset All Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Could Not Load Pre-Orders',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              error.replaceFirst('Exception: ', ''),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refreshPreOrders,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HELPER LOGIC
  // ===========================================================================
  List<ProductItem> _sortProducts(List<ProductItem> products) {
    final sorted = [...products];
    switch (_currentSort) {
      case PreOrderSort.earliestHarvest:
        sorted.sort((a, b) {
          final aDays = int.tryParse(a.harvestDays ?? '') ?? 9999;
          final bDays = int.tryParse(b.harvestDays ?? '') ?? 9999;
          return aDays.compareTo(bDays);
        });
        break;
      case PreOrderSort.mostReserved:
        sorted.sort((a, b) {
          final aTarget = a.targetQuantity ?? 1;
          final aReserved = a.reservedQuantity ?? 0;
          final aRatio = aTarget > 0 ? (aReserved / aTarget) : 0.0;

          final bTarget = b.targetQuantity ?? 1;
          final bReserved = b.reservedQuantity ?? 0;
          final bRatio = bTarget > 0 ? (bReserved / bTarget) : 0.0;

          return bRatio.compareTo(aRatio);
        });
        break;
      case PreOrderSort.priceLowToHigh:
        sorted.sort((a, b) {
          final aPrice = _parsePrice(a.price);
          final bPrice = _parsePrice(b.price);
          return aPrice.compareTo(bPrice);
        });
        break;
      case PreOrderSort.priceHighToLow:
        sorted.sort((a, b) {
          final aPrice = _parsePrice(a.price);
          final bPrice = _parsePrice(b.price);
          return bPrice.compareTo(aPrice);
        });
        break;
      case PreOrderSort.topRated:
        sorted.sort((a, b) {
          final aRating = double.tryParse(a.rating ?? '0') ?? 0.0;
          final bRating = double.tryParse(b.rating ?? '0') ?? 0.0;
          return bRating.compareTo(aRating);
        });
        break;
    }
    return sorted;
  }

  bool _matchesCurrentFilters(ProductItem product) {
    // 1. Search Query Match
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      final nameMatches = product.name.toLowerCase().contains(query);
      final farmMatches = product.farm.toLowerCase().contains(query);
      final farmerMatches =
          (product.farmerName ?? '').toLowerCase().contains(query);
      final categoryMatches =
          (product.categoryName ?? '').toLowerCase().contains(query);
      if (!nameMatches && !farmMatches && !farmerMatches && !categoryMatches) {
        return false;
      }
    }

    // 2. Category Match
    if (_selectedCategoryIndex > 0 &&
        _selectedCategoryIndex < _categories.length) {
      final selectedCategory =
          _categories[_selectedCategoryIndex].trim().toLowerCase();
      final productCategory = (product.categoryName ?? '').trim().toLowerCase();
      if (productCategory.isEmpty || productCategory != selectedCategory) {
        return false;
      }
    }

    // 3. Urgent (≤ 3 Days) Quick Filter
    if (_filterUrgentOnly) {
      final days = int.tryParse(product.harvestDays ?? '') ?? 99;
      if (days > 3) return false;
    }

    // 4. Hot (> 70% Reserved) Quick Filter
    if (_filterHotOnly) {
      final target = product.targetQuantity ?? 0;
      final reserved = product.reservedQuantity ?? 0;
      final percent = target > 0 ? (reserved / target) : 0.0;
      if (percent < 0.7) return false;
    }

    return true;
  }

  void _autoCacheProducts(List<ProductItem> products) {
    if (products.isEmpty) return;
    for (final product in products) {
      final cachedProduct = CachedProduct(
        id: product.productId ?? 'unknown_${product.name}',
        farmerId: product.farmerId ?? '',
        name: product.name,
        price: _parsePrice(product.price),
        description: product.description,
        imageUrl: product.imageUrl,
        category: product.categoryName,
        unit: product.unit,
        isPreorder: true,
        harvestDays: int.tryParse(product.harvestDays ?? '0') ?? 0,
        farmName: product.farm,
        rating: double.tryParse(product.rating ?? '0') ?? 0.0,
        farmerAvatarUrl: product.farmerAvatarUrl,
      );
      _cacheService.autoCacheProduct(cachedProduct);
    }
  }

  double _parsePrice(String rawPrice) {
    final normalized = rawPrice.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(normalized) ?? 0.0;
  }

  String _normalizePrice(String price) {
    final trimmed = price.trim();
    if (trimmed.isEmpty) return '₱0.00';

    final numeric = trimmed.replaceAll(RegExp(r'[^0-9.]'), '');
    if (numeric.isEmpty) return '₱0.00';

    final val = double.tryParse(numeric);
    if (val != null) {
      return '₱${val.toStringAsFixed(2)}';
    }
    return '₱$numeric';
  }

  ProductItem _cachedToProductItem(CachedProduct product) {
    final normalizedUnit = (product.unit ?? '').trim();

    return ProductItem(
      productId: product.id,
      farmerId: product.farmerId,
      farmerName: product.farmName,
      farmerAvatarUrl: product.farmerAvatarUrl,
      name: product.name,
      farm: product.farmName ?? 'Farm',
      price: '₱${product.price.toStringAsFixed(2)}',
      unit: normalizedUnit.isEmpty ? 'kg' : normalizedUnit,
      imageUrl: product.imageUrl ?? '',
      categoryName: product.category,
      rating: (product.rating ?? 0).toStringAsFixed(1),
      reviews: '0',
      harvestDays: product.harvestDays.toString(),
      description: product.description,
      reservedQuantity: 0,
      targetQuantity: 0,
    );
  }

  bool _isHarvested(ProductItem product) {
    final days = int.tryParse(product.harvestDays ?? '');
    if (days == null) return false;
    if (days <= 0) return true;
    if (product.createdAt != null) {
      final harvestDate = product.createdAt!.add(Duration(days: days));
      final now = DateTime.now();
      return harvestDate.difference(now).isNegative;
    }
    return false;
  }

  void _openPreOrderDetails(ProductItem product) {
    final productId = product.productId;
    if (productId == null || productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('This pre-order is missing product details.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    context.push(AppRoutes.preorderDetails, extra: product);
  }
}
