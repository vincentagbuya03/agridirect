import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../widgets/animated_components.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/models/order/order_model.dart';
import '../../../mobile/screens/farmer/farmer_order_details_screen.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../widgets/web_consumer_nav_bar.dart';
import '../../widgets/web_hamburger_menu_button.dart';
import '../../../shared/router/app_routes.dart';

class WebFarmerOrders extends StatefulWidget {
  final Function(int) onNavigate;
  final int currentIndex;

  const WebFarmerOrders({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
  });

  @override
  State<WebFarmerOrders> createState() => _WebFarmerOrdersState();
}

class _WebFarmerOrdersState extends State<WebFarmerOrders>
    with TickerProviderStateMixin {
  late AnimationController _fadeInController;
  int _hoveredNav = -1;
  String _searchQuery = '';
  String _selectedStatus = 'ALL';
  String _selectedFulfillment = 'ALL'; // 'ALL', 'DELIVERY', 'PICKUP'
  String _sortBy = 'NEWEST'; // 'NEWEST', 'OLDEST', 'HIGHEST'

  final List<String> _statusFilters = [
    'ALL',
    'PENDING',
    'CONFIRMED',
    'PROCESSING',
    'SHIPPED',
    'DELIVERED',
    'CANCELLED',
  ];

  List<Map<String, dynamic>> _orders = [];
  bool _ordersLoaded = false;
  final Set<String> _updatingOrderIds = {};

  static const Color _primary = Color(0xFF059669);
  static const Color _primaryDark = Color(0xFF047857);
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
    _loadOrders();
  }

  void _loadOrders() {
    setState(() => _ordersLoaded = false);
    SupabaseDataService().getFarmerOrders().then((data) {
      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data);
          _ordersLoaded = true;
        });
      }
      return data;
    }).catchError((_) {
      if (mounted) setState(() => _ordersLoaded = true);
      return <Map<String, dynamic>>[];
    });
  }

  void _updateOrderStatusLocally(String rawOrderId, String newStatus) {
    setState(() {
      final idx = _orders.indexWhere(
        (o) => o['rawOrderId']?.toString() == rawOrderId,
      );
      if (idx != -1) {
        _orders[idx] = Map<String, dynamic>.from(_orders[idx])
          ..['status'] = newStatus;
      }
    });
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    super.dispose();
  }

  // ─── Filter & Search Logic ────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredOrders {
    var list = _orders.where((o) {
      final id = o['orderId']?.toString().toLowerCase() ?? '';
      final customer = o['customerName']?.toString().toLowerCase() ?? '';
      final items = o['items']?.toString().toLowerCase() ?? '';
      final status = o['status']?.toString().toUpperCase() ?? '';
      final isCop = o['paymentMethod']?.toString().toUpperCase() == 'COP';

      final query = _searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          id.contains(query) ||
          customer.contains(query) ||
          items.contains(query);

      final matchesStatus =
          _selectedStatus == 'ALL' || status == _selectedStatus;

      final matchesFulfillment = _selectedFulfillment == 'ALL' ||
          (_selectedFulfillment == 'PICKUP' && isCop) ||
          (_selectedFulfillment == 'DELIVERY' && !isCop);

      return matchesSearch && matchesStatus && matchesFulfillment;
    }).toList();

    // Sorting
    if (_sortBy == 'NEWEST') {
      list.sort((a, b) {
        final tA = a['createdAt'] as DateTime? ?? DateTime.now();
        final tB = b['createdAt'] as DateTime? ?? DateTime.now();
        return tB.compareTo(tA);
      });
    } else if (_sortBy == 'OLDEST') {
      list.sort((a, b) {
        final tA = a['createdAt'] as DateTime? ?? DateTime.now();
        final tB = b['createdAt'] as DateTime? ?? DateTime.now();
        return tA.compareTo(tB);
      });
    } else if (_sortBy == 'HIGHEST') {
      list.sort((a, b) {
        final amtA = (a['rawTotal'] as num?)?.toDouble() ?? 0.0;
        final amtB = (b['rawTotal'] as num?)?.toDouble() ?? 0.0;
        return amtB.compareTo(amtA);
      });
    }

    return list;
  }

  int _countForStatus(String status) {
    if (status == 'ALL') return _orders.length;
    return _orders.where((o) => (o['status']?.toString().toUpperCase() ?? '') == status).length;
  }

  // ─── Metrics Calculations ──────────────────────────────────────────────────
  double get _totalDeliveredRevenue {
    return _orders
        .where((o) => (o['status']?.toString().toUpperCase() ?? '') == 'DELIVERED')
        .fold(0.0, (sum, o) => sum + ((o['rawTotal'] as num?)?.toDouble() ?? 0.0));
  }

  int get _pendingCount => _countForStatus('PENDING');
  int get _inProgressCount =>
      _countForStatus('CONFIRMED') +
      _countForStatus('PROCESSING') +
      _countForStatus('SHIPPED');

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;

    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DotPatternPainter(
                opacity: 0.025,
                color: _primary,
              ),
            ),
          ),
          Column(
            children: [
              _buildNavBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 36,
                    0,
                    isMobile ? 16 : 36,
                    48,
                  ),
                  child: FadeTransition(
                    opacity: _fadeInController,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1360),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTopHeader(isMobile),
                            const SizedBox(height: 20),
                            _buildMetricsStrip(isMobile),
                            const SizedBox(height: 24),
                            _buildControlHub(isMobile),
                            const SizedBox(height: 16),
                            _buildOrdersContent(isMobile),
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

    final navItems = [
      'Dashboard',
      'Products',
      'Orders',
      'Community',
      'Pre-Orders',
    ];
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

  // ─── Header ────────────────────────────────────────────────────────────────
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
                        const Icon(Icons.storefront_rounded, size: 14, color: _primary),
                        const SizedBox(width: 5),
                        Text(
                          'FARMER ORDER HUB',
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
                'Order Fulfillment & Sales',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 22 : 28,
                  fontWeight: FontWeight.w900,
                  color: _dark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage incoming buyer requests, prepare harvests, and track farm shipments.',
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 12 : 13.5,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
        // Action buttons
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _loadOrders,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.refresh_rounded, size: 18, color: _primary),
                  if (!isMobile) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Refresh',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _dark,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Executive KPI Metrics Strip ──────────────────────────────────────────
  Widget _buildMetricsStrip(bool isMobile) {
    final metrics = [
      _MetricData(
        title: 'Total Orders',
        value: _orders.length.toString(),
        subtitle: 'All-time volume',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF0284C7),
        bgColor: const Color(0xFFF0F9FF),
        borderColor: const Color(0xFFBAE6FD),
      ),
      _MetricData(
        title: 'Action Required',
        value: _pendingCount.toString(),
        subtitle: _pendingCount > 0 ? 'Needs confirmation' : 'All caught up',
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        borderColor: const Color(0xFFFDE68A),
        badgeText: _pendingCount > 0 ? 'URGENT' : null,
      ),
      _MetricData(
        title: 'In Fulfillment',
        value: _inProgressCount.toString(),
        subtitle: 'Processing & In-Transit',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF5F3FF),
        borderColor: const Color(0xFFDDD6FE),
      ),
      _MetricData(
        title: 'Delivered Revenue',
        value: '₱${_totalDeliveredRevenue.toStringAsFixed(2)}',
        subtitle: 'Completed sales payout',
        icon: Icons.account_balance_wallet_rounded,
        color: _primary,
        bgColor: const Color(0xFFECFDF5),
        borderColor: const Color(0xFFA7F3D0),
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

  Widget _buildMetricCard(_MetricData data) {
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
              if (data.badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    data.badgeText!,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
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

  // ─── Control Hub (Search, Filters, Sort) ───────────────────────────────────
  Widget _buildControlHub(bool isMobile) {
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
          // 1. Status Filter Pills with Counts
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _statusFilters.map((st) {
                final isSelected = _selectedStatus == st;
                final count = _countForStatus(st);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedStatus = st),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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
                              st,
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

          // 2. Search Bar + Fulfillment Filter + Sorter
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search input
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
                    hintText: 'Search order #, customer, item...',
                    hintStyle: GoogleFonts.inter(color: _muted, fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 18),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),

              // Fulfillment Type Filter Dropdown
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFulfillment,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _muted),
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: _dark),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedFulfillment = val);
                    },
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Methods')),
                      DropdownMenuItem(value: 'DELIVERY', child: Text('🚚 Delivery Orders')),
                      DropdownMenuItem(value: 'PICKUP', child: Text('🏪 Farm Pickups (COP)')),
                    ],
                  ),
                ),
              ),

              // Sorter Dropdown
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    icon: const Icon(Icons.sort_rounded, size: 18, color: _muted),
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: _dark),
                    onChanged: (val) {
                      if (val != null) setState(() => _sortBy = val);
                    },
                    items: const [
                      DropdownMenuItem(value: 'NEWEST', child: Text('Sort: Newest First')),
                      DropdownMenuItem(value: 'OLDEST', child: Text('Sort: Oldest First')),
                      DropdownMenuItem(value: 'HIGHEST', child: Text('Sort: Highest Amount')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Orders Data View ──────────────────────────────────────────────────────
  Widget _buildOrdersContent(bool isMobile) {
    if (!_ordersLoaded) {
      return _buildSkeleton();
    }

    final filtered = _filteredOrders;

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
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Orders Found',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _searchQuery.isNotEmpty || _selectedStatus != 'ALL'
                    ? 'No records match your active search or filter criteria.'
                    : 'Your customer orders will appear here once placed.',
                style: GoogleFonts.inter(fontSize: 13, color: _muted),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.isNotEmpty || _selectedStatus != 'ALL') ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _selectedStatus = 'ALL';
                      _selectedFulfillment = 'ALL';
                    });
                  },
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('Reset All Filters'),
                  style: TextButton.styleFrom(
                    foregroundColor: _primary,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (isMobile) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _buildMobileOrderCard(filtered[i]),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // Table Header
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  _headerCell('ORDER ID', flex: 4),
                  _headerCell('DATE', flex: 2),
                  _headerCell('CUSTOMER', flex: 3),
                  _headerCell('ITEMS', flex: 4),
                  _headerCell('TOTAL', flex: 2),
                  _headerCell('STATUS', flex: 3),
                  _headerCell('ACTION', flex: 3, align: TextAlign.end),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Table Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, i) => _buildDesktopTableRow(filtered[i]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String label, {int flex = 1, TextAlign align = TextAlign.start}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF64748B),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // ─── Desktop Table Row ─────────────────────────────────────────────────────
  Widget _buildDesktopTableRow(Map<String, dynamic> o) {
    final status = o['status']?.toString().toUpperCase() ?? 'PENDING';
    final isCop = o['paymentMethod']?.toString().toUpperCase() == 'COP';
    final canProgress = status != 'DELIVERED' && status != 'CANCELLED';
    final rawOrderId = o['rawOrderId']?.toString();
    final isUpdating = _updatingOrderIds.contains(rawOrderId);

    return _HoverableRow(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Order ID & Copy
            Expanded(
              flex: 4,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    final id = o['orderId']?.toString() ?? '';
                    Clipboard.setData(ClipboardData(text: id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied order ID: $id'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Tooltip(
                    message: 'Click to copy: ${o['orderId'] ?? ''}',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            o['orderId'] ?? '#0000',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _dark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy_rounded, size: 12, color: _muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Date / Time
            Expanded(
              flex: 2,
              child: Text(
                o['timeAgo'] ?? '',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _muted,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Customer Info
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (o['customerName'] ?? 'C')[0].toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      o['customerName'] ?? 'Customer',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _dark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Items & Fulfillment Method Pill
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCop ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isCop ? '🏪 COP' : '🚚 Ship',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isCop ? const Color(0xFFB45309) : const Color(0xFF0369A1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      o['items'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF334155),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Total Amount
            Expanded(
              flex: 2,
              child: Text(
                o['total'] ?? '₱0.00',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Status Badge
            Expanded(
              flex: 3,
              child: _StatusBadge(
                status: status,
                paymentMethod: o['paymentMethod'],
              ),
            ),

            // Primary Action CTA + Details Menu
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canProgress)
                    isUpdating
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _primary,
                              ),
                            ),
                          )
                        : Tooltip(
                            message: _getNextActionLabel(status, o['paymentMethod']),
                            child: ElevatedButton(
                              onPressed: () => _processOrderConfirmation(o),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                _getNextActionShortLabel(status, o['paymentMethod']),
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => _viewOrderDetails(o),
                    icon: const Icon(Icons.chevron_right_rounded, size: 20, color: _muted),
                    tooltip: 'View Full Details',
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Mobile Order Card ─────────────────────────────────────────────────────
  Widget _buildMobileOrderCard(Map<String, dynamic> o) {
    final status = o['status']?.toString().toUpperCase() ?? 'PENDING';
    final isCop = o['paymentMethod']?.toString().toUpperCase() == 'COP';
    final canProgress = status != 'DELIVERED' && status != 'CANCELLED';
    final rawOrderId = o['rawOrderId']?.toString();
    final isUpdating = _updatingOrderIds.contains(rawOrderId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: ID + Status + Method
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    o['orderId'] ?? '#0000',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCop ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isCop ? '🏪 Pickup' : '🚚 Delivery',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isCop ? const Color(0xFFB45309) : const Color(0xFF0369A1),
                      ),
                    ),
                  ),
                ],
              ),
              _StatusBadge(status: status, paymentMethod: o['paymentMethod']),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Customer & Items
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (o['customerName'] ?? 'C')[0].toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  o['customerName'] ?? 'Customer',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
              ),
              Text(
                o['timeAgo'] ?? '',
                style: GoogleFonts.inter(fontSize: 11, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 14, color: _muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  o['items'] ?? '',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Total & CTAs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL AMOUNT', style: GoogleFonts.inter(fontSize: 9.5, color: _muted, fontWeight: FontWeight.w700)),
                  Text(
                    o['total'] ?? '₱0.00',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _primaryDark,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => _viewOrderDetails(o),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _dark,
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Details', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  if (canProgress) ...[
                    const SizedBox(width: 8),
                    isUpdating
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                          )
                        : ElevatedButton(
                            onPressed: () => _processOrderConfirmation(o),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              _getNextActionShortLabel(status, o['paymentMethod']),
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Status Label Helpers ──────────────────────────────────────────────────
  String _getNextActionShortLabel(String status, dynamic paymentMethod) {
    final isCop = paymentMethod?.toString().toUpperCase() == 'COP';
    switch (status) {
      case 'PENDING':
        return 'Confirm';
      case 'CONFIRMED':
        return 'Prepare';
      case 'PROCESSING':
        return isCop ? 'Ready Pickup' : 'Ship';
      case 'SHIPPED':
        return isCop ? 'Complete' : 'Delivered';
      default:
        return 'Done';
    }
  }

  String _getNextActionLabel(String status, dynamic paymentMethod) {
    final isCop = paymentMethod?.toString().toUpperCase() == 'COP';
    switch (status) {
      case 'PENDING':
        return 'Confirm Order';
      case 'CONFIRMED':
        return 'Prepare Harvest / Items';
      case 'PROCESSING':
        return isCop ? 'Mark Ready for Pickup' : 'Ship Order via Courier';
      case 'SHIPPED':
        return isCop ? 'Complete Buyer Pickup' : 'Mark Delivered';
      default:
        return 'Order Completed';
    }
  }

  // ─── Skeleton Loading ──────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: List.generate(
          5,
          (i) => Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: i < 4 ? const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))) : null,
            ),
            child: Row(
              children: [
                _skeletonBox(100),
                const SizedBox(width: 24),
                _skeletonBox(80),
                const SizedBox(width: 24),
                _skeletonBox(120),
                const SizedBox(width: 24),
                _skeletonBox(160),
                const Spacer(),
                _skeletonBox(70),
                const SizedBox(width: 16),
                _skeletonBox(80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _skeletonBox(double width) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  // ─── Actions & Confirmation Dialog ─────────────────────────────────────────
  void _viewOrderDetails(Map<String, dynamic> o) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, a1, a2) => FarmerOrderDetailsScreen(
          order: Order(
            orderId: o['rawOrderId'].toString(),
            orderNumber: o['orderId'].toString().replaceFirst('#', ''),
            customerId: o['customerId'] ?? '',
            farmerId: '',
            status: o['status'] ?? 'PENDING',
            createdAt: o['createdAt'] as DateTime,
            updatedAt: o['createdAt'] as DateTime,
            deliveryAddressId: o['deliveryAddressId'],
            total: o['rawTotal'] as double?,
            subtotal: o['subtotal'] as double?,
            deliveryFee: o['deliveryFee'] as double?,
            paymentMethod: o['paymentMethod'],
          ),
          customerName: o['customerName'] ?? 'Customer',
          customerImage: o['customerImage']?.toString() ?? '',
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Future<void> _processOrderConfirmation(Map<String, dynamic> o) async {
    final orderIdStr = o['orderId'] ?? '#0000';
    final rawOrderId = o['rawOrderId']?.toString();
    if (rawOrderId == null) return;

    final status = o['status']?.toString().toUpperCase() ?? 'PENDING';
    final isCop = o['paymentMethod']?.toString().toUpperCase() == 'COP';

    String nextStatus = 'CONFIRMED';
    String actionText = 'Confirm Order';
    String confirmationMsg = 'Mark Order $orderIdStr as CONFIRMED?';

    if (status == 'PENDING') {
      nextStatus = 'CONFIRMED';
      actionText = 'Confirm Order';
      confirmationMsg = 'Accept and confirm Order $orderIdStr? The buyer will be notified.';
    } else if (status == 'CONFIRMED') {
      nextStatus = 'PROCESSING';
      actionText = 'Prepare Order';
      confirmationMsg = 'Start preparing items for Order $orderIdStr?';
    } else if (status == 'PROCESSING') {
      nextStatus = 'SHIPPED';
      actionText = isCop ? 'Ready for Pickup' : 'Ship Order';
      confirmationMsg = isCop
          ? 'Mark Order $orderIdStr as Ready for Pickup at your farm?'
          : 'Mark Order $orderIdStr as Shipped with courier?';
    } else if (status == 'SHIPPED') {
      nextStatus = 'DELIVERED';
      actionText = isCop ? 'Complete Pickup' : 'Mark Delivered';
      confirmationMsg = isCop
          ? 'Confirm buyer has picked up Order $orderIdStr?'
          : 'Confirm Order $orderIdStr has been successfully delivered?';
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: actionText,
        message: confirmationMsg,
        confirmLabel: actionText,
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _updatingOrderIds.add(rawOrderId);
      });

      try {
        await OrderService().updateOrderStatus(rawOrderId, nextStatus);
        if (mounted) {
          _updateOrderStatusLocally(rawOrderId, nextStatus);
          String successMsg = 'Order updated successfully.';
          if (nextStatus == 'SHIPPED') {
            successMsg = isCop
                ? 'Order is ready for farm pickup! Buyer notified.'
                : 'Order marked as shipped and in-transit!';
          } else if (nextStatus == 'DELIVERED') {
            successMsg = isCop
                ? 'Pickup completed! Order finalized.'
                : 'Order delivered successfully!';
          } else if (nextStatus == 'CONFIRMED') {
            successMsg = 'Order accepted! Ready to harvest & pack.';
          } else if (nextStatus == 'PROCESSING') {
            successMsg = 'Order is now processing!';
          }

          late OverlayEntry overlayEntry;
          overlayEntry = OverlayEntry(
            builder: (context) => Scaffold(
              backgroundColor: Colors.transparent,
              body: _StatusSuccessOverlay(
                statusTitle: nextStatus,
                message: successMsg,
                onFinished: () {
                  overlayEntry.remove();
                },
              ),
            ),
          );
          Overlay.of(context).insert(overlayEntry);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _updatingOrderIds.remove(rawOrderId);
          });
        }
      }
    }
  }
}

// ─── Metric Data Model ───────────────────────────────────────────────────────
class _MetricData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final String? badgeText;

  _MetricData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    this.badgeText,
  });
}

