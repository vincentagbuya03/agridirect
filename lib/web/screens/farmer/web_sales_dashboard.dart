import 'package:flutter/material.dart';
import 'dart:ui' as ui;
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
import '../../widgets/web_hamburger_menu_button.dart';
import '../../../shared/services/commerce/voucher_service.dart';
import 'package:geolocator/geolocator.dart';
import 'web_weather_radar_screen.dart';


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
  static const Color _primaryDark = Color(0xFF047857);
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
  List<Map<String, dynamic>> _lowStockProducts = [];
  bool _isLoading = true;
  String _farmerName = '';
  List<double> _salesData = List.filled(7, 0.0);
  List<double> _inventoryData = [1.0, 0.0, 0.0];
  String _inventoryLegend1 = '0%';
  String _inventoryLegend2 = '0%';
  String _inventoryLegend3 = '0%';
  String _farmerRating = '0.0';
  String _farmerReviews = '0 Reviews';

  // Weather & Location State
  double? _farmLatitude;
  double? _farmLongitude;
  String? _farmLocationName;
  WeatherData? _weatherData;
  bool _isLoadingWeather = true;
  bool _showWeatherPage = false;

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

      final lat = (farmerResponse?['farm_latitude'] as num?)?.toDouble();
      final lon = (farmerResponse?['farm_longitude'] as num?)?.toDouble();
      final locName = farmerResponse?['location']?.toString() ?? farmerResponse?['farm_name']?.toString() ?? 'My Farm';

      WeatherData? weather;
      double finalLat = lat ?? 14.5995;
      double finalLon = lon ?? 120.9842;
      String finalLocName = locName;

      if (lat != null && lon != null) {
        weather = await WeatherService().getWeatherByCoordinates(
          latitude: lat,
          longitude: lon,
        );
      } else {
        try {
          final permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
            final pos = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 3));
            finalLat = pos.latitude;
            finalLon = pos.longitude;
            weather = await WeatherService().getWeatherByCoordinates(
              latitude: pos.latitude,
              longitude: pos.longitude,
            );
          }
        } catch (_) {}

        weather ??= await WeatherService().getWeatherByCity('Manila');
      }

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
      List<Map<String, dynamic>> lowStockList = [];

      for (final product in products) {
        final qty = (product['available_quantity'] as num?)?.toDouble() ?? 0.0;
        if (qty <= 0) {
          outOfStockCount++;
          lowStockList.add(Map<String, dynamic>.from(product));
        } else if (qty < 5) {
          lowStockCount++;
          lowStockList.add(Map<String, dynamic>.from(product));
        } else {
          inStockCount++;
        }
      }
      
      final totalInventory = inStockCount + lowStockCount + outOfStockCount;
      List<double> inventoryData = [inStockCount.toDouble(), lowStockCount.toDouble(), outOfStockCount.toDouble()];
      if (totalInventory == 0) {
        inventoryData = [1.0, 0.0, 0.0];
      }

      if (mounted) {
        setState(() {
          _farmerName = name.isEmpty ? 'Farmer' : name;
          _activeListings = products.where((p) => (p['available_quantity'] ?? 0) > 0).length;
          _pendingOrders = pending;
          _weeklyRevenue = revenue;
          _recentOrders = List<Map<String, dynamic>>.from(orders.take(6));
          _lowStockProducts = lowStockList;
          _salesData = salesLast7Days;
          _inventoryData = inventoryData;
          _farmerRating = rating;
          _farmerReviews = '$reviews Reviews';
          _farmLatitude = finalLat;
          _farmLongitude = finalLon;
          _farmLocationName = finalLocName;
          _weatherData = weather;
          _isLoadingWeather = false;
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
    if (_showWeatherPage) {
      return Scaffold(
        backgroundColor: const Color(0xFF070E1B),
        body: _buildWeatherRadarPage(),
      );
    }

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
                  ? _buildDashboardSkeleton()
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
                      duration: const Duration(milliseconds: 300),
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
              onTap: () => widget.onNavigate(5),
              child: Container(
                width: (isMobile || isCompact) ? 38 : 46,
                height: (isMobile || isCompact) ? 38 : 46,
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
                  size: (isMobile || isCompact) ? 20 : 24,
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

  Widget _buildDashboardSkeleton() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 40),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header shimmer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppShimmerLoader.rectangle(width: isMobile ? 180 : 320, height: 32, borderRadius: 8),
                    const SizedBox(height: 12),
                    AppShimmerLoader.rectangle(width: isMobile ? 220 : 450, height: 16, borderRadius: 6),
                  ],
                ),
              ),
              if (!isMobile) ...[
                AppShimmerLoader.rectangle(width: 150, height: 48, borderRadius: 12),
                const SizedBox(width: 16),
                AppShimmerLoader.rectangle(width: 200, height: 60, borderRadius: 16),
              ],
            ],
          ),
          SizedBox(height: isMobile ? 24 : 40),
          
          // Metrics Row Shimmer
          if (isMobile)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(child: AppShimmerLoader.rectangle(height: 120, borderRadius: 24)),
                    const SizedBox(width: 12),
                    Expanded(child: AppShimmerLoader.rectangle(height: 120, borderRadius: 24)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: AppShimmerLoader.rectangle(height: 120, borderRadius: 24)),
                    const SizedBox(width: 12),
                    Expanded(child: AppShimmerLoader.rectangle(height: 120, borderRadius: 24)),
                  ],
                ),
              ],
            )
          else
            Row(
              children: List.generate(4, (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 3 ? 0 : 24),
                  child: AppShimmerLoader.rectangle(height: 140, borderRadius: 24),
                ),
              )),
            ),
          SizedBox(height: isMobile ? 24 : 40),
          
          // Insights Shimmer
          if (isMobile)
            Column(
              children: [
                AppShimmerLoader.rectangle(height: 300, borderRadius: 28),
                const SizedBox(height: 24),
                AppShimmerLoader.rectangle(height: 300, borderRadius: 28),
              ],
            )
          else
            Row(
              children: [
                Expanded(flex: 2, child: AppShimmerLoader.rectangle(height: 400, borderRadius: 28)),
                const SizedBox(width: 40),
                Expanded(flex: 1, child: AppShimmerLoader.rectangle(height: 400, borderRadius: 28)),
              ],
            ),
          SizedBox(height: isMobile ? 24 : 40),
          
          // Activity Shimmer
          if (isMobile)
            AppShimmerLoader.rectangle(height: 250, borderRadius: 28)
          else
            Row(
              children: [
                Expanded(flex: 2, child: AppShimmerLoader.rectangle(height: 300, borderRadius: 28)),
                const SizedBox(width: 40),
                Expanded(flex: 1, child: AppShimmerLoader.rectangle(height: 300, borderRadius: 28)),
              ],
            ),
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
            _buildActivityAndAlertsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;
    final isTablet = sw >= 650 && sw < 1100;

    final headerText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Storefront Active · ${_farmLocationName ?? 'Local Farm'}',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Welcome back, $_farmerName! 🌾',
          style: GoogleFonts.plusJakartaSans(
            fontSize: isMobile ? 24 : (isTablet ? 28 : 34),
            fontWeight: FontWeight.w900,
            color: _dark,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Manage your farm's performance, products, and order fulfillments in real-time.",
          style: GoogleFonts.inter(
            fontSize: isMobile ? 13 : 15,
            color: _muted,
            fontWeight: FontWeight.w400,
            height: 1.3,
          ),
        ),
      ],
    );

    Widget weatherWidget;
    if (_isLoadingWeather || _weatherData == null) {
      weatherWidget = AppShimmerLoader.rectangle(width: 260, height: 80, borderRadius: 20);
    } else {
      final data = _weatherData!;
      final temp = data.temperature.toStringAsFixed(0);
      final desc = data.description;
      final wind = data.windSpeed.toStringAsFixed(1);
      final humidity = data.humidity.toStringAsFixed(0);
      final feelsLike = data.feelsLike.toStringAsFixed(0);
      final isSunny = desc.toLowerCase().contains('sun') || desc.toLowerCase().contains('clear');

      weatherWidget = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _showWeatherDetailsModal(data),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isSunny ? _accent : const Color(0xFF3B82F6)).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSunny ? Icons.wb_sunny_rounded : Icons.cloud_rounded,
                    color: isSunny ? _accent : const Color(0xFF3B82F6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$desc · $temp°C',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Feels $feelsLike°C',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.air_rounded, size: 12, color: _muted),
                        const SizedBox(width: 3),
                        Text(
                          '$wind m/s',
                          style: GoogleFonts.inter(fontSize: 11, color: _muted, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.water_drop_outlined, size: 12, color: _muted),
                        const SizedBox(width: 3),
                        Text(
                          '$humidity%',
                          style: GoogleFonts.inter(fontSize: 11, color: _muted, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Text(
                              'Radar',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF3B82F6),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF3B82F6)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final actionButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: () => widget.onNavigate(1),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Product'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: _openVoucherManager,
          icon: const Icon(Icons.confirmation_number_outlined, size: 16),
          label: const Text('Manage Vouchers'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _dark,
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerText,
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: actionButtons,
          ),
          const SizedBox(height: 14),
          weatherWidget,
        ],
      );
    }

    if (isTablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerText,
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              actionButtons,
              weatherWidget,
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: headerText),
        const SizedBox(width: 20),
        actionButtons,
        const SizedBox(width: 16),
        weatherWidget,
      ],
    );
  }

  void _showWeatherDetailsModal(WeatherData? data) {
    setState(() {
      _showWeatherPage = true;
    });
  }

  Widget _buildWeatherRadarPage() {
    return WebWeatherRadarScreen(
      weatherData: _weatherData,
      farmLatitude: _farmLatitude,
      farmLongitude: _farmLongitude,
      farmLocationName: _farmLocationName,
      onBack: () => setState(() => _showWeatherPage = false),
    );
  }

  Future<void> _openVoucherManager() async {
    final voucherService = VoucherService();
    final currentUserId = AuthService().userId;
    bool isSaving = false;
    bool isLoadingList = true;
    List<Map<String, dynamic>> vouchers = [];
    int activeTab = 0;

    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController();
    final valueController = TextEditingController();
    final minSpendController = TextEditingController();
    final maxDiscountController = TextEditingController();
    final limitController = TextEditingController(text: '100');
    String discountType = 'flat';
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 30));

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> loadList() async {
              setModalState(() => isLoadingList = true);
              try {
                final list = await voucherService.getFarmerVouchers(currentUserId);
                setModalState(() {
                  vouchers = list;
                  isLoadingList = false;
                });
              } catch (_) {
                setModalState(() => isLoadingList = false);
              }
            }

            if (isLoadingList && activeTab == 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) => loadList());
            }

            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              setModalState(() => isSaving = true);
              try {
                await voucherService.createVoucher(
                  farmerId: currentUserId,
                  code: codeController.text,
                  discountType: discountType,
                  discountValue: double.parse(valueController.text),
                  minSpend: double.parse(minSpendController.text),
                  maxDiscount: maxDiscountController.text.isNotEmpty 
                      ? double.parse(maxDiscountController.text)
                      : null,
                  usageLimit: int.parse(limitController.text),
                  startDate: startDate,
                  endDate: endDate,
                );
                
                codeController.clear();
                valueController.clear();
                minSpendController.clear();
                maxDiscountController.clear();
                limitController.text = '100';
                
                setModalState(() {
                  activeTab = 0;
                  isLoadingList = true;
                  isSaving = false;
                });
              } catch (e) {
                setModalState(() => isSaving = false);
                if (!dialogCtx.mounted) return;
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  SnackBar(content: Text('Failed to create voucher: $e')),
                );
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
              contentPadding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
              actionsPadding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_rounded,
                      color: _primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voucher Manager',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage store vouchers & customer discount codes',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setModalState(() => activeTab = 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: activeTab == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: activeTab == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.style_outlined, size: 14, color: activeTab == 0 ? _primary : _muted),
                                const SizedBox(width: 6),
                                Text(
                                  'Vouchers List (${vouchers.length})',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: activeTab == 0 ? FontWeight.w800 : FontWeight.w600,
                                    color: activeTab == 0 ? _dark : _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setModalState(() => activeTab = 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: activeTab == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: activeTab == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.add_circle_outline_rounded, size: 14, color: activeTab == 1 ? _primary : _muted),
                                const SizedBox(width: 6),
                                Text(
                                  'Create New',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: activeTab == 1 ? FontWeight.w800 : FontWeight.w600,
                                    color: activeTab == 1 ? _dark : _muted,
                                  ),
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
              content: SizedBox(
                width: 640,
                height: 460,
                child: activeTab == 0
                    ? (isLoadingList
                        ? const Center(child: CircularProgressIndicator(color: _primary))
                        : (vouchers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(22),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: const Icon(
                                        Icons.confirmation_number_outlined,
                                        size: 42,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No store vouchers created yet',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: _dark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Click "Create New" to add promotional codes for your shop.',
                                      style: GoogleFonts.inter(
                                        color: _muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: vouchers.length,
                                itemBuilder: (context, index) {
                                  final voucher = vouchers[index];
                                  final code = voucher['code']?.toString() ?? 'VOUCHER';
                                  final dynamic rawVal = voucher['discount_percentage'] ??
                                      voucher['discount_value'] ??
                                      voucher['discount_amount'];
                                  final double discVal = rawVal != null ? (rawVal as num).toDouble() : 0.0;
                                  final String type = voucher['discount_type']?.toString() ?? 'flat';
                                  final dynamic rawMin = voucher['min_spend'];
                                  final double minSpend = rawMin != null ? (rawMin as num).toDouble() : 0.0;
                                  final int limit = (voucher['usage_limit'] as num?)?.toInt() ?? 100;
                                  final int used = (voucher['used_count'] as num?)?.toInt() ?? 0;
                                  final String? dateStr = voucher['valid_until']?.toString() ?? voucher['end_date']?.toString();
                                  final String endStr = dateStr != null
                                      ? DateFormat('yMMMd').format(DateTime.tryParse(dateStr) ?? DateTime.now().add(const Duration(days: 30)))
                                      : 'No Expiry';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                        // Left discount ticket block with ticket style
                                        Container(
                                          width: 120,
                                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: _primary.withValues(alpha: 0.07),
                                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                                            border: const Border(
                                              right: BorderSide(color: Color(0xFFE2E8F0), style: BorderStyle.solid),
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                type == 'flat'
                                                    ? '₱${discVal.toStringAsFixed(0)}'
                                                    : '${discVal.toStringAsFixed(0)}%',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 20,
                                                  color: _primary,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'OFF',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 9.5,
                                                  color: _primary,
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Right details block
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(14),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFDCFCE7),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        code,
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: 13,
                                                          color: _primaryDark,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFF1F5F9),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        minSpend > 0
                                                            ? 'Min. Spend ₱${minSpend.toStringAsFixed(0)}'
                                                            : 'No Min. Spend',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: _muted,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.event_available_rounded, size: 13, color: Colors.grey),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Valid until $endStr',
                                                      style: GoogleFonts.inter(fontSize: 11.5, color: _muted),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.people_outline_rounded, size: 13, color: Colors.grey),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Claimed $used / $limit times',
                                                      style: GoogleFonts.inter(fontSize: 11.5, color: _muted),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(right: 14),
                                          child: IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                            tooltip: 'Delete Voucher',
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.red.withValues(alpha: 0.06),
                                              padding: const EdgeInsets.all(8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () async {
                                              final voucherId = voucher['voucher_id']?.toString() ?? voucher['id']?.toString();
                                              if (voucherId != null) {
                                                await voucherService.deleteVoucher(voucherId);
                                                loadList();
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )))
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.lightbulb_outline_rounded, color: _primary, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Configure discount value and rules. Vouchers are automatically displayed on your store profile page and product details pages.',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: _muted,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: codeController,
                                      textCapitalization: TextCapitalization.characters,
                                      style: GoogleFonts.inter(fontSize: 13.5, color: _dark),
                                      decoration: InputDecoration(
                                        labelText: 'Voucher Promo Code',
                                        hintText: 'e.g. HARVEST50',
                                        prefixIcon: const Icon(Icons.label_outline_rounded, size: 18),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      ),
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: discountType,
                                      decoration: InputDecoration(
                                        labelText: 'Discount Type',
                                        prefixIcon: const Icon(Icons.style_outlined, size: 18),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'flat', child: Text('Flat Discount (₱)')),
                                        DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setModalState(() => discountType = val);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: valueController,
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.inter(fontSize: 13.5, color: _dark),
                                      decoration: InputDecoration(
                                        labelText: discountType == 'flat' ? 'Discount Value (₱)' : 'Discount Value (%)',
                                        hintText: discountType == 'flat' ? '50' : '10',
                                        prefixIcon: Icon(
                                          discountType == 'flat' ? Icons.payments_outlined : Icons.percent_rounded,
                                          size: 18,
                                        ),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      ),
                                      validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required number' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: TextFormField(
                                      controller: minSpendController,
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.inter(fontSize: 13.5, color: _dark),
                                      decoration: InputDecoration(
                                        labelText: 'Min. Spend (₱)',
                                        hintText: '100',
                                        prefixIcon: const Icon(Icons.shopping_bag_outlined, size: 18),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      ),
                                      validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required number' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: maxDiscountController,
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.inter(fontSize: 13.5, color: _dark),
                                      decoration: InputDecoration(
                                        labelText: 'Max Discount Limit (₱)',
                                        hintText: 'Optional',
                                        prefixIcon: const Icon(Icons.money_off_rounded, size: 18),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: TextFormField(
                                      controller: limitController,
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.inter(fontSize: 13.5, color: _dark),
                                      decoration: InputDecoration(
                                        labelText: 'Total Quantity Limit',
                                        hintText: '100',
                                        prefixIcon: const Icon(Icons.onetwothree_rounded, size: 18),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      ),
                                      validator: (v) => (v == null || int.tryParse(v) == null) ? 'Required integer' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: endDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: _primary,
                                            onPrimary: Colors.white,
                                            onSurface: _dark,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setModalState(() => endDate = picked);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.date_range_rounded, color: _primary, size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Expiration Date',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: _muted,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              DateFormat('yMMMd').format(endDate),
                                              style: GoogleFonts.inter(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: _dark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogCtx).pop(),
                  child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _muted)),
                ),
                if (activeTab == 1)
                  ElevatedButton(
                    onPressed: isSaving ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isSaving ? 'Creating...' : 'Create Voucher',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    valueController.dispose();
    minSpendController.dispose();
    maxDiscountController.dispose();
    limitController.dispose();
  }

  Widget _buildMetricsRow() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;
    final isTablet = sw >= 650 && sw < 1100;

    final metrics = [
      (
        'Pending Orders',
        '$_pendingOrders',
        _pendingOrders > 0 ? '$_pendingOrders require fulfillment' : 'All orders fulfilled',
        Icons.shopping_bag_outlined,
        const Color(0xFF3B82F6),
        () => widget.onNavigate(2),
        _pendingOrders > 0 ? 'Needs Action' : 'Clear',
        _pendingOrders > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      ),
      (
        'Active Listings',
        '$_activeListings',
        'Storefront live products',
        Icons.inventory_2_outlined,
        _primary,
        () => widget.onNavigate(1),
        'Live',
        _primary,
      ),
      (
        'Total Revenue',
        _currencyFormat.format(_weeklyRevenue),
        '7-day sales: ${_currencyFormat.format(_salesData.fold(0.0, (a, b) => a + b))}',
        Icons.trending_up_rounded,
        const Color(0xFF8B5CF6),
        null,
        'Earnings',
        const Color(0xFF8B5CF6),
      ),
      (
        'Farmer Rating',
        '$_farmerRating ★',
        '$_farmerReviews · Verified Seller',
        Icons.star_rounded,
        const Color(0xFFF59E0B),
        null,
        'Top Rated',
        const Color(0xFFF59E0B),
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildAnimatedMetricCard(
                  0,
                  metrics[0].$1,
                  metrics[0].$2,
                  metrics[0].$3,
                  metrics[0].$4,
                  metrics[0].$5,
                  onTap: metrics[0].$6,
                  badgeText: metrics[0].$7,
                  badgeColor: metrics[0].$8,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnimatedMetricCard(
                  1,
                  metrics[1].$1,
                  metrics[1].$2,
                  metrics[1].$3,
                  metrics[1].$4,
                  metrics[1].$5,
                  onTap: metrics[1].$6,
                  badgeText: metrics[1].$7,
                  badgeColor: metrics[1].$8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAnimatedMetricCard(
                  2,
                  metrics[2].$1,
                  metrics[2].$2,
                  metrics[2].$3,
                  metrics[2].$4,
                  metrics[2].$5,
                  onTap: metrics[2].$6,
                  badgeText: metrics[2].$7,
                  badgeColor: metrics[2].$8,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnimatedMetricCard(
                  3,
                  metrics[3].$1,
                  metrics[3].$2,
                  metrics[3].$3,
                  metrics[3].$4,
                  metrics[3].$5,
                  onTap: metrics[3].$6,
                  badgeText: metrics[3].$7,
                  badgeColor: metrics[3].$8,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (isTablet) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10, bottom: 14),
                  child: _buildAnimatedMetricCard(
                    0,
                    metrics[0].$1,
                    metrics[0].$2,
                    metrics[0].$3,
                    metrics[0].$4,
                    metrics[0].$5,
                    onTap: metrics[0].$6,
                    badgeText: metrics[0].$7,
                    badgeColor: metrics[0].$8,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 14),
                  child: _buildAnimatedMetricCard(
                    1,
                    metrics[1].$1,
                    metrics[1].$2,
                    metrics[1].$3,
                    metrics[1].$4,
                    metrics[1].$5,
                    onTap: metrics[1].$6,
                    badgeText: metrics[1].$7,
                    badgeColor: metrics[1].$8,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _buildAnimatedMetricCard(
                    2,
                    metrics[2].$1,
                    metrics[2].$2,
                    metrics[2].$3,
                    metrics[2].$4,
                    metrics[2].$5,
                    onTap: metrics[2].$6,
                    badgeText: metrics[2].$7,
                    badgeColor: metrics[2].$8,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: _buildAnimatedMetricCard(
                    3,
                    metrics[3].$1,
                    metrics[3].$2,
                    metrics[3].$3,
                    metrics[3].$4,
                    metrics[3].$5,
                    onTap: metrics[3].$6,
                    badgeText: metrics[3].$7,
                    badgeColor: metrics[3].$8,
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
            padding: EdgeInsets.only(right: index == 3 ? 0 : 20),
            child: _buildAnimatedMetricCard(
              index,
              metrics[index].$1,
              metrics[index].$2,
              metrics[index].$3,
              metrics[index].$4,
              metrics[index].$5,
              onTap: metrics[index].$6,
              badgeText: metrics[index].$7,
              badgeColor: metrics[index].$8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedMetricCard(
    int i,
    String label,
    String value,
    String subtitle,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
    String? badgeText,
    Color? badgeColor,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 650;
    final isHovered = _hoveredMetrics.contains(i);

    return FadeTransition(
      opacity: _metricControllers[i],
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(parent: _metricControllers[i], curve: Curves.easeOutQuart),
        ),
        child: MouseRegion(
          cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hoveredMetrics.add(i)),
          onExit: (_) => setState(() => _hoveredMetrics.remove(i)),
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              transform: Matrix4.translationValues(0, isHovered ? -4 : 0, 0),
              padding: EdgeInsets.all(isMobile ? 16 : 22),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isHovered ? color.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
                  width: isHovered ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isHovered ? color.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.03),
                    blurRadius: isHovered ? 24 : 10,
                    offset: Offset(0, isHovered ? 8 : 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: isMobile ? 18 : 22),
                      ),
                      if (badgeText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? color).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: badgeColor ?? color,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 22 : 28,
                        fontWeight: FontWeight.w900,
                        color: _dark,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: color,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 11,
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
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;
    final total7Days = _salesData.fold<double>(0, (sum, item) => sum + item);

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      height: 420,
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales Performance',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.w900,
                        color: _dark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '7-Day Total: ${_currencyFormat.format(total7Days)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.show_chart_rounded, size: 16, color: _primary),
                    const SizedBox(width: 6),
                    Text(
                      'Last 7 Days',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: InteractiveLineChart(
              values: _salesData,
              labels: List.generate(7, (i) {
                final day = DateTime.now().subtract(Duration(days: 6 - i));
                return DateFormat('E').format(day);
              }),
              lineColor: _primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryDistribution() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      height: 420,
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Inventory Split',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.w900,
                  color: _dark,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18, color: _muted),
                tooltip: 'Refresh',
                onPressed: _loadDashboardData,
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: MiniDonutChart(
              size: isMobile ? 170 : 190,
              values: _inventoryData,
              colors: const [_primary, _secondary, _accent],
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_activeListings',
                    style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w900, color: _dark),
                  ),
                  Text('Total Items', style: GoogleFonts.inter(fontSize: 11, color: _muted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const Spacer(),
          _buildLegendRow('In Stock', _primary, _inventoryLegend1),
          const SizedBox(height: 10),
          _buildLegendRow('Low Stock (<5kg)', _secondary, _inventoryLegend2),
          const SizedBox(height: 10),
          _buildLegendRow('Out of Stock', _accent, _inventoryLegend3),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String label, Color color, String percent) {
    return Row(
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.inter(fontSize: 12.5, color: _dark, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(percent, style: GoogleFonts.inter(fontSize: 12.5, color: _muted, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildActivityAndAlertsGrid() {
    final sw = MediaQuery.of(context).size.width;
    final isMobileOrTablet = sw < 1000;

    if (isMobileOrTablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecentActivitySection(),
          const SizedBox(height: 24),
          _buildLowStockAlertsCard(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildRecentActivitySection(),
        ),
        const SizedBox(width: 32),
        Expanded(
          flex: 1,
          child: _buildLowStockAlertsCard(),
        ),
      ],
    );
  }

  Widget _buildLowStockAlertsCard() {
    final isMobile = MediaQuery.of(context).size.width < 650;
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Stock Alerts',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => widget.onNavigate(1),
                child: Text('Manage Stock', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _primary, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_lowStockProducts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: _primary, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      'All products fully stocked!',
                      style: GoogleFonts.inter(color: _dark, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lowStockProducts.length > 4 ? 4 : _lowStockProducts.length,
              separatorBuilder: (context, i) => Divider(color: const Color(0xFFF1F5F9), height: 18),
              itemBuilder: (context, i) {
                final item = _lowStockProducts[i];
                final name = item['name'] ?? 'Product';
                final qty = (item['available_quantity'] as num?)?.toInt() ?? 0;
                final isOutOfStock = qty <= 0;
                return Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOutOfStock ? Colors.redAccent : Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _dark, fontSize: 13.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isOutOfStock ? Colors.red.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isOutOfStock ? 'OUT OF STOCK' : '$qty left',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isOutOfStock ? Colors.redAccent : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    final isMobile = MediaQuery.of(context).size.width < 650;

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Orders',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.w900,
                  color: _dark,
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigate(2),
                child: Text('View All Orders', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _primary, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_recentOrders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Icon(Icons.inbox_outlined, size: 36, color: _muted),
                    const SizedBox(height: 8),
                    Text('No customer orders yet.', style: GoogleFonts.inter(color: _muted, fontSize: 14)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentOrders.length,
              separatorBuilder: (context, i) => Divider(color: const Color(0xFFF1F5F9), height: 24),
              itemBuilder: (context, i) => _buildActivityRow(_recentOrders[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityRow(Map<String, dynamic> o) {
    final status = o['status']?.toString().toUpperCase() ?? 'PENDING';
    Color statusColor = const Color(0xFFF59E0B);
    if (status == 'DELIVERED') statusColor = _primary;
    if (status == 'CANCELLED') statusColor = Colors.redAccent;
    
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            status == 'DELIVERED' ? Icons.check_circle_rounded : Icons.local_shipping_outlined,
            color: statusColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order from ${o['customerName'] ?? 'Customer'}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _dark, fontSize: 14),
              ),
              const SizedBox(height: 3),
              Text(
                o['items'] ?? 'Processing order items...',
                style: GoogleFonts.inter(color: _muted, fontSize: 12.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              o['total'] ?? '₱0',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: _dark, fontSize: 15),
            ),
            const SizedBox(height: 3),
            Text(
              o['timeAgo'] ?? 'Recently',
              style: GoogleFonts.inter(color: _muted, fontSize: 11.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}

class InteractiveLineChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final Color lineColor;

  const InteractiveLineChart({
    super.key,
    required this.values,
    required this.labels,
    this.lineColor = const Color(0xFF10B981),
  });

  @override
  State<InteractiveLineChart> createState() => _InteractiveLineChartState();
}

class _InteractiveLineChartState extends State<InteractiveLineChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _hoveredIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = widget.values.fold<double>(0, (prev, e) => e > prev ? e : prev);
    final displayMax = maxVal == 0 ? 100.0 : maxVal * 1.2;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight - 30; // 30 for labels

            return Stack(
              children: [
                // Custom Paint Smooth Line Graph
                CustomPaint(
                  size: Size(w, h),
                  painter: _SalesLineGraphPainter(
                    values: widget.values,
                    maxVal: displayMax,
                    color: widget.lineColor,
                    progress: _controller.value,
                    hoveredIndex: _hoveredIndex,
                  ),
                ),
                // Mouse region detection for points
                Positioned.fill(
                  child: Row(
                    children: List.generate(widget.values.length, (i) {
                      return Expanded(
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = i),
                          onExit: (_) => setState(() => _hoveredIndex = -1),
                          child: const SizedBox.expand(),
                        ),
                      );
                    }),
                  ),
                ),
                // X-Axis Labels at the bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(widget.labels.length, (i) {
                      final isHovered = _hoveredIndex == i;
                      return SizedBox(
                        width: w / widget.labels.length,
                        child: Text(
                          widget.labels[i],
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isHovered ? FontWeight.w800 : FontWeight.w600,
                            color: isHovered ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SalesLineGraphPainter extends CustomPainter {
  final List<double> values;
  final double maxVal;
  final Color color;
  final double progress;
  final int hoveredIndex;

  _SalesLineGraphPainter({
    required this.values,
    required this.maxVal,
    required this.color,
    required this.progress,
    required this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    // Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.5)
      ..strokeWidth = 1;

    for (int i = 0; i <= 3; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = List.generate(values.length, (i) {
      final x = values.length == 1 ? size.width / 2 : (size.width / (values.length - 1)) * i;
      final valRatio = (values[i] / maxVal) * progress;
      final y = size.height - (size.height * valRatio);
      return Offset(x, y);
    });

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);

      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
      fillPath.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Draw Data Point Circles
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final isHovered = hoveredIndex == i;

      canvas.drawCircle(pt, isHovered ? 8 : 5, Paint()..color = Colors.white);
      canvas.drawCircle(pt, isHovered ? 6 : 3.5, Paint()..color = color);

      if (isHovered && values[i] > 0) {
        final valText = '₱${values[i].toStringAsFixed(0)}';
        final textSpan = TextSpan(
          text: valText,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
        );
        final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
        textPainter.layout();

        final tooltipRect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(pt.dx, pt.dy - 22), width: textPainter.width + 12, height: textPainter.height + 8),
          const Radius.circular(8),
        );
        canvas.drawRRect(tooltipRect, Paint()..color = const Color(0xFF0F172A));
        textPainter.paint(canvas, Offset(pt.dx - textPainter.width / 2, pt.dy - 22 - textPainter.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SalesLineGraphPainter oldDelegate) => true;
}
