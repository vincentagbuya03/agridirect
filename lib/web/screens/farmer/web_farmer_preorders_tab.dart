import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/commerce/product_service.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../widgets/web_hamburger_menu_button.dart';
import '../../widgets/web_consumer_nav_bar.dart';
import '../../widgets/crop_milestones_timeline.dart';
import '../../../shared/models/product/crop_milestone_model.dart';
import '../../../shared/data/app_data.dart';

class WebFarmerPreordersTab extends StatefulWidget {
  final Function(int) onNavigate;
  final int currentIndex;

  const WebFarmerPreordersTab({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
  });

  @override
  State<WebFarmerPreordersTab> createState() => _WebFarmerPreordersTabState();
}

class _WebFarmerPreordersTabState extends State<WebFarmerPreordersTab> {
  // Design Tokens
  static const Color _primary = Color(0xFF059669);
  static const Color _primaryDark = Color(0xFF047857);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  final _supabase = Supabase.instance.client;
  final _productService = ProductService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _preorders = [];
  double _totalProjectedRevenue = 0.0;
  double _totalReservations = 0.0;
  int _hoveredNav = -1;
  final Set<String> _expandedProductIds = {};

  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // 'ALL', 'GROWING', 'UNDER_RESERVED', 'IMMINENT'

  @override
  void initState() {
    super.initState();
    _loadPreorders();
  }

  Future<void> _loadPreorders() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Resolve user_id to farmer_id first
      final farmerResponse = await _supabase
          .from('farmers')
          .select('farmer_id')
          .eq('user_id', currentUserId)
          .maybeSingle();

      if (farmerResponse == null) {
        if (mounted) {
          setState(() {
            _preorders = [];
            _totalProjectedRevenue = 0.0;
            _totalReservations = 0.0;
            _isLoading = false;
          });
        }
        return;
      }

      final farmerId = farmerResponse['farmer_id'] as String;

      final productsResponse = await _supabase
          .from('products')
          .select('*, categories(name), units(name)')
          .eq('farmer_id', farmerId)
          .eq('is_preorder', true);

      final products = List<Map<String, dynamic>>.from(productsResponse as List);

      double revenue = 0.0;
      double totalRes = 0.0;

      for (var product in products) {
        final productId = product['product_id'];

        final itemsResponse = await _supabase
            .from('order_items')
            .select('quantity, orders!inner(order_statuses!inner(code))')
            .eq('product_id', productId)
            .inFilter('orders.order_statuses.code', ['pending', 'confirmed', 'PENDING', 'CONFIRMED']);

        final items = List<Map<String, dynamic>>.from(itemsResponse as List);
        double reserved =
            items.fold<double>(0.0, (sum, item) => sum + ((item['quantity'] as num?)?.toDouble() ?? 0.0));

        product['reserved_quantity'] = reserved;

        try {
          final milestones = await _productService.getCropMilestones(productId);
          product['milestones'] = milestones;
        } catch (_) {
          product['milestones'] = <CropMilestone>[];
        }

        final price = (product['price'] as num?)?.toDouble() ?? 0.0;
        revenue += reserved * price;
        totalRes += reserved;
      }

