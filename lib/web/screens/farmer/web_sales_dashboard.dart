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
import '../../widgets/web_hamburger_menu_button.dart';
import '../../../shared/services/commerce/voucher_service.dart';


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

    final navItems = ['Dashboard', 'Products', 'Orders', 'Community', 'Pre-Orders'];
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
              onTap: () => widget.onNavigate(5),
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
            WebHamburgerMenuButton(
              currentIndex: widget.currentIndex,
              onNavigate: widget.onNavigate,
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openVoucherManager,
                  icon: const Icon(Icons.confirmation_number_outlined),
                  label: const Text('Manage Vouchers'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
        ElevatedButton.icon(
          onPressed: _openVoucherManager,
          icon: const Icon(Icons.confirmation_number_outlined),
          label: const Text('Manage Vouchers'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(width: 16),
        weatherWidget,
      ],
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
                borderRadius: BorderRadius.circular(28),
              ),
              titlePadding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
              contentPadding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
              actionsPadding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_rounded,
                      color: _primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voucher Manager',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage store vouchers & discount codes',
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setModalState(() => activeTab = 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: activeTab == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
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
                            child: Text(
                              'Vouchers List',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: activeTab == 0 ? FontWeight.w700 : FontWeight.w600,
                                color: activeTab == 0 ? _dark : _muted,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setModalState(() => activeTab = 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: activeTab == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
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
                            child: Text(
                              'Create New',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: activeTab == 1 ? FontWeight.w700 : FontWeight.w600,
                                color: activeTab == 1 ? _dark : _muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                height: 440,
                child: activeTab == 0
                    ? (isLoadingList
                        ? const Center(child: CircularProgressIndicator(color: _primary))
                        : (vouchers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFFF1F5F9)),
                                      ),
                                      child: const Icon(
                                        Icons.confirmation_number_outlined,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      'No vouchers created yet',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: _dark,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Click "Create New" to add discount vouchers for your shop.',
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
                                  final code = voucher['code'] ?? '';
                                  final discVal = (voucher['discount_value'] as num).toDouble();
                                  final type = voucher['discount_type'] ?? '';
                                  final minSpend = (voucher['min_spend'] as num).toDouble();
                                  final limit = voucher['usage_limit'] ?? 0;
                                  final used = voucher['used_count'] ?? 0;
                                  final endStr = DateFormat('yMMMd').format(DateTime.parse(voucher['end_date']));

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.02),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Left discount ticket block
                                        Container(
                                          width: 120,
                                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: _primary.withValues(alpha: 0.06),
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
                                                type == 'flat' ? '₱${discVal.toStringAsFixed(0)}' : '${discVal.toStringAsFixed(0)}%',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 22,
                                                  color: _primary,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'OFF',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 10,
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
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      code,
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 15,
                                                        color: _dark,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFF1F5F9),
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      child: Text(
                                                        'Min. Spend ₱${minSpend.toStringAsFixed(0)}',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 10,
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
                                                    const Icon(Icons.history_toggle_off_rounded, size: 13, color: Colors.grey),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Expires $endStr',
                                                      style: GoogleFonts.inter(fontSize: 11, color: _muted),
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
                                                      style: GoogleFonts.inter(fontSize: 11, color: _muted),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(right: 12),
                                          child: IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                            tooltip: 'Delete Voucher',
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.red.withValues(alpha: 0.05),
                                              padding: const EdgeInsets.all(10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: () async {
                                              await voucherService.deleteVoucher(voucher['voucher_id']);
                                              loadList();
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
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFF1F5F9)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.lightbulb_outline_rounded, color: _primary, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Configure discount value and rules. Vouchers are displayed on your store profile page and product details pages.',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: _muted,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: codeController,
                                      textCapitalization: TextCapitalization.characters,
                                      decoration: InputDecoration(
                                        labelText: 'Voucher Code',
                                        hintText: 'e.g. FARM50',
                                        prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                      ),
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: discountType,
                                      decoration: InputDecoration(
                                        labelText: 'Discount Type',
                                        prefixIcon: const Icon(Icons.style_outlined, size: 20),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: valueController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: discountType == 'flat' ? 'Discount Value (₱)' : 'Discount Value (%)',
                                        hintText: discountType == 'flat' ? '50' : '10',
                                        prefixIcon: Icon(
                                          discountType == 'flat' ? Icons.payments_outlined : Icons.percent_rounded,
                                          size: 20,
                                        ),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                      ),
                                      validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required number' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: minSpendController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Min. Spend (₱)',
                                        hintText: '100',
                                        prefixIcon: const Icon(Icons.shopping_bag_outlined, size: 20),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                      ),
                                      validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required number' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: maxDiscountController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Max Discount Limit (₱)',
                                        hintText: 'Leave empty for no limit',
                                        prefixIcon: const Icon(Icons.money_off_rounded, size: 20),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: limitController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Total Quantity Limit',
                                        hintText: '100',
                                        prefixIcon: const Icon(Icons.onetwothree_rounded, size: 20),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                      ),
                                      validator: (v) => (v == null || int.tryParse(v) == null) ? 'Required integer' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
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
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade400),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.date_range_rounded, color: _primary, size: 20),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Expiration Date',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w500,
                                                      color: _muted,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    DateFormat('yMMMd').format(endDate),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
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
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Close'),
                ),
                if (activeTab == 1)
                  FilledButton(
                    onPressed: isSaving ? null : submit,
                    child: Text(isSaving ? 'Saving...' : 'Create Voucher'),
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
              Expanded(
                child: Text(
                  'Sales Performance',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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
              labels: List.generate(7, (i) {
                final day = DateTime.now().subtract(Duration(days: 6 - i));
                return DateFormat('E').format(day);
              }),
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
