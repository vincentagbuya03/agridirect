import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin_service.dart';

/// Admin Orders Tab - View and manage all platform orders (Modern White)
class AdminOrdersTab extends StatefulWidget {
  final AdminService adminService;

  const AdminOrdersTab({super.key, required this.adminService});

  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab> {
  late Future<List<Map<String, dynamic>>> _ordersFuture;
  int _currentPage = 0;

  // Modern light theme colors
  static const Color _primary = Color(0xFF10B981);
  static const Color _secondary = Color(0xFF3B82F6);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _background = Color(0xFFFAFAFA);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _muted = Color(0xFF64748B);
  static const Color _text = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    _ordersFuture = widget.adminService.getAllOrders(page: _currentPage);
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return _primary;
      case 'PENDING':
        return _warning;
      case 'CANCELLED':
        return _danger;
      case 'SHIPPED':
        return _secondary;
      case 'PROCESSING':
        return _secondary;
      default:
        return _muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: _background,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
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
                      'Sales & Orders',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    Text(
                      'Monitor platform transactions and fulfillment',
                      style: GoogleFonts.inter(fontSize: 13, color: _muted),
                    ),
                  ],
                ),
                if (!isMobile)
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _loadOrders()),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _text,
                      elevation: 0,
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: _primary),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _buildErrorState();
                }

                final orders = snapshot.data ?? [];

                if (orders.isEmpty) {
                  return _buildEmptyState();
                }

                return Column(
                  children: [
                    if (!isMobile)
                      _OrdersTable(
                        orders: orders,
                        getStatusColor: _getStatusColor,
                        onReload: () => setState(() => _loadOrders()),
                      )
                    else
                      Column(
                        children: orders
                            .map(
                              (order) => _OrderCard(
                                order: order,
                                getStatusColor: _getStatusColor,
                                onReload: () => setState(() => _loadOrders()),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 32),
                    _buildPagination(orders.length),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _currentPage > 0
              ? () => setState(() {
                  _currentPage--;
                  _loadOrders();
                })
              : null,
          icon: const Icon(Icons.chevron_left),
          style: IconButton.styleFrom(
            backgroundColor: _card,
            side: const BorderSide(color: _border),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          'Page ${_currentPage + 1}',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _text),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: count >= 20
              ? () => setState(() {
                  _currentPage++;
                  _loadOrders();
                })
              : null,
          icon: const Icon(Icons.chevron_right),
          style: IconButton.styleFrom(
            backgroundColor: _card,
            side: const BorderSide(color: _border),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: _danger),
          const SizedBox(height: 16),
          Text(
            'Failed to load orders',
            style: GoogleFonts.inter(
              color: _danger,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(onPressed: _loadOrders, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: _muted.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: GoogleFonts.inter(
              color: _muted,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersTable extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final Color Function(String) getStatusColor;
  final VoidCallback onReload;

  const _OrdersTable({
    required this.orders,
    required this.getStatusColor,
    required this.onReload,
  });

  static const Color _primary = Color(0xFF10B981);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _muted = Color(0xFF64748B);
  static const Color _text = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingRowHeight: 56,
          headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
          dividerThickness: 0.5,
          columns: [
            DataColumn(
              label: Text(
                'ORDER ID',
                style: GoogleFonts.inter(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'CUSTOMER',
                style: GoogleFonts.inter(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'TOTAL',
                style: GoogleFonts.inter(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'STATUS',
                style: GoogleFonts.inter(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'DATE',
                style: GoogleFonts.inter(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'ACTIONS',
                style: GoogleFonts.inter(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          rows: orders.map((order) {
            final customerName = order['users']?['name'] ?? 'Unknown';
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    order['order_number'] ?? '-',
                    style: GoogleFonts.inter(
                      color: _text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(
                  Text(customerName, style: GoogleFonts.inter(color: _text)),
                ),
                DataCell(
                  Text(
                    '₱${order['total'] ?? 0}',
                    style: GoogleFonts.inter(
                      color: _primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(
                  _StatusBadge(
                    status: order['status'],
                    color: getStatusColor(order['status'] ?? ''),
                  ),
                ),
                DataCell(
                  Text(
                    _formatDate(order['created_at']),
                    style: GoogleFonts.inter(color: _muted, fontSize: 13),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded, color: _muted),
                    onPressed: () {}, // Detail view coming soon
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return '-';
    }
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Color Function(String) getStatusColor;
  final VoidCallback onReload;

  const _OrderCard({
    required this.order,
    required this.getStatusColor,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'PENDING';
    final customerName = order['users']?['name'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order['order_number'] ?? '-',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              _StatusBadge(status: status, color: getStatusColor(status)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 14,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                customerName,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₱${order['total'] ?? 0}',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('Details')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String? status;
  final Color color;
  const _StatusBadge({this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status?.toUpperCase() ?? 'PENDING',
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