      if (mounted) {
        setState(() {
          _preorders = products;
          _totalProjectedRevenue = revenue;
          _totalReservations = totalRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading farmer pre-orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading preorders: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Filtered Preorders ───────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredPreorders {
    return _preorders.where((p) {
      final name = p['name']?.toString().toLowerCase() ?? '';
      final cat = p['categories']?['name']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty || name.contains(query) || cat.contains(query);

      if (!matchesSearch) return false;

      final reserved = p['reserved_quantity'] as double? ?? 0.0;
      final target = (p['stock_quantity'] as num?)?.toDouble() ?? 100.0;
      final harvestDays = int.tryParse(p['harvest_days']?.toString() ?? '') ?? 0;
      final createdAt =
          p['created_at'] != null ? DateTime.parse(p['created_at'].toString()) : DateTime.now();
      final daysLeft = createdAt.add(Duration(days: harvestDays)).difference(DateTime.now()).inDays + 1;

      if (_selectedFilter == 'GROWING') {
        return daysLeft > 5;
      } else if (_selectedFilter == 'UNDER_RESERVED') {
        return target > 0 && (reserved / target) < 0.5;
      } else if (_selectedFilter == 'IMMINENT') {
        return daysLeft <= 5 && daysLeft >= 0;
      }

      return true;
    }).toList();
  }

  int _countForFilter(String filter) {
    if (filter == 'ALL') return _preorders.length;
    return _preorders.where((p) {
      final reserved = p['reserved_quantity'] as double? ?? 0.0;
      final target = (p['stock_quantity'] as num?)?.toDouble() ?? 100.0;
      final harvestDays = int.tryParse(p['harvest_days']?.toString() ?? '') ?? 0;
      final createdAt =
          p['created_at'] != null ? DateTime.parse(p['created_at'].toString()) : DateTime.now();
      final daysLeft = createdAt.add(Duration(days: harvestDays)).difference(DateTime.now()).inDays + 1;

      if (filter == 'GROWING') return daysLeft > 5;
      if (filter == 'UNDER_RESERVED') return target > 0 && (reserved / target) < 0.5;
      if (filter == 'IMMINENT') return daysLeft <= 5 && daysLeft >= 0;
      return true;
    }).length;
  }

  // ─── Next Imminent Harvest Calculation ─────────────────────────────────────
  String get _nextHarvestInfo {
    if (_preorders.isEmpty) return 'None active';
    int minDays = 9999;
    String crop = '';
    for (var p in _preorders) {
      final harvestDays = int.tryParse(p['harvest_days']?.toString() ?? '') ?? 0;
      final createdAt =
          p['created_at'] != null ? DateTime.parse(p['created_at'].toString()) : DateTime.now();
      final daysLeft = createdAt.add(Duration(days: harvestDays)).difference(DateTime.now()).inDays + 1;
      if (daysLeft >= 0 && daysLeft < minDays) {
        minDays = daysLeft;
        crop = p['name']?.toString() ?? 'Produce';
      }
    }
    if (minDays == 9999) return 'Harvested';
    return '$crop ($minDays days)';
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildNavBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: AppShimmerLoader())
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 16 : 36,
                      0,
                      isMobile ? 16 : 36,
                      48,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1360),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTopHeader(isMobile),
                            const SizedBox(height: 20),
                            _buildAnalyticsStrip(isMobile),
                            const SizedBox(height: 24),
                            _buildControlsHub(isMobile),
                            const SizedBox(height: 18),
                            _buildPreordersList(isMobile),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Nav Bar ───────────────────────────────────────────────────────────────
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
            ? const EdgeInsets.fromLTRB(16, 16, 16, 8)
            : const EdgeInsets.fromLTRB(32, 24, 32, 12),
      );
    }

