import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin_service.dart';

/// Admin Analytics Tab - Enterprise Dashboard Overview
class AdminAnalyticsTab extends StatefulWidget {
  final AdminService adminService;

  const AdminAnalyticsTab({super.key, required this.adminService});

  @override
  State<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

// Modern plain white theme colors
const Color _primary = Color(0xFF10B981);
const Color _primaryLight = Color(0xFF34D399);
const Color _secondary = Color(0xFF3B82F6);
const Color _warning = Color(0xFFF59E0B);
const Color _purple = Color(0xFF8B5CF6);
const Color _background = Color(0xFFFAFAFA); // Lighter background
const Color _card = Colors.white;
const Color _border = Color(0xFFE2E8F0);
const Color _text = Color(0xFF1E293B); // Darker text for white theme
const Color _muted = Color(0xFF64748B);

class _AdminAnalyticsTabState extends State<AdminAnalyticsTab> {
  late Future<Map<String, int>> _countsFuture;
  late Future<Map<String, dynamic>> _revenueFuture;
  late Future<List<Map<String, dynamic>>> _activityFuture;

  @override
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _countsFuture = widget.adminService.getDashboardCounts();
    _revenueFuture = widget.adminService.getRevenueAnalytics();
    _activityFuture = widget.adminService.getDashboardActivity();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1200;

    return Container(
      color: _background,
      child: RefreshIndicator(
        onRefresh: () async {
          setState(() => _loadData());
        },
        color: _primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Dashboard Overview',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              const SizedBox(height: 20),
              // Quick Stats
              FutureBuilder<Map<String, int>>(
                future: _countsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingStats(isMobile);
                  }
                  final counts = snapshot.data ?? {};
                  return _buildStatsGrid(counts, isMobile, isTablet);
                },
              ),
              const SizedBox(height: 20),
              // Revenue & Activity Row
              if (isMobile)
                Column(
                  children: [
                    _buildRevenueCard(),
                    const SizedBox(height: 20),
                    _buildQuickActionsCard(),
                    const SizedBox(height: 20),
                    _buildRecentActivityCard(),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildRevenueCard()),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _buildQuickActionsCard(),
                          const SizedBox(height: 20),
                          _buildRecentActivityCard(),
                        ],
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

