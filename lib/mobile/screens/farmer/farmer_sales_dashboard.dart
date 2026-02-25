import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

/// Farmer Sales Dashboard
class FarmerSalesDashboard extends StatelessWidget {
  const FarmerSalesDashboard({super.key});

  static const Color primary = Color(0xFF13EC5B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetricsGrid(),
                    const SizedBox(height: 16),
                    _buildSalesAnalytics(),
                    const SizedBox(height: 16),
                    _buildWeatherAlert(),
                    const SizedBox(height: 24),
                    _buildAICropInsights(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          ClipOval(
            child: CachedNetworkImage(
              imageUrl:
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuA7SO8J3CebwmP_4K0nwWhDkMsWISrTpnfbOkYJ79_ZiTCLVxdvX_FJArJ1xwYsLAJx8gW_Wtk3xValGb9mDShlpRvdPIMoD9UGWJ9LwNRlF0vvmsKesjK6liNaDGy7C5HGWdOAE1hEPvF3UTq81_QK7QkgKAAMQgeICa4pykDXTF8JYtnrFYPiavyC7N-wkK4pGMGQJcdoyKpRglzbFXWGqTdoa3xP-Bm86BGxFKlWg21Mbw-FylTfHiJeJMKgLbfSJr8MhPFg1zqB',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(width: 48, height: 48, color: Colors.grey[200]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning,',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                Text(
                  'Farmer Marcus',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: Colors.grey[600],
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
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

  Widget _buildMetricsGrid() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
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
                      'REVENUE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+5.2%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '\$1,240',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'VS. YESTERDAY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
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
                      'LISTINGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '0%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '14',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ACTIVE ITEMS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalesAnalytics() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
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
                'SALES ANALYTICS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up,
                      size: 12,
                      color: Color(0xFF13EC5B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '15%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '\$8,420',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: CustomPaint(
              size: const Size(double.infinity, 140),
              painter: _AnalyticsChartPainter(primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun',
              ])
                Text(
                  day,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE5D0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD0B3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFA500),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weather Alert',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9D4D0D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Strong frost warning tonight for Zone B. Prepare protective covers.',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF9D4D0D),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.close, color: Color(0xFF9D4D0D), size: 20),
        ],
      ),
    );
  }

  Widget _buildAICropInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AI Crop Insights',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Refresh',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInsightCard(
          icon: Icons.trending_up_rounded,
          iconColor: const Color(0xFF7C3AED),
          title: 'Market Demand Surge',
          description:
              'Local demand for organic bell peppers has spiked by 22% this week. Consider prioritizing this harvest.',
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          icon: Icons.water_drop_rounded,
          iconColor: primary,
          title: 'Irrigation Optimization',
          description:
              'Soil sensors in Sector 4 show 15% lower moisture. Automating irrigation at 9 PM is recommended.',
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsChartPainter extends CustomPainter {
  final Color color;
  _AnalyticsChartPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final fillPath = Path();

    final points = [
      Offset(size.width * 0.1, size.height * 0.6),
      Offset(size.width * 0.25, size.height * 0.3),
      Offset(size.width * 0.4, size.height * 0.6),
      Offset(size.width * 0.55, size.height * 0.4),
      Offset(size.width * 0.7, size.height * 0.5),
      Offset(size.width * 0.85, size.height * 0.15),
      Offset(size.width, size.height * 0.25),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final cp1x = points[i].dx + (points[i + 1].dx - points[i].dx) / 2;
      final cp1y = points[i].dy;
      final cp2x = points[i].dx + (points[i + 1].dx - points[i].dx) / 2;
      final cp2y = points[i + 1].dy;
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, points[i + 1].dx, points[i + 1].dy);
      fillPath.cubicTo(
        cp1x,
        cp1y,
        cp2x,
        cp2y,
        points[i + 1].dx,
        points[i + 1].dy,
      );
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