// ─── Status Badge ────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  final dynamic paymentMethod;
  const _StatusBadge({required this.status, this.paymentMethod});

  Color get _color {
    switch (status) {
      case 'DELIVERED':
        return const Color(0xFF059669);
      case 'SHIPPED':
        return const Color(0xFF2563EB);
      case 'PROCESSING':
        return const Color(0xFF7C3AED);
      case 'CONFIRMED':
        return const Color(0xFF0891B2);
      case 'CANCELLED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706); // PENDING
    }
  }

  Color get _bg {
    switch (status) {
      case 'DELIVERED':
        return const Color(0xFFECFDF5);
      case 'SHIPPED':
        return const Color(0xFFEFF6FF);
      case 'PROCESSING':
        return const Color(0xFFF5F3FF);
      case 'CONFIRMED':
        return const Color(0xFFECFEFF);
      case 'CANCELLED':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFFFFBEB);
    }
  }

  IconData get _icon {
    switch (status) {
      case 'DELIVERED':
        return Icons.check_circle_rounded;
      case 'SHIPPED':
        return Icons.local_shipping_rounded;
      case 'PROCESSING':
        return Icons.inventory_2_rounded;
      case 'CONFIRMED':
        return Icons.thumb_up_alt_rounded;
      case 'CANCELLED':
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  String get _labelText {
    final isCop = paymentMethod?.toString().toUpperCase() == 'COP';
    if (isCop) {
      if (status == 'DELIVERED') return 'PICKED UP';
      if (status == 'SHIPPED') return 'READY PICKUP';
    }
    return status;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: _color),
          const SizedBox(width: 4),
          Text(
            _labelText,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: _color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hoverable Row ───────────────────────────────────────────────────────────
class _HoverableRow extends StatefulWidget {
  final Widget child;
  const _HoverableRow({required this.child});

  @override
  State<_HoverableRow> createState() => _HoverableRowState();
}

class _HoverableRowState extends State<_HoverableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
        child: widget.child,
      ),
    );
  }
}

// ─── Confirmation Dialog ─────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 32,
                  color: Color(0xFF059669),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
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
}

// ─── Status Success Overlay ──────────────────────────────────────────────────
class _StatusSuccessOverlay extends StatefulWidget {
  final String statusTitle;
  final String message;
  final VoidCallback onFinished;

  const _StatusSuccessOverlay({
    required this.statusTitle,
    required this.message,
    required this.onFinished,
  });

  @override
  State<_StatusSuccessOverlay> createState() => _StatusSuccessOverlayState();
}

class _StatusSuccessOverlayState extends State<_StatusSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onFinished();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 24,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Updated',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.message,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF64748B),
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
}
