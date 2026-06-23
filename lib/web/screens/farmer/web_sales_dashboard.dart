import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/animated_components.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/integration/weather_service.dart';
import '../../../shared/models/weather_model.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';
import '../../../shared/services/auth/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_routes.dart';
import '../../widgets/web_consumer_nav_bar.dart';

class WebSalesDashboard extends StatefulWidget {
  final Function(int) onNavigate;
  final int currentIndex;

  const WebSalesDashboard({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
  });

  @override
  State<WebSalesDashboard> createState() => _WebSalesDashboardState();
}

class _WebSalesDashboardState extends State<WebSalesDashboard> with TickerProviderStateMixin {
  // Premium Design Tokens
  static const Color _primary = Color(0xFF10B981); // Emerald
  static const Color _secondary = Color(0xFF3B82F6); // Blue
  static const Color _accent = Color(0xFFF59E0B); // Amber
  
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _white = Color(0xFFFFFFFF);

  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 0);

  // Animations
  late AnimationController _fadeInController;
  late List<AnimationController> _metricControllers;
  final Set<int> _hoveredMetrics = {};
  int _hoveredNav = -1;

  // Data State
  int _pendingOrders = 0;
  int _activeListings = 0;
  double _weeklyRevenue = 0.0;
  List<Map<String, dynamic>> _recentOrders = [];
  bool _isLoading = true;
  String _farmerName = '';
  List<double> _salesData = List.filled(7, 0.0);
  List<double> _inventoryData = [1.0, 0.0, 0.0];
  String _inventoryLegend1 = '0%';
  String _inventoryLegend2 = '0%';
  String _inventoryLegend3 = '0%';
  String _farmerRating = '0.0';
  String _farmerReviews = '0 Reviews';

  @override
  void initState() {
    super.initState();
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..forward();

    _metricControllers = List.generate(
      4,
      (i) => AnimationController(
        duration: const Duration(milliseconds: 700),
        vsync: this,
      ),
    );

    // Staggered entry
    Future.delayed(const Duration(milliseconds: 400), () {
      for (int i = 0; i < _metricControllers.length; i++) {
        Future.delayed(Duration(milliseconds: 120 * i), () {
          if (mounted) _metricControllers[i].forward();
        });
      }
    });

    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final name = AuthService().userName;
      final products = await SupabaseDataService().getFarmerProducts();
      final orders = await SupabaseDataService().getFarmerOrders();
      final farmerResponse = await SupabaseDataService().getFarmerProfile(AuthService().userId);
      
      final rating = farmerResponse?['average_rating']?.toString() ?? '4.9';
      final reviews = farmerResponse?['review_count']?.toString() ?? '120+';

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      List<double> salesLast7Days = List.filled(7, 0.0);

      int pending = 0;
      double revenue = 0.0;
      for (final order in orders) {
        final status = order['status']?.toString().toUpperCase() ?? '';
        if (status == 'PENDING') pending++;
        if (status == 'DELIVERED') {
          final total = (order['rawTotal'] as num?)?.toDouble() ?? 0.0;
          revenue += total;

          final createdAt = order['createdAt'] as DateTime?;
          if (createdAt != null) {
            final orderDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
            final diff = today.difference(orderDate).inDays;
            if (diff >= 0 && diff < 7) {
              salesLast7Days[6 - diff] += total;
            }
          }
        }
      }

      int inStockCount = 0;
      int lowStockCount = 0;
      int outOfStockCount = 0;

      for (final product in products) {
        final qty = (product['available_quantity'] as num?)?.toDouble() ?? 0.0;
        if (qty <= 0) {
          outOfStockCount++;
        } else if (qty < 5) {
          lowStockCount++;
        } else {
          inStockCount++;
        }
      }
      
      final totalInventory = inStockCount + lowStockCount + outOfStockCount;
      List<double> inventoryData = [inStockCount.toDouble(), lowStockCount.toDouble(), outOfStockCount.toDouble()];
      if (totalInventory == 0) {
        inventoryData = [1.0, 0.0, 0.0]; // fallback
      }

      if (mounted) {
        setState(() {
          _farmerName = name.isEmpty ? 'Farmer' : name;
          _activeListings = products.where((p) => (p['available_quantity'] ?? 0) > 0).length;
          _pendingOrders = pending;
          _weeklyRevenue = revenue;
          _recentOrders = List<Map<String, dynamic>>.from(orders.take(6));
          _salesData = salesLast7Days;
          _inventoryData = inventoryData;
          _farmerRating = rating;
          _farmerReviews = '$reviews Reviews';
          if (totalInventory > 0) {
            _inventoryLegend1 = '${((inStockCount / totalInventory) * 100).toStringAsFixed(0)}%';
            _inventoryLegend2 = '${((lowStockCount / totalInventory) * 100).toStringAsFixed(0)}%';
            _inventoryLegend3 = '${((outOfStockCount / totalInventory) * 100).toStringAsFixed(0)}%';
          } else {
            _inventoryLegend1 = '0%';
            _inventoryLegend2 = '0%';
            _inventoryLegend3 = '0%';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    for (final c in _metricControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          // Background Design Elements
          Positioned.fill(
            child: CustomPaint(
              painter: DotPatternPainter(opacity: 0.04, color: _primary),
            ),
          ),
          const Positioned.fill(
            child: FloatingParticles(
              count: 12,
              maxSize: 1.5,
              color: Color(0xFF10B981),
              height: 1200,
            ),
          ),
          // Gradient blobs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_primary.withValues(alpha: 0.05), Colors.transparent],
                ),
              ),
            ),
          ),

          Column(
            children: [
              _buildNavBar(),
              Expanded(
                child: _isLoading 
                  ? const Center(child: AppShimmerLoader())
                  : _buildMainScrollableArea(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;

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

    final navItems = ['Dashboard', 'Products', 'Orders', 'Community'];
    return Container(
      margin: isMobile
          ? const EdgeInsets.fromLTRB(16, 16, 16, 8)
          : const EdgeInsets.fromLTRB(32, 24, 32, 12),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 28,
        vertical: isMobile ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: _dark.withValues(alpha: 0.03),
            blurRadius: 30,
            offset: const Offset(0, 10),
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
                size: isMobile ? BrandLogoSize.small : BrandLogoSize.medium,
              ),
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 48),
            ...List.generate(navItems.length, (i) {
              final isActive = i == widget.currentIndex;
              final isHovered = _hoveredNav == i;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hoveredNav = i),
                  onExit: (_) => setState(() => _hoveredNav = -1),
                  child: GestureDetector(
                    onTap: () => widget.onNavigate(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
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
                          fontSize: 15,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive
                              ? _primary
                              : isHovered
                              ? _dark
                              : _muted,
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
              onTap: () => widget.onNavigate(4),
              child: Container(
                width: isMobile ? 38 : 46,
                height: isMobile ? 38 : 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, Color(0xFF059669)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: isMobile ? 20 : 24,
                ),
              ),
            ),
          ),
          if (isMobile) ...[
            const SizedBox(width: 8),
            PopupMenuButton<int>(
              icon: const Icon(Icons.menu, color: _primary),
              tooltip: '',
              onSelected: (index) {
                widget.onNavigate(index);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 0,
                  child: Row(
                    children: [
                      Icon(Icons.dashboard_rounded, color: widget.currentIndex == 0 ? _primary : _muted, size: 20),
                      const SizedBox(width: 8),
                      Text('Dashboard', style: GoogleFonts.inter(fontWeight: widget.currentIndex == 0 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 1,
                  child: Row(
                    children: [
                      Icon(Icons.agriculture_rounded, color: widget.currentIndex == 1 ? _primary : _muted, size: 20),
                      const SizedBox(width: 8),
                      Text('Products', style: GoogleFonts.inter(fontWeight: widget.currentIndex == 1 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 2,
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: widget.currentIndex == 2 ? _primary : _muted, size: 20),
                      const SizedBox(width: 8),
                      Text('Orders', style: GoogleFonts.inter(fontWeight: widget.currentIndex == 2 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 3,
                  child: Row(
                    children: [
                      Icon(Icons.people_rounded, color: widget.currentIndex == 3 ? _primary : _muted, size: 20),
                      const SizedBox(width: 8),
                      Text('Community', style: GoogleFonts.inter(fontWeight: widget.currentIndex == 3 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 4,
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded, color: widget.currentIndex == 4 ? _primary : _muted, size: 20),
                      const SizedBox(width: 8),
                      Text('Profile', style: GoogleFonts.inter(fontWeight: widget.currentIndex == 4 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainScrollableArea() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 40),
      physics: const BouncingScrollPhysics(),
      child: FadeTransition(
        opacity: _fadeInController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            SizedBox(height: isMobile ? 24 : 40),
            _buildMetricsRow(),
            SizedBox(height: isMobile ? 24 : 40),
            _buildInsightsGrid(),
            SizedBox(height: isMobile ? 24 : 40),
            _buildRecentActivitySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;

    final headerText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, $_farmerName!',
          style: GoogleFonts.plusJakartaSans(
            fontSize: isMobile ? 24 : 36,
            fontWeight: FontWeight.w800,
            color: _dark,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Manage your farm's performance and orders from one place.",
          style: GoogleFonts.inter(
            fontSize: isMobile ? 14 : 16,
            color: _muted,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );

    final weatherWidget = FutureBuilder<WeatherData?>(
      future: WeatherService().getWeatherByCity('Manila'),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final temp = data?.temperature.toStringAsFixed(0) ?? '28';
        final desc = data?.description ?? 'Sunny';
        final isSunny = desc.toLowerCase().contains('sun') || desc.toLowerCase().contains('clear');
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSunny ? Icons.wb_sunny_rounded : Icons.cloud_rounded,
                color: isSunny ? _accent : const Color(0xFF3B82F6),
                size: 24,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$desc · $temp°C',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _dark),
                  ),
                  Text(
                    isSunny ? 'Perfect for harvesting' : 'Good day for maintenance',
                    style: GoogleFonts.inter(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerText,
          const SizedBox(height: 16),
          weatherWidget,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: headerText),
        const SizedBox(width: 16),
        weatherWidget,
      ],
    );
  }

  Widget _buildMetricsRow() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;
    final isTablet = sw >= 650 && sw < 1000;

    final metrics = [
      ('Pending Orders', '$_pendingOrders', 'Active tasks', Icons.shopping_bag_outlined, _secondary),
      ('Active Listings', '$_activeListings', 'Storefront live', Icons.inventory_2_outlined, _primary),
      ('Total Revenue', _currencyFormat.format(_weeklyRevenue), 'Lifetime sales', Icons.trending_up_rounded, _accent),
      ('Farmer Rating', _farmerRating, _farmerReviews, Icons.star_rounded, Colors.amber),
    ];

    if (isMobile) {
      return Column(
        children: List.generate(
          metrics.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildAnimatedMetricCard(
              index,
              metrics[index].$1,
              metrics[index].$2,
              metrics[index].$3,
              metrics[index].$4,
              metrics[index].$5,
            ),
          ),
        ),
      );
    }

    if (isTablet) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 16),
                  child: _buildAnimatedMetricCard(
                    0,
                    metrics[0].$1,
                    metrics[0].$2,
                    metrics[0].$3,
                    metrics[0].$4,
                    metrics[0].$5,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 16),
                  child: _buildAnimatedMetricCard(
                    1,
                    metrics[1].$1,
                    metrics[1].$2,
                    metrics[1].$3,
                    metrics[1].$4,
                    metrics[1].$5,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildAnimatedMetricCard(
                    2,
                    metrics[2].$1,
                    metrics[2].$2,
                    metrics[2].$3,
                    metrics[2].$4,
                    metrics[2].$5,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _buildAnimatedMetricCard(
                    3,
                    metrics[3].$1,
                    metrics[3].$2,
                    metrics[3].$3,
                    metrics[3].$4,
                    metrics[3].$5,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: List.generate(
        metrics.length,
        (index) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 3 ? 0 : 24),
            child: _buildAnimatedMetricCard(
              index,
              metrics[index].$1,
              metrics[index].$2,
              metrics[index].$3,
              metrics[index].$4,
              metrics[index].$5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedMetricCard(int i, String l, String v, String s, IconData ic, Color c) {
    return FadeTransition(
      opacity: _metricControllers[i],
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _metricControllers[i], curve: Curves.easeOutQuart),
        ),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hoveredMetrics.add(i)),
          onExit: (_) => setState(() => _hoveredMetrics.remove(i)),
          child: HoverScaleCard(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _hoveredMetrics.contains(i) ? c.withValues(alpha: 0.5) : _border,
                  width: _hoveredMetrics.contains(i) ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: c.withValues(alpha: 0.05),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(ic, color: c, size: 24),
                      ),
                      Icon(Icons.more_horiz_rounded, color: _muted.withValues(alpha: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    v,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsGrid() {
    final sw = MediaQuery.of(context).size.width;
    final isMobileOrTablet = sw < 1000;

    if (isMobileOrTablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSalesPerformanceChart(),
          const SizedBox(height: 24),
          _buildInventoryDistribution(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildSalesPerformanceChart(),
        ),
        const SizedBox(width: 40),
        Expanded(
          flex: 1,
          child: _buildInventoryDistribution(),
        ),
      ],
    );
  }

  Widget _buildSalesPerformanceChart() {
    return Container(
      padding: const EdgeInsets.all(32),
      height: 400,
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales Performance',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              Text(
                'Last 7 Days',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _muted),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 240,
            child: MiniBarChart(
              values: _salesData,
              barColor: _primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryDistribution() {
    return Container(
      padding: const EdgeInsets.all(32),
      height: 400,
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inventory Split',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const Spacer(),
          Center(
            child: MiniDonutChart(
              size: 200,
              values: _inventoryData,
              colors: const [_primary, _secondary, _accent],
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_activeListings', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: _dark)),
                  Text('Total', style: GoogleFonts.inter(fontSize: 12, color: _muted)),
                ],
              ),
            ),
          ),
          const Spacer(),
          _buildLegendRow('In Stock', _primary, _inventoryLegend1),
          const SizedBox(height: 12),
          _buildLegendRow('Low Stock', _secondary, _inventoryLegend2),
          const SizedBox(height: 12),
          _buildLegendRow('Out of Stock', _accent, _inventoryLegend3),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String label, Color color, String percent) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: _dark, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(percent, style: GoogleFonts.inter(fontSize: 13, color: _muted, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildRecentActivitySection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigate(2),
                child: Text('View Full History', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _primary)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_recentOrders.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('No recent orders.', style: GoogleFonts.inter(color: _muted))))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentOrders.length,
              separatorBuilder: (context, i) => Divider(color: _border.withValues(alpha: 0.5), height: 32),
              itemBuilder: (context, i) => _buildActivityRow(_recentOrders[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityRow(Map<String, dynamic> o) {
    final status = o['status']?.toString().toUpperCase() ?? 'PENDING';
    Color statusColor = Colors.orange;
    if (status == 'DELIVERED') statusColor = _primary;
    
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            status == 'DELIVERED' ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
            color: statusColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order from ${o['customerName'] ?? 'Customer'}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _dark, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                o['items'] ?? 'Processing...',
                style: GoogleFonts.inter(color: _muted, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              o['total'] ?? '₱0',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: _dark, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              o['timeAgo'] ?? 'Recently',
              style: GoogleFonts.inter(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
