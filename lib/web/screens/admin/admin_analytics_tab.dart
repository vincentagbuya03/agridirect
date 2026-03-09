import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin_service.dart';

/// Admin Analytics Tab - Enterprise Dashboard Overview matching reference design
class AdminAnalyticsTab extends StatefulWidget {
  final AdminService adminService;

  const AdminAnalyticsTab({
    super.key,
    required this.adminService,
  });

  @override
  State<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<AdminAnalyticsTab> {
  late Future<Map<String, dynamic>?> _statsFuture;

  // Enterprise dark theme colors
  static const Color _primary = Color(0xFF16A34A);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _warning = Color(0xFFFFA500);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _darker = Color(0xFF111827);
  static const Color _surface = Color(0xFF334155);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _cardBg = Color(0xFF1E293B);
  static const Color _border = Color(0xFF334155);

  @override
  void initState() {
    super.initState();
    _statsFuture = widget.adminService.getDashboardStats();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      color: _darker,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(isMobile),
            const SizedBox(height: 24),
            FutureBuilder<Map<String, dynamic>?>(
              future: _statsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingCards(isMobile);
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return _buildErrorState();
                }
                final stats = snapshot.data!;
                return Column(
                  children: [
                    _buildStatCardsRow(stats, isMobile),
                    const SizedBox(height: 24),
                    if (isMobile)
                      Column(
                        children: [
                          _buildFinancialPerformance(),
                          const SizedBox(height: 24),
                          _buildSystemEvents(),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildFinancialPerformance()),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: _buildSystemEvents()),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search, color: _muted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Global search for farmers, orders, or SKUs...',
                      hintStyle: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isMobile) ...[
          const SizedBox(width: 16),
          _buildIconButton(Icons.thumb_up_outlined),
          const SizedBox(width: 8),
          _buildIconButton(Icons.help_outline),
          const SizedBox(width: 16),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.add, color: Color(0xFF111827), size: 18),
                const SizedBox(width: 8),
                Text('Quick Action',
                    style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF111827),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIconButton(IconData icon) {
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Icon(icon, color: _muted, size: 20),
    );
  }

  Widget _buildStatCardsRow(Map<String, dynamic> stats, bool isMobile) {
    final totalRevenue = stats['total_orders'] != null
        ? (stats['total_orders'] as num) * 33.4
        : 0.0;
    final completedOrders = stats['total_orders'] ?? 0;
    final verifiedFarmers = stats['total_farmers'] ?? 0;
    final pendingReports = stats['pending_reports'] ?? 0;

    final cards = [
      _EnterpriseStatCard(
        icon: Icons.account_balance_wallet_outlined,
        iconColor: _primary,
        title: 'GROSS REVENUE',
        value: '₱${_formatNumber(totalRevenue)}',
        badge: '↗ 12.5%',
        badgeColor: _primary,
      ),
      _EnterpriseStatCard(
        icon: Icons.shopping_cart_outlined,
        iconColor: _secondary,
        title: 'COMPLETED ORDERS',
        value: _formatWholeNumber(completedOrders),
        badge: '↗ 8.2%',
        badgeColor: _secondary,
      ),
      _EnterpriseStatCard(
        icon: Icons.groups_outlined,
        iconColor: _primary,
        title: 'VERIFIED FARMERS',
        value: _formatWholeNumber(verifiedFarmers),
        badgeText: 'Live',
        badgeColor: _primary,
      ),
      _EnterpriseStatCard(
        icon: Icons.assignment_outlined,
        iconColor: _warning,
        title: 'AUDIT QUEUE',
        value: '$pendingReports',
        badgeText: 'Action',
        badgeColor: _danger,
      ),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: cards,
      );
    }

    return Row(
      children: cards
          .map((card) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: card,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildFinancialPerformance() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Financial Performance',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Year 2024',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _muted)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.download, color: _muted, size: 16),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Monthly Revenue', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _muted)),
              const SizedBox(width: 16),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: _muted.withOpacity(0.5), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Previous Period', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _muted)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(height: 220, child: _buildBarChart()),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG'];
    final values = [15.0, 25.0, 84.2, 40.0, 30.0, 45.0, 35.0, 20.0];
    final maxVal = 100.0;
    final yLabels = ['₱100k', '₱75k', '₱50k', '₱25k', '0'];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 50,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: yLabels
                          .map((label) => Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _muted)))
                          .toList(),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(months.length, (i) {
                        final ratio = values[i] / maxVal;
                        final isHighlighted = i == 2;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (isHighlighted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(6)),
                                child: Text('₱${values[i]}k',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
                              ),
                            if (isHighlighted) const SizedBox(height: 4),
                            Container(
                              width: 24,
                              height: (constraints.maxHeight - 30) * ratio,
                              decoration: BoxDecoration(
                                color: isHighlighted ? _primary : _surface.withOpacity(0.6),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: months.asMap().entries.map((e) => Text(e.value,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: e.key == 2 ? Colors.white : _muted,
                        fontWeight: e.key == 2 ? FontWeight.w600 : FontWeight.normal))).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSystemEvents() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('System Events',
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Icon(Icons.filter_list, color: _muted, size: 20),
            ],
          ),
          const SizedBox(height: 24),
          _buildEventItem(
            icon: Icons.person_add,
            iconBg: _primary.withOpacity(0.15),
            iconColor: _primary,
            title: 'New Farmer Signup',
            time: '2m ago',
            description: 'Highland Organics submitted credentials for review.',
            dotColor: _primary,
          ),
          const SizedBox(height: 20),
          _buildEventItem(
            icon: Icons.warning_rounded,
            iconBg: _danger.withOpacity(0.15),
            iconColor: _danger,
            title: 'Violation Detected',
            time: '15m ago',
            description: 'Price anomaly detected on "Premium Arabica" listing.',
            dotColor: _danger,
            showActions: true,
          ),
          const SizedBox(height: 20),
          _buildEventItem(
            icon: Icons.inventory_2,
            iconBg: _secondary.withOpacity(0.15),
            iconColor: _secondary,
            title: 'Bulk Order Placed',
            time: '45m ago',
            description: 'Order #8842: 2.5 Tons of Sweet Potato confirmed.',
            dotColor: _secondary,
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('VIEW FULL ACTIVITY LOGS',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: _muted, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String time,
    required String description,
    required Color dotColor,
    bool showActions = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  Text(time, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _muted)),
                ],
              ),
              const SizedBox(height: 4),
              Text(description, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _muted)),
              if (showActions) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildActionBtn('Action', _primary, const Color(0xFF111827)),
                    const SizedBox(width: 8),
                    _buildActionBtn('Dismiss', _surface, _muted),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
      ],
    );
  }

  Widget _buildActionBtn(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  Widget _buildLoadingCards(bool isMobile) {
    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: isMobile ? 1.4 : 2.0,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(
        4,
        (_) => Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: const Center(child: CircularProgressIndicator(color: _primary)),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, color: _danger, size: 48),
            const SizedBox(height: 16),
            Text('Failed to load statistics', style: GoogleFonts.plusJakartaSans(color: _danger, fontSize: 14)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _statsFuture = widget.adminService.getDashboardStats();
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: const Color(0xFF111827)),
              child: Text('Retry', style: GoogleFonts.plusJakartaSans()),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return value.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    }
    return value.toStringAsFixed(2);
  }

  String _formatWholeNumber(num value) {
    return value.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _EnterpriseStatCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String? badge;
  final String? badgeText;
  final Color badgeColor;

  const _EnterpriseStatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.badge,
    this.badgeText,
    required this.badgeColor,
  });

  @override
  State<_EnterpriseStatCard> createState() => _EnterpriseStatCardState();
}

class _EnterpriseStatCardState extends State<_EnterpriseStatCard> {
  bool _isHovered = false;

  static const Color _cardBg = Color(0xFF1E293B);
  static const Color _border = Color(0xFF334155);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? widget.badgeColor.withOpacity(0.5) : _border,
          ),
          boxShadow: _isHovered
              ? [BoxShadow(color: widget.badgeColor.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 24),
                ),
                if (widget.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.badgeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(widget.badge!,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: widget.badgeColor)),
                  ),
                if (widget.badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.badgeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: widget.badgeColor.withOpacity(0.3)),
                    ),
                    child: Text(widget.badgeText!,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: widget.badgeColor)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(widget.title,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: _muted, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(widget.value, style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
