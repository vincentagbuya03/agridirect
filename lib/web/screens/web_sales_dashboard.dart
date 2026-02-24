import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/data/app_data.dart';

/// Web-only Sales Dashboard — modern analytics dashboard design.
/// Completely separate UI from the mobile dashboard.
class WebSalesDashboard extends StatelessWidget {
  const WebSalesDashboard({super.key});

  static const Color _primary = Color(0xFF10B981);
  static const Color _accent = Color(0xFF13EC5B);
  static const Color _blue = Color(0xFF3B82F6);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGreeting(),
                  const SizedBox(height: 28),
                  _buildMetricCards(),
                  const SizedBox(height: 28),
                  _buildMainRow(),
                  const SizedBox(height: 28),
                  _buildAISuggestion(),
                  const SizedBox(height: 28),
                  _buildQuickActionsRow(),
                  const SizedBox(height: 40),
                ],
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
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Text(
            'Dashboard',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const Spacer(),
          // Date range pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: _muted),
                const SizedBox(width: 8),
                Text('This Week', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _muted),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Notification
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Stack(
              children: [
                const Center(child: Icon(Icons.notifications_outlined, size: 20, color: _dark)),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
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

  // ─── Greeting ───
  Widget _buildGreeting() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _primary, width: 2),
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: AppData.farmerAvatarUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey[200]),
              errorWidget: (_, __, ___) => const Icon(Icons.person),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good Morning, John',
              style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w800, color: _dark, letterSpacing: -0.5),
            ),
            const SizedBox(height: 2),
            Text(
              'Here\'s what\'s happening with your farm today.',
              style: GoogleFonts.manrope(fontSize: 14, color: _muted),
            ),
          ],
        ),
        const Spacer(),
        // Weather alert compact
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weather Alert', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: _blue)),
                  Text('Heavy rain expected', style: GoogleFonts.manrope(fontSize: 11, color: _muted)),
                ],
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded, size: 18, color: _muted),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Metric Cards ───
  Widget _buildMetricCards() {
    return Row(
      children: [
        Expanded(child: _buildMetricCard('PENDING ORDERS', '12', 'Orders to fulfill', Icons.shopping_cart_rounded, _primary)),
        const SizedBox(width: 20),
        Expanded(child: _buildMetricCard('ACTIVE LISTINGS', '48', 'Products live', Icons.inventory_2_rounded, _blue)),
        const SizedBox(width: 20),
        Expanded(child: _buildMetricCard('WEEKLY REVENUE', '₱4.2K', '+20% from last week', Icons.trending_up_rounded, _amber)),
        const SizedBox(width: 20),
        Expanded(child: _buildMetricCard('FARM RATING', '4.8', '120 reviews', Icons.star_rounded, const Color(0xFFF97316))),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              Icon(Icons.more_horiz_rounded, size: 18, color: _muted),
            ],
          ),
          const SizedBox(height: 16),
          Text(label, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w800, color: _dark, letterSpacing: -1)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.manrope(fontSize: 12, color: _muted)),
        ],
      ),
    );
  }

  // ─── Main Row: Chart + Recent Orders ───
  Widget _buildMainRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _buildSalesChart()),
        const SizedBox(width: 24),
        Expanded(flex: 2, child: _buildRecentOrders()),
      ],
    );
  }

  Widget _buildSalesChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                  Text('TOTAL SALES', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₱4,250', style: GoogleFonts.manrope(fontSize: 32, fontWeight: FontWeight.w800, color: _dark, letterSpacing: -1.5)),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.trending_up_rounded, size: 14, color: _primary),
                            const SizedBox(width: 4),
                            Text('+20%', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: _primary)),
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
                  border: Border.all(color: _border),
                ),
                child: Text('This Week', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: _dark)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 180,
            child: CustomPaint(
              size: const Size(double.infinity, 180),
              painter: _WebChartPainter(_primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'])
                Text(day, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: _muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrders() {
    final orders = [
      ('Maria Santos', 'Tomatoes · 5kg', '₱600', 'Pending', _amber),
      ('Jose Cruz', 'Spinach · 2 bunches', '₱90', 'Shipped', _blue),
      ('Ana Reyes', 'Mangoes · 3kg', '₱540', 'Delivered', _primary),
      ('Carlos Tan', 'Carrots · 4kg', '₱240', 'Pending', _amber),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Orders', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: _dark)),
              Text('View all', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: _primary)),
            ],
          ),
          const SizedBox(height: 20),
          ...orders.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          o.$1.split(' ').map((w) => w[0]).take(2).join(),
                          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: _dark),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.$1, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: _dark)),
                          Text(o.$2, style: GoogleFonts.manrope(fontSize: 12, color: _muted)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(o.$3, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: _dark)),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: o.$5.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(o.$4, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: o.$5)),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── AI Suggestion ───
  Widget _buildAISuggestion() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF064E3B), Color(0xFF065F46)],
        ),
      ),
      child: Row(
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
                        color: _accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.smart_toy_rounded, size: 14, color: _accent),
                          const SizedBox(width: 6),
                          Text('AI SMART SUGGESTION', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: _accent, letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Plant Lettuce Now — High demand predicted',
                  style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'High demand predicted for local markets next month. Expected ROI of +35% based on current market analysis.',
                  style: GoogleFonts.manrope(fontSize: 14, color: Colors.white.withValues(alpha: 0.7), height: 1.5),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF065F46),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('View Market Analysis', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.yard_rounded, size: 40, color: Colors.white.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  // ─── Quick Actions ───
  Widget _buildQuickActionsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('QUICK ACTIONS', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 0.8)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildActionCard(Icons.add_circle_rounded, 'Add Product', _primary)),
            const SizedBox(width: 16),
            Expanded(child: _buildActionCard(Icons.inventory_rounded, 'Manage Stock', _blue)),
            const SizedBox(width: 16),
            Expanded(child: _buildActionCard(Icons.analytics_rounded, 'View Analytics', _amber)),
            const SizedBox(width: 16),
            Expanded(child: _buildActionCard(Icons.local_shipping_rounded, 'Track Deliveries', const Color(0xFF8B5CF6))),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(IconData icon, String label, Color color) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: _dark),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chart Painter ───
class _WebChartPainter extends CustomPainter {
  final Color color;
  _WebChartPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(0, size.height * 0.75),
      Offset(size.width * 0.14, size.height * 0.30),
      Offset(size.width * 0.28, size.height * 0.50),
      Offset(size.width * 0.42, size.height * 0.20),
      Offset(size.width * 0.57, size.height * 0.35),
      Offset(size.width * 0.71, size.height * 0.15),
      Offset(size.width * 0.85, size.height * 0.25),
      Offset(size.width, size.height * 0.10),
    ];

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Path
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    final fillPath = Path()..moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final cp1x = points[i].dx + (points[i + 1].dx - points[i].dx) / 2;
      final cp1y = points[i].dy;
      final cp2x = points[i].dx + (points[i + 1].dx - points[i].dx) / 2;
      final cp2y = points[i + 1].dy;
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, points[i + 1].dx, points[i + 1].dy);
      fillPath.cubicTo(cp1x, cp1y, cp2x, cp2y, points[i + 1].dx, points[i + 1].dy);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Dots
    for (final p in points) {
      canvas.drawCircle(p, 4, Paint()..color = color);
      canvas.drawCircle(p, 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