  Widget _buildLoadingStats(bool isMobile) {
    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: isMobile ? 1.3 : 1.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(
        4,
        (_) => Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: _primary, strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    Map<String, int> counts,
    bool isMobile,
    bool isTablet,
  ) {
    final stats = [
      _StatData(
        icon: Icons.people_rounded,
        title: 'Total Users',
        value: '${counts['total_users'] ?? 0}',
        subtitle: '+12% this month',
        color: _secondary,
        trend: 12,
      ),
      _StatData(
        icon: Icons.agriculture_rounded,
        title: 'Active Farmers',
        value: '${counts['verified_farmers'] ?? 0}',
        subtitle: '${counts['total_farmers'] ?? 0} total',
        color: _primary,
        trend: 8,
      ),
      _StatData(
        icon: Icons.inventory_2_rounded,
        title: 'Products',
        value: '${counts['total_products'] ?? 0}',
        subtitle: 'Listed items',
        color: _purple,
        trend: 15,
      ),
      _StatData(
        icon: Icons.shopping_bag_rounded,
        title: 'Total Orders',
        value: '${counts['total_orders'] ?? 0}',
        subtitle: 'All time orders',
        color: _warning,
        trend: 23,
      ),
    ];

    return GridView.count(
      crossAxisCount: isMobile ? 1 : (isTablet ? 3 : 5),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isMobile ? 2.8 : (isTablet ? 2.0 : 2.4),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: stats.map((stat) => _StatCard(stat: stat)).toList(),
    );
  }

  Widget _buildRevenueCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenue Overview',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Platform sales performance',
                    style: GoogleFonts.inter(fontSize: 13, color: _muted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Text(
                      'This Year',
                      style: GoogleFonts.inter(fontSize: 13, color: _text),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _muted,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Revenue Stats
          FutureBuilder<Map<String, dynamic>>(
            future: _revenueFuture,
            builder: (context, snapshot) {
              final data = snapshot.data ?? {};
              final totalRevenue = (data['total_revenue'] ?? 0.0) as double;
              final completedRevenue =
                  (data['completed_revenue'] ?? 0.0) as double;

              return Column(
                children: [
                  Row(
                    children: [
                      _MiniStatCard(
                        label: 'Total Revenue',
                        value: '₱${_formatNumber(totalRevenue)}',
                        icon: Icons.account_balance_wallet_rounded,
                        color: _primary,
                      ),
                      const SizedBox(width: 16),
                      _MiniStatCard(
                        label: 'Completed',
                        value: '₱${_formatNumber(completedRevenue)}',
                        icon: Icons.check_circle_rounded,
                        color: _secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Chart placeholder
                  SizedBox(height: 200, child: _buildBarChart()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    final values = [35.0, 52.0, 78.0, 45.0, 89.0, 67.0];
    final maxVal = 100.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(months.length, (i) {
                  final ratio = values[i] / maxVal;
                  final isHighlighted = i == 4;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isHighlighted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '₱${values[i].toInt()}k',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          if (isHighlighted) const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            width: double.infinity,
                            height: (constraints.maxHeight - 40) * ratio,
                            decoration: BoxDecoration(
                              gradient: isHighlighted
                                  ? const LinearGradient(
                                      colors: [_primary, _primaryLight],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    )
                                  : null,
                              color: isHighlighted ? null : Color(0xFFF1F5F9),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: months
                  .asMap()
                  .entries
                  .map(
                    (e) => Expanded(
                      child: Center(
                        child: Text(
                          e.value,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: e.key == 4
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: e.key == 4 ? _text : _muted,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _text,
            ),
          ),
          const SizedBox(height: 16),
          _QuickActionTile(
            icon: Icons.person_add_rounded,
            title: 'Add User',
            color: _secondary,
            onTap: () {},
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.category_rounded,
            title: 'New Category',
            color: _purple,
            onTap: () {},
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.announcement_rounded,
            title: 'Send Notification',
            color: _warning,
            onTap: () {},
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.download_rounded,
            title: 'Export Report',
            color: _primary,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                'Recent Activity',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              Icon(Icons.more_horiz_rounded, color: _muted, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _activityFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primary,
                    ),
                  ),
                );
              }
              final activities = snapshot.data ?? [];
              if (activities.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No recent activity',
                      style: GoogleFonts.inter(color: _muted, fontSize: 13),
                    ),
                  ),
                );
              }
              return Column(
                children: activities
                    .map(
                      (activity) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ActivityItem(
                          icon: activity['icon'] as IconData,
                          iconBg: (activity['color'] as Color).withOpacity(
                            0.12,
                          ),
                          iconColor: activity['color'] as Color,
                          title: activity['title'] as String,
                          subtitle: activity['subtitle'] as String,
                          time: _getTimeAgo(activity['time'] as String),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text(
                'View All Activity',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(String timeStr) {
    try {
      final date = DateTime.parse(timeStr);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return 'Recent';
    }
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}

class _StatData {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final int trend;

  _StatData({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.trend,
  });
}

class _StatCard extends StatefulWidget {
  final _StatData stat;

  const _StatCard({required this.stat});

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? widget.stat.color.withOpacity(0.5) : _border,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? widget.stat.color.withOpacity(0.1)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.stat.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.stat.icon,
                    color: widget.stat.color,
                    size: 20,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.trending_up_rounded,
                        size: 14,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+${widget.stat.trend}%',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              widget.stat.value,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.stat.title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color.withOpacity(0.5),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: GoogleFonts.inter(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}