    final navItems = ['Dashboard', 'Products', 'Orders', 'Community', 'Pre-Orders'];
    return Container(
      margin: isMobile
          ? const EdgeInsets.fromLTRB(16, 16, 16, 8)
          : (isCompact
              ? const EdgeInsets.fromLTRB(20, 16, 20, 8)
              : const EdgeInsets.fromLTRB(32, 24, 32, 12)),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : (isCompact ? 16 : 28),
        vertical: isMobile ? 12 : (isCompact ? 10 : 14),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _dark.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                size: (isMobile || isCompact) ? BrandLogoSize.small : BrandLogoSize.medium,
              ),
            ),
          ),
          if (!isMobile) ...[
            SizedBox(width: isCompact ? 16 : 48),
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
                        horizontal: isCompact ? 12 : 20,
                        vertical: isCompact ? 10 : 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isActive
                            ? _primary.withValues(alpha: 0.1)
                            : isHovered
                                ? _border.withValues(alpha: 0.35)
                                : Colors.transparent,
                      ),
                      child: Text(
                        navItems[i],
                        style: GoogleFonts.inter(
                          fontSize: isCompact ? 13 : 15,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? _primary : (isHovered ? _dark : _muted),
                          letterSpacing: 0.2,
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
                width: (isMobile || isCompact) ? 38 : 44,
                height: (isMobile || isCompact) ? 38 : 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _primaryDark],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
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

  // ─── Header Section ────────────────────────────────────────────────────────
  Widget _buildTopHeader(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.spa_rounded, size: 14, color: _primary),
                        const SizedBox(width: 5),
                        Text(
                          'HARVEST & PRE-ORDER PIPELINE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: _primaryDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Pre-Order & Harvest Campaigns',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 22 : 28,
                  fontWeight: FontWeight.w900,
                  color: _dark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage crop reservation quotas, post growth updates to buyers, and track seasonal harvest schedules.',
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 12 : 13.5,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
        // Action Button: Add Pre-Order
        ElevatedButton.icon(
          onPressed: () => context.push(AppRoutes.addProduct),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(
            isMobile ? 'New' : 'Launch Campaign',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 18,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // ─── Executive Harvest Analytics Strip ─────────────────────────────────────
  Widget _buildAnalyticsStrip(bool isMobile) {
    final metrics = [
      _HarvestMetricData(
        title: 'Active Campaigns',
        value: _preorders.length.toString(),
        subtitle: 'Live pre-order listings',
        icon: Icons.spa_rounded,
        color: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
        borderColor: const Color(0xFFA7F3D0),
      ),
      _HarvestMetricData(
        title: 'Reserved Volume',
        value: '${_totalReservations.toStringAsFixed(0)} units',
        subtitle: 'Advance buyer orders',
        icon: Icons.bookmark_added_rounded,
        color: const Color(0xFF0284C7),
        bgColor: const Color(0xFFF0F9FF),
        borderColor: const Color(0xFFBAE6FD),
      ),
      _HarvestMetricData(
        title: 'Projected Revenue',
        value: '₱${_totalProjectedRevenue.toStringAsFixed(2)}',
        subtitle: 'Committed harvest payout',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        borderColor: const Color(0xFFFDE68A),
      ),
      _HarvestMetricData(
        title: 'Next Harvest',
        value: _nextHarvestInfo,
        subtitle: 'Upcoming batch deadline',
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF5F3FF),
        borderColor: const Color(0xFFDDD6FE),
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: metrics.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (ctx, i) => SizedBox(
            width: 220,
            child: _buildMetricCard(metrics[i]),
          ),
        ),
      );
    }

    return Row(
      children: metrics
          .map(
            (m) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildMetricCard(m),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMetricCard(_HarvestMetricData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: data.borderColor.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, size: 18, color: data.color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            data.subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: _muted,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── Controls Hub (Status Chips + Search) ──────────────────────────────────
  Widget _buildControlsHub(bool isMobile) {
    final filters = [
      {'id': 'ALL', 'label': 'All Campaigns'},
      {'id': 'GROWING', 'label': '🌿 Growing'},
      {'id': 'UNDER_RESERVED', 'label': '⚠️ Under-Reserved'},
      {'id': 'IMMINENT', 'label': '🌾 Harvest Soon'},
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          // 1. Status Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: filters.map((f) {
                final isSelected = _selectedFilter == f['id'];
                final count = _countForFilter(f['id']!);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilter = f['id']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? _primary : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? _primary : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              f['label']!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                count.toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? Colors.white : _muted,
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
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // 2. Search Box
          Container(
            width: isMobile ? double.infinity : 320,
            height: 40,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.inter(fontSize: 13, color: _dark),
              decoration: InputDecoration(
                hintText: 'Search crop or variety...',
                hintStyle: GoogleFonts.inter(color: _muted, fontSize: 12.5),
                prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 18),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Pre-Orders List ───────────────────────────────────────────────────────
  Widget _buildPreordersList(bool isMobile) {
    final filtered = _filteredPreorders;

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.spa_outlined,
                  size: 40,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Pre-Order Campaigns Found',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _searchQuery.isNotEmpty || _selectedFilter != 'ALL'
                    ? 'No campaigns match your active search or filter criteria.'
                    : 'Launch a pre-order campaign to start taking advance buyer reservations.',
                style: GoogleFonts.inter(fontSize: 13, color: _muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.addProduct),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Create Pre-Order Listing'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        return _buildCampaignCard(filtered[index], isMobile);
      },
    );
  }

  // ─── Individual Campaign Card ──────────────────────────────────────────────
  Widget _buildCampaignCard(Map<String, dynamic> product, bool isMobile) {
    final reserved = product['reserved_quantity'] as double? ?? 0.0;
    final target = (product['stock_quantity'] as num?)?.toDouble() ?? 100.0;
    final percent = (reserved / (target > 0 ? target : 1.0)).clamp(0.0, 1.0);
    final unitName = product['units']?['name']?.toString() ?? 'units';
    final harvestDays = int.tryParse(product['harvest_days']?.toString() ?? '') ?? 0;
    final createdAt =
        product['created_at'] != null ? DateTime.parse(product['created_at'].toString()) : DateTime.now();
    final daysLeft = createdAt.add(Duration(days: harvestDays)).difference(DateTime.now()).inDays + 1;
    final isHarvestSoon = daysLeft <= 5 && daysLeft >= 0;
    final isUnderReserved = target > 0 && (reserved / target) < 0.5;

    final productId = product['product_id']?.toString() ?? '';
    final isExpanded = _expandedProductIds.contains(productId);
    final imageUrl = product['image_url']?.toString() ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isHarvestSoon ? const Color(0xFFFDE68A) : _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Card Content
            Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Thumbnail + Title + Days Countdown Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: imageUrl.isNotEmpty
                            ? SafeNetworkImage(
                                imageUrl: imageUrl,
                                width: isMobile ? 60 : 72,
                                height: isMobile ? 60 : 72,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: isMobile ? 60 : 72,
                                height: isMobile ? 60 : 72,
                                color: const Color(0xFFF1F5F9),
                                child: const Icon(Icons.spa_rounded, size: 30, color: _primary),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    product['name']?.toString() ?? 'Crop Produce',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: isMobile ? 16 : 18,
                                      fontWeight: FontWeight.w800,
                                      color: _dark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '₱${price.toStringAsFixed(2)} / $unitName',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: _primaryDark,
                                  ),
                                ),
                                if (product['categories']?['name'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      product['categories']['name'].toString(),
                                      style: GoogleFonts.inter(fontSize: 11, color: _muted, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Countdown Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isHarvestSoon ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isHarvestSoon ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isHarvestSoon ? Icons.alarm_rounded : Icons.spa_rounded,
                              size: 14,
                              color: isHarvestSoon ? const Color(0xFFD97706) : _primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              daysLeft > 0 ? '$daysLeft days left' : 'Harvest Ready',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: isHarvestSoon ? const Color(0xFFB45309) : _primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Progress Meter Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Reservation Goal: ${(percent * 100).toStringAsFixed(0)}%',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: _dark),
                          ),
                          Text(
                            '$reserved / $target $unitName (₱${(reserved * price).toStringAsFixed(2)})',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: _muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percent >= 1.0 ? const Color(0xFF059669) : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Under-reserved Warning
                  if (isHarvestSoon && isUnderReserved) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Low reservation rate: ${(percent * 100).toStringAsFixed(0)}% with only $daysLeft days remaining before harvest!',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF9F1239),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Action Buttons Toolbar
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showPostUpdateDialog(
                            product['product_id'],
                            product['name'],
                          ),
                          icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                          label: const Text('Post Update'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primary,
                            side: const BorderSide(color: _primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _markHarvestComplete(
                            product['product_id'],
                            product['name'],
                          ),
                          icon: const Icon(Icons.check_circle_rounded, size: 16),
                          label: const Text('Mark Harvested'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Details launcher
                      IconButton(
                        onPressed: () {
                          final productItem = ProductItem(
                            productId: product['product_id']?.toString(),
                            farmerId: product['farmer_id']?.toString(),
                            name: product['name']?.toString() ?? '',
                            price: product['price']?.toString() ?? '0',
                            unit: product['units']?['name']?.toString() ?? 'units',
                            imageUrl: product['image_url']?.toString() ?? '',
                            categoryName: product['categories']?['name']?.toString(),
                            harvestDays: product['harvest_days']?.toString(),
                            description: product['description']?.toString(),
                            reservedQuantity: reserved,
                            targetQuantity: target,
                            farm: '',
                          );
                          context.push(AppRoutes.farmerPreorderDetail, extra: productItem);
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 20, color: _muted),
                        tooltip: 'View Campaign Details',
                        splashRadius: 18,
                      ),
                      // Expand/collapse milestone feed
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedProductIds.remove(productId);
                            } else {
                              _expandedProductIds.add(productId);
                            }
                          });
                        },
                        icon: Icon(
                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: _muted,
                        ),
                        tooltip: isExpanded ? 'Hide Milestones' : 'View Milestones',
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Expandable Growth Milestones Timeline Feed
            if (isExpanded) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crop Growth Timeline & Updates',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (product['milestones'] != null && (product['milestones'] as List).isNotEmpty)
                      CropMilestonesTimeline(
                        milestones: List<CropMilestone>.from(product['milestones'] as List),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No growth updates posted yet. Click "Post Update" above to share photos with buyers.',
                          style: GoogleFonts.inter(fontSize: 12.5, color: _muted),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Post Growth Update Dialog ─────────────────────────────────────────────
  Future<void> _showPostUpdateDialog(String productId, String cropName) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    XFile? pickedImage;
    Uint8List? imageBytes;
    bool isPosting = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.spa_rounded, color: _primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Post Growth Update',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cropName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: isPosting ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: _muted),
                      splashRadius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Milestone Title', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  style: GoogleFonts.inter(fontSize: 14, color: _dark),
                  decoration: InputDecoration(
                    hintText: 'e.g., Flowering Stage 🌱',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Update Description', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
                const SizedBox(height: 6),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  style: GoogleFonts.inter(fontSize: 14, color: _dark),
                  decoration: InputDecoration(
                    hintText: 'Describe crop health, weather conditions, and growth progress...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Progress Photo', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
                const SizedBox(height: 6),
                imageBytes != null
                    ? Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(imageBytes!, fit: BoxFit.cover),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      pickedImage = null;
                                      imageBytes = null;
                                    });
                                  },
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1200,
                              imageQuality: 80,
                            );
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              setDialogState(() {
                                pickedImage = image;
                                imageBytes = bytes;
                              });
                            }
                          },
                          child: Container(
                            height: 90,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_a_photo_rounded, color: _primary, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  'Upload Progress Photo',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: isPosting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _muted,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: isPosting
                          ? null
                          : () async {
                              if (titleController.text.trim().isEmpty || descController.text.trim().isEmpty) {
                                return;
                              }
                              setDialogState(() => isPosting = true);
                              try {
                                String? imageUrl;
                                if (imageBytes != null && pickedImage != null) {
                                  final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedImage!.name}';
                                  final path = 'milestones/$fileName';
                                  final uploadResult = await SupabaseDatabase.uploadImage(
                                    bucket: 'uploads',
                                    path: path,
                                    bytes: imageBytes,
                                  );
                                  if (uploadResult != null) {
                                    imageUrl = _supabase.storage.from('uploads').getPublicUrl(path);
                                  }
                                }

                                await _productService.addCropMilestone(
                                  productId: productId,
                                  title: titleController.text.trim(),
                                  description: descController.text.trim(),
                                  imageUrl: imageUrl,
                                );
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                _loadPreorders();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Growth milestone posted successfully!'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                );
                              } finally {
                                setDialogState(() => isPosting = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        isPosting ? 'Posting...' : 'Post Update',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Mark Harvest Complete ─────────────────────────────────────────────────
  Future<void> _markHarvestComplete(String productId, String cropName) async {
    bool confirm = await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD97706),
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Confirm Harvest',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Are you sure "$cropName" is harvested?\n\nThis will convert the campaign to ready stock and notify all customers who pre-ordered.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: _muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _muted,
                            side: const BorderSide(color: _border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Confirm Harvest', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('products').update({'is_preorder': false}).eq('product_id', productId);

      final reservationsResponse = await _supabase
          .from('order_items')
          .select('orders!inner(customer_id, order_number, order_statuses!inner(code))')
          .eq('product_id', productId)
          .inFilter('orders.order_statuses.code', ['pending', 'confirmed', 'PENDING', 'CONFIRMED']);

      final uniqueCustomerIds = List<Map<String, dynamic>>.from(reservationsResponse as List)
          .map((item) => item['orders']?['customer_id']?.toString())
          .whereType<String>()
          .toSet();

      for (final customerId in uniqueCustomerIds) {
        await _supabase.from('notifications').insert({
          'user_id': customerId,
          'title': '🍏 Crop Harvested!',
          'message': 'Your pre-ordered $cropName has been harvested and is ready for fulfillment!',
          'link_type': 'orders',
          'is_read': false,
        });
      }

      await _loadPreorders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$cropName" marked as harvested! Buyers have been notified.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ─── Metric Data Model ───────────────────────────────────────────────────────
class _HarvestMetricData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  _HarvestMetricData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });
}
