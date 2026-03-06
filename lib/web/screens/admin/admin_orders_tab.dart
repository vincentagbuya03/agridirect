import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin_service.dart';

/// Admin Orders Tab - View and manage all platform orders
class AdminOrdersTab extends StatefulWidget {
  final AdminService adminService;

  const AdminOrdersTab({
    super.key,
    required this.adminService,
  });

  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab> {
  late Future<List<Map<String, dynamic>>> _ordersFuture;
  int _currentPage = 0;

  static const Color _primary = Color(0xFF13EC5B);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _warning = Color(0xFFFFA500);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _darker = Color(0xFF0F172A);
  static const Color _cardBg = Color(0xFF1E293B);
  static const Color _surface = Color(0xFF334155);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFF334155);

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    _ordersFuture = widget.adminService.getAllOrders(page: _currentPage);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return _primary;
      case 'PENDING':
        return _warning;
      case 'CANCELLED':
        return _danger;
      case 'SHIPPED':
        return _secondary;
      default:
        return _muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: _darker,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Performance',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _primary));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load orders',
                        style: GoogleFonts.poppins(color: _danger)),
                  );
                }

                final orders = snapshot.data ?? [];

                if (orders.isEmpty) {
                  return Center(
                    child: Text('No orders found',
                        style: GoogleFonts.poppins(color: _muted)),
                  );
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
                        children: [
                          for (final order in orders)
                            _OrderCard(
                              order: order,
                              getStatusColor: _getStatusColor,
                              onReload: () => setState(() => _loadOrders()),
                            ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    // Pagination
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPaginationBtn(
                          icon: Icons.arrow_back,
                          label: 'Previous',
                          onPressed: _currentPage > 0
                              ? () => setState(() { _currentPage--; _loadOrders(); })
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _border),
                          ),
                          child: Text('Page ${_currentPage + 1}',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
                        ),
                        const SizedBox(width: 16),
                        _buildPaginationBtn(
                          icon: Icons.arrow_forward,
                          label: 'Next',
                          onPressed: orders.length >= 20
                              ? () => setState(() { _currentPage++; _loadOrders(); })
                              : null,
                        ),
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

  Widget _buildPaginationBtn({required IconData icon, required String label, VoidCallback? onPressed}) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? _cardBg : _surface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: enabled ? _border : _surface),
        ),
        child: Row(
          children: [
            Icon(icon, color: enabled ? Colors.white : _muted, size: 16),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.poppins(color: enabled ? Colors.white : _muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _OrdersTable extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final Color Function(String) getStatusColor;
  final VoidCallback onReload;

  static const Color _primary = Color(0xFF13EC5B);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _cardBg = Color(0xFF1E293B);
  static const Color _border = Color(0xFF334155);
  static const Color _muted = Color(0xFF64748B);

  const _OrdersTable({
    required this.orders,
    required this.getStatusColor,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
            dataRowColor: WidgetStateProperty.all(_cardBg),
            dividerThickness: 0.5,
            columns: [
              DataColumn(label: Text('Order #', style: GoogleFonts.poppins(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Customer', style: GoogleFonts.poppins(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Total', style: GoogleFonts.poppins(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Status', style: GoogleFonts.poppins(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Date', style: GoogleFonts.poppins(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Actions', style: GoogleFonts.poppins(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
            ],
            rows: [
              for (final order in orders)
                DataRow(
                  cells: [
                    DataCell(Text(order['order_number'] ?? '-',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 13))),
                    DataCell(Text(order['customer_name'] ?? 'Unknown',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 13))),
                    DataCell(Text('₱${order['total'] ?? 0}',
                        style: GoogleFonts.poppins(color: _primary, fontSize: 13, fontWeight: FontWeight.w600))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: getStatusColor(order['status'] ?? '').withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: getStatusColor(order['status'] ?? '').withOpacity(0.3)),
                        ),
                        child: Text(
                          order['status'] ?? 'UNKNOWN',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: getStatusColor(order['status'] ?? ''),
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(_formatDate(order['created_at']),
                        style: GoogleFonts.poppins(color: _muted, fontSize: 13))),
                    DataCell(
                      Row(
                        children: [
                          _buildActionIcon(Icons.visibility, _secondary, () => _showOrderDetails(context, order)),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _muted.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.more_vert, color: _muted, size: 16),
                            ),
                            color: const Color(0xFF1E293B),
                            onSelected: (value) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: _primary,
                                  content: Text('Order $value',
                                      style: GoogleFonts.poppins(color: const Color(0xFF0F172A))),
                                ),
                              );
                              onReload();
                            },
                            itemBuilder: (BuildContext context) => [
                              PopupMenuItem(value: 'approved',
                                  child: Text('Approve', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13))),
                              PopupMenuItem(value: 'shipped',
                                  child: Text('Mark Shipped', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13))),
                              PopupMenuItem(value: 'delivered',
                                  child: Text('Mark Delivered', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13))),
                              PopupMenuItem(value: 'cancelled',
                                  child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFFEF4444), fontSize: 13))),
                            ],
                          ),
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

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return '-';
    }
  }

  void _showOrderDetails(BuildContext context, Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Order #${order['order_number']}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Customer', order['customer_name'] ?? 'Unknown'),
            _detailRow('Total', '₱${order['total'] ?? 0}'),
            _detailRow('Status', order['status'] ?? 'Unknown'),
            _detailRow('Date', _formatDate(order['created_at'])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins(color: _muted)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label: ', style: GoogleFonts.poppins(color: _muted, fontSize: 13)),
          Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Color Function(String) getStatusColor;
  final VoidCallback onReload;

  static const Color _primary = Color(0xFF13EC5B);
  static const Color _cardBg = Color(0xFF1E293B);
  static const Color _border = Color(0xFF334155);
  static const Color _muted = Color(0xFF64748B);

  const _OrderCard({
    required this.order,
    required this.getStatusColor,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = getStatusColor(order['status'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
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
                    Text('Order #${order['order_number'] ?? '-'}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(order['customer_name'] ?? 'Unknown',
                        style: GoogleFonts.poppins(fontSize: 12, color: _muted)),
                  ],
                ),
              ),
              Text('₱${order['total'] ?? 0}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: _primary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(order['status'] ?? 'UNKNOWN',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
              ),
              Text(_formatDate(order['created_at']),
                  style: GoogleFonts.poppins(fontSize: 12, color: _muted)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showActions(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Update Status', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return '-';
    }
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: _muted, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          _buildSheetTile(context, Icons.check_circle, 'Approve', _primary, 'Order approved'),
          _buildSheetTile(context, Icons.local_shipping, 'Mark Shipped', const Color(0xFF06B6D4), 'Order marked as shipped'),
          _buildSheetTile(context, Icons.done_all, 'Mark Delivered', _primary, 'Order marked as delivered'),
          _buildSheetTile(context, Icons.cancel, 'Cancel Order', const Color(0xFFEF4444), 'Order cancelled'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSheetTile(BuildContext context, IconData icon, String title, Color color, String msg) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: color, content: Text(msg, style: GoogleFonts.poppins(color: const Color(0xFF0F172A)))),
        );
        onReload();
      },
    );
  }
}
