import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/animated_components.dart';

/// Web Sales Dashboard — Modern Design
/// Professional analytics dashboard for farmers
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
  // Modern colors
  static const Color _primary = Color(0xFF16A34A);
  static const Color _success = Color(0xFF06B6D4);
  static const Color _warning = Color(0xFFF59E0B);

  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _surface = Color(0xFFFAFAFA);
  static const Color _white = Color(0xFFFFFFFF);

  // ─── Animations ───
  late AnimationController _fadeInController;
  late List<AnimationController> _metricControllers;
  final Set<int> _hoveredMetrics = {};
  int _hoveredNav = -1;

  @override
  void initState() {
    super.initState();
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    // Create controllers for 4 metric cards
    _metricControllers = List.generate(
      4,
      (i) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    // Stagger the animations
    Future.delayed(const Duration(milliseconds: 300), () {
      for (int i = 0; i < _metricControllers.length; i++) {
        Future.delayed(Duration(milliseconds: 100 * i), () {
          if (mounted) {
            _metricControllers[i].forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    for (final controller in _metricControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          // Subtle dot pattern background
          Positioned.fill(
            child: CustomPaint(
              painter: DotPatternPainter(opacity: 0.04, color: const Color(0xFF10B981)),
            ),
          ),
          // Subtle floating particles
          const Positioned.fill(
            child: FloatingParticles(
              count: 10,
              maxSize: 2,
              color: Color(0xFF34D399),
              height: 1200,
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                _buildNavBar(),
                _buildTopBar(),
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGreeting(),
                      const SizedBox(height: 32),
                      _buildMetricsRow(),
                      const SizedBox(height: 32),
                      _buildChartsRow(),
                      const SizedBox(height: 32),
                      _buildRecentOrdersSection(),
                      const SizedBox(height: 40),
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

  // ─── Site Header ───
  Widget _buildNavBar() {
    final navItems = ['Home', 'Shop', 'Farmers', 'About'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.eco_rounded, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 8),
              Text(
                'AgriDirect',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
            ],
          ),
          const SizedBox(width: 40),
          ...List.generate(navItems.length, (i) {
            final isHovered = _hoveredNav == i;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hoveredNav = i),
              onExit: (_) => setState(() => _hoveredNav = -1),
              child: GestureDetector(
                onTap: () => widget.onNavigate(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(
                    navItems[i],
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isHovered ? _primary : _dark,
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: const Icon(Icons.shopping_cart_outlined, size: 22, color: _dark),
          ),
          const SizedBox(width: 20),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Sign Up',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Top Bar ───
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      decoration: BoxDecoration(
        color: _white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Text(
            'Dashboard',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, size: 16, color: _muted),
                const SizedBox(width: 8),
                Text(
                  'This Week',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.notifications_none, size: 20, color: _dark),
          ),
        ],
      ),
    );
  }

  // ─── Greeting ───
  Widget _buildGreeting() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good Morning, John',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Here's what's happening with your farm today.",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _muted,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _success.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _success,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.water_drop, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weather Alert',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _success),
                  ),
                  Text(
                    'Heavy rain expected tomorrow',
                    style: GoogleFonts.inter(fontSize: 11, color: _muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Metrics Row ───
  Widget _buildMetricsRow() {
    final metrics = [
      ('PENDING ORDERS', '12', 'Orders to fulfill', Icons.shopping_cart_outlined, _primary),
      ('ACTIVE LISTINGS', '48', 'Products live', Icons.inventory_2_outlined, _success),
      ('WEEKLY REVENUE', '₱4.2K', '+20% from last week', Icons.trending_up_rounded, _warning),
      ('FARM RATING', '4.8', '120 reviews', Icons.star_rounded, Colors.amber),
    ];

    return Row(
      children: List.generate(
        metrics.length,
        (index) => Expanded(
          child: _buildAnimatedMetricCard(
            index,
            metrics[index].$1,
            metrics[index].$2,
            metrics[index].$3,
            metrics[index].$4,
            metrics[index].$5,
          ),
        ),
      ).expand((w) => [w, const SizedBox(width: 20)]).toList()..removeLast(),
    );
  }

  Widget _buildAnimatedMetricCard(
    int index,
    String label,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _metricControllers[index], curve: Curves.easeInOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _metricControllers[index], curve: Curves.easeOutCubic),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hoveredMetrics.add(index)),
          onExit: (_) => setState(() => _hoveredMetrics.remove(index)),
          child: _buildMetricCard(
            label,
            value,
            subtitle,
            icon,
            color,
            _hoveredMetrics.contains(index),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    bool isHovered,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHovered ? color : _border,
          width: isHovered ? 2 : 1,
        ),
        boxShadow: isHovered
            ? [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: color == _warning || color == Colors.amber
                      ? AgriColors.goldGradient
                      : LinearGradient(
                          colors: [color, color.withOpacity(0.7)],
                        ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const Icon(Icons.more_horiz, size: 18, color: _muted),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Charts Row ───
  Widget _buildChartsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _buildSalesChart(),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 2,
          child: _buildRevenueBreakdown(),
        ),
      ],
    );
  }

  Widget _buildSalesChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL SALES',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₱4,250',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.trending_up, size: 14, color: _primary),
                            const SizedBox(width: 4),
                            Text(
                              '+20%',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'This Week',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Animated bar chart
          SizedBox(
            height: 200,
            child: MiniBarChart(
              values: const [650, 480, 820, 560, 930, 780, 1100],
              labels: const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'],
              barColor: _primary,
              height: 160,
              barWidth: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueBreakdown() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REVENUE BREAKDOWN',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          // Animated donut chart
          Center(
            child: MiniDonutChart(
              values: const [45, 35, 20],
              colors: const [_primary, _success, _warning],
              size: 160,
              strokeWidth: 20,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '₱4.2K',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  Text(
                    'total',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildLegendItem('Vegetables', _primary, '45%'),
          const SizedBox(height: 12),
          _buildLegendItem('Fruits', _success, '35%'),
          const SizedBox(height: 12),
          _buildLegendItem('Other', _warning, '20%'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String percentage) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _dark,
            ),
          ),
        ),
        Text(
          percentage,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
      ],
    );
  }

  // ─── Recent Orders ───
  Widget _buildRecentOrdersSection() {
    final orders = [
      ('Maria Santos', 'Tomatoes · 5kg', '₱600', 'Pending', _warning),
      ('Jose Cruz', 'Spinach · 2 bunches', '₱90', 'Shipped', _success),
      ('Ana Reyes', 'Mangoes · 3kg', '₱540', 'Delivered', _primary),
      ('Carlos Tan', 'Carrots · 4kg', '₱240', 'Pending', _warning),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              Text(
                'View all',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              columns: [
                DataColumn(
                  label: Text(
                    'Customer',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Product',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Amount',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Status',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),
              ],
              rows: orders
                  .map((o) => DataRow(
                        cells: [
                          DataCell(
                            Text(
                              o.$1,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _dark,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              o.$2,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _muted,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              o.$3,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _dark,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: o.$5.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                o.$4,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: o.$5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
