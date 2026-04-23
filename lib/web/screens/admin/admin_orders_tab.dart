import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/admin/admin_service.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'admin_ui.dart';

class AdminOrdersTab extends StatefulWidget {
  final AdminService adminService;
  const AdminOrdersTab({super.key, required this.adminService});

  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab> {
  late Future<List<Map<String, dynamic>>> _ordersFuture;
  String _searchQuery = '';
  String _filterStatus = 'all'; 
  late VoidCallback _dataRefreshListener;

  @override
  void initState() {
    super.initState();
    _dataRefreshListener = () {
      if (!mounted) return;
      _loadData();
    };
    widget.adminService.dataVersionListenable.addListener(_dataRefreshListener);
    _loadData();
  }

  @override
  void dispose() {
    widget.adminService.dataVersionListenable.removeListener(_dataRefreshListener);
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _ordersFuture = widget.adminService.getAllOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: SingleChildScrollView(
        padding: AdminUi.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminHeroCard(
              useGradient: true,
              eyebrow: 'Commerce System',
              title: 'Order Management',
              description: 'Monitor marketplace transactions, oversee fulfillment, and analyze sales performance.',
              metrics: [
                AdminMiniMetric(label: 'Total Revenue', value: '₱428,210', icon: Icons.payments_rounded, light: true),
                AdminMiniMetric(label: 'Pending Orders', value: '24', icon: Icons.pending_actions_rounded, light: true),
                AdminMiniMetric(label: 'Sales Growth', value: '+18.4%', icon: Icons.trending_up_rounded, light: true),
              ],
              actions: [
                ElevatedButton.icon(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusMd),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Sync Transactions'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AdminUi.radiusLg,
                border: Border.all(color: AdminUi.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildToolbar(),
                  const Divider(height: 1, color: AdminUi.border),
                  _buildTableHeader(),
                  const Divider(height: 1, color: AdminUi.border),
                  _buildTableBody(),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildBottomInsights(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInsights() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            height: 180,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AdminUi.brand,
              borderRadius: AdminUi.radiusLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fulfillment Efficiency', style: AdminUi.title(size: 20, color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  'Current average fulfillment time is 4.2 hours. This is 12% faster than last month.',
                  style: AdminUi.body(size: 14, color: Colors.white.withValues(alpha: 0.8)),
                ),
                const Spacer(),
                Text('VIEW LOGISTICS DASHBOARD', style: AdminUi.label(size: 12, color: Colors.white, weight: FontWeight.w800)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Container(
            height: 180,
            padding: const EdgeInsets.all(32),
            decoration: AdminUi.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment Methods', style: AdminUi.title(size: 20)),
                const SizedBox(height: 16),
                _paymentStat('Credit/Debit Card', '68%', AdminUi.brand),
                const SizedBox(height: 12),
                _paymentStat('Digital Wallets', '32%', AdminUi.success),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentStat(String label, String value, Color color) {
    return Row(
      children: [
        Text(label, style: AdminUi.label(size: 14, color: AdminUi.textSecondary)),
        const Spacer(),
        Text(value, style: AdminUi.label(size: 14, color: color, weight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminUi.background,
                borderRadius: AdminUi.radiusMd,
              ),
              child: TextField(
                decoration: AdminUi.inputDecoration(
                  hintText: 'Search by Order ID or Buyer Name...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AdminUi.textMuted, size: 20),
                ).copyWith(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AdminUi.background,
              borderRadius: AdminUi.radiusMd,
            ),
            child: DropdownButton<String>(
              value: _filterStatus,
              underline: const SizedBox(),
              icon: const Icon(Icons.tune_rounded, size: 18, color: AdminUi.textSecondary),
              style: AdminUi.label(size: 13, color: AdminUi.textPrimary, weight: FontWeight.w700),
              onChanged: (v) => setState(() => _filterStatus = v ?? 'all'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Orders')),
                DropdownMenuItem(value: 'pending', child: Text('Pending Review')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: AdminUi.sidebarBg.withValues(alpha: 0.05),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          _headerCell('Transaction ID', flex: 2),
          _headerCell('Fulfillment', flex: 1),
          _headerCell('Amount', flex: 1),
          _headerCell('Date', flex: 1),
          _headerCell('Actions', flex: 1, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: AdminUi.label(size: 11, color: AdminUi.textMuted, weight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTableBody() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: AppShimmerLoader(color: AdminUi.brand)),
          );
        }

        var orders = snapshot.data ?? [];
        
        // Filtering
        if (_searchQuery.isNotEmpty) {
          orders = orders.where((o) {
            final id = (o['order_id'] ?? '').toString().toLowerCase();
            return id.contains(_searchQuery);
          }).toList();
        }
        if (_filterStatus != 'all') {
          orders = orders.where((o) => o['status'] == _filterStatus).toList();
        }

        if (orders.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text('No orders found.', style: AdminUi.body(color: AdminUi.textMuted)),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: orders.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: AdminUi.border),
          itemBuilder: (context, index) => _buildRow(orders[index]),
        );
      },
    );
  }

  Widget _buildRow(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final orderId = order['order_id'] ?? 'Unknown';
    final amount = order['total_amount'] ?? 0;
    final date = order['created_at'] != null 
        ? DateFormat('MMM d, yyyy HH:mm').format(DateTime.parse(order['created_at']))
        : 'Unknown';

    Color statusColor;
    if (status == 'completed') {
      statusColor = AdminUi.success;
    } else if (status == 'cancelled') {
      statusColor = AdminUi.danger;
    } else {
      statusColor = AdminUi.warning;
    }

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {},
        hoverColor: AdminUi.panelAlt,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AdminUi.brandSoft,
                        borderRadius: AdminUi.radiusMd,
                      ),
                      child: const Icon(Icons.receipt_rounded, size: 20, color: AdminUi.brand),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${orderId.toString().substring(0, 8).toUpperCase()}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AdminUi.textPrimary,
                          ),
                        ),
                        Text(
                          'Payment via Card',
                          style: AdminUi.body(size: 12, color: AdminUi.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: AdminUi.radiusFull,
                      border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: AdminUi.label(size: 10, color: statusColor, weight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text('₱${amount.toStringAsFixed(2)}', style: AdminUi.label(size: 13, color: AdminUi.textPrimary)),
              ),
              Expanded(
                flex: 1,
                child: Text(date, style: AdminUi.body(size: 13, color: AdminUi.textSecondary)),
              ),
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      color: AdminUi.textSecondary,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
