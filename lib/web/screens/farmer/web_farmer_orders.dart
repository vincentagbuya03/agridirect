import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../widgets/animated_components.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/models/order/order_model.dart';
import '../../../mobile/screens/farmer/farmer_order_details_screen.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../widgets/web_consumer_nav_bar.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_routes.dart';

class WebFarmerOrders extends StatefulWidget {
  final Function(int) onNavigate;
  final int currentIndex;

  const WebFarmerOrders({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
  });

  @override
  State<WebFarmerOrders> createState() => _WebFarmerOrdersState();
}

class _WebFarmerOrdersState extends State<WebFarmerOrders> with TickerProviderStateMixin {
  late AnimationController _fadeInController;
  int _hoveredNav = -1;
  String _searchQuery = '';
  String _selectedStatus = 'ALL';
  final List<String> _statusFilters = ['ALL', 'PENDING', 'SHIPPED', 'DELIVERED', 'CANCELLED'];

  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _surface = Color(0xFFFAFAFA);

  @override
  void initState() {
    super.initState();
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;

    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DotPatternPainter(opacity: 0.03, color: const Color(0xFF10B981)),
            ),
          ),
          Column(
            children: [
              _buildNavBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(isMobile ? 16 : 40, 0, isMobile ? 16 : 40, 40),
                  child: FadeTransition(
                    opacity: _fadeInController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        SizedBox(height: isMobile ? 20 : 32),
                        _buildOrderTable(),
                      ],
                    ),
                  ),
                ),
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

    final navItems = ['Dashboard', 'Products', 'Orders', 'Community'];
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
              onTap: () => widget.onNavigate(4),
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
            PopupMenuButton<int>(
              icon: const Icon(Icons.menu, color: _primary),
              tooltip: '',
              onSelected: (index) {
                widget.onNavigate(index);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 0,
                  child: Row(
                    children: [
                      Icon(Icons.dashboard_rounded, color: widget.currentIndex == 0 ? _primary : _muted, size: 20),
                      const SizedBox(width: 8),
                      Text('Dashboard', style: GoogleFonts.inter(fontWeight: widget.currentIndex == 0 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 1,
                  child: Row(
                    children: [
                      Icon(Icons.agriculture_rounded, color: widget.currentIndex == 1 ? _primary : _muted, size: 20),
                      const SizedBox(width: 8),
                      Text('Products', style: GoogleFonts.inter(fontWeight: widget.currentIndex == 1 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 2,
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: widget.currentIndex == 2 ? _primary : _muted, size: 20),
                      const SizedBox(width: 8),
                      Text('Orders', style: GoogleFonts.inter(fontWeight: widget.currentIndex == 2 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 3,
                  child: Row(
                    children: [
                      Icon(Icons.people_rounded, color: widget.currentIndex == 3 ? _primary : _muted, size: 20),
                      const SizedBox(width: 8),
                      Text('Community', style: GoogleFonts.inter(fontWeight: widget.currentIndex == 3 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 4,
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded, color: widget.currentIndex == 4 ? _primary : _muted, size: 20),
                      const SizedBox(width: 8),
                      Text('Profile', style: GoogleFonts.inter(fontWeight: widget.currentIndex == 4 ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;

    final title = Text(
      'Order Management',
      style: GoogleFonts.plusJakartaSans(
        fontSize: isMobile ? 24 : 32,
        fontWeight: FontWeight.w800,
        color: _dark,
      ),
    );

    final statusFiltersList = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_statusFilters.length, (index) {
          final status = _statusFilters[index];
          final isSelected = _selectedStatus == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(status),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedStatus = status),
              selectedColor: _primary.withValues(alpha: 0.1),
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _primary : _muted,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isSelected ? _primary : _border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              showCheckmark: false,
            ),
          );
        }),
      ),
    );

    final searchField = Container(
      width: isMobile ? double.infinity : 300,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search order ID, customer...',
          hintStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 20),
          statusFiltersList,
          const SizedBox(height: 16),
          searchField,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: statusFiltersList),
            const SizedBox(width: 16),
            searchField,
          ],
        ),
      ],
    );
  }

  Widget _buildOrderTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: SupabaseDataService().getFarmerOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: AppShimmerLoader()),
            );
          }

          final allOrders = snapshot.data ?? [];
          final orders = allOrders.where((o) {
            final id = o['orderId']?.toString().toLowerCase() ?? '';
            final customer = o['customerName']?.toString().toLowerCase() ?? '';
            final status = o['status']?.toString().toUpperCase() ?? '';
            
            final matchesSearch = id.contains(_searchQuery.toLowerCase()) || 
                                customer.contains(_searchQuery.toLowerCase());
            final matchesStatus = _selectedStatus == 'ALL' || status == _selectedStatus;
            
            return matchesSearch && matchesStatus;
          }).toList();

          if (orders.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(80),
              child: Center(
                child: Text('No orders match your criteria.', style: GoogleFonts.inter(color: _muted)),
              ),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: _border.withValues(alpha: 0.5)),
              child: DataTable(
                headingRowHeight: 64,
                dataRowMinHeight: 72,
                dataRowMaxHeight: 72,
                horizontalMargin: 24,
                columnSpacing: 24,
                columns: [
                  _buildColumn('Order ID'),
                  _buildColumn('Date'),
                  _buildColumn('Customer'),
                  _buildColumn('Items'),
                  _buildColumn('Total'),
                  _buildColumn('Status'),
                  _buildColumn('Actions'),
                ],
                rows: orders.map((o) => _buildDataRow(o)).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  DataColumn _buildColumn(String label) {
    return DataColumn(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _dark,
        ),
      ),
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> o) {
    final status = o['status']?.toString().toUpperCase() ?? 'PENDING';
    Color statusColor = Colors.orange;
    if (status == 'DELIVERED') statusColor = _primary;
    if (status == 'SHIPPED') statusColor = Colors.blue;
    if (status == 'CANCELLED') statusColor = Colors.red;

    return DataRow(
      cells: [
        DataCell(Text(o['orderId'] ?? '#0000', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
        DataCell(Text(o['timeAgo'] ?? 'Recently', style: GoogleFonts.inter(fontSize: 13))),
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: _primary.withValues(alpha: 0.1),
                child: Text(
                  (o['customerName'] ?? 'C')[0],
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primary),
                ),
              ),
              const SizedBox(width: 10),
              Text(o['customerName'] ?? 'Customer', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        DataCell(
          SizedBox(
            width: 150,
            child: Text(
              o['items'] ?? 'Various items',
              style: GoogleFonts.inter(fontSize: 12, color: _muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(o['total'] ?? '₱0.00', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _dark))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor),
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 20),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FarmerOrderDetailsScreen(
                        order: Order(
                          orderId: o['rawOrderId'].toString(),
                          orderNumber: o['orderId'].toString().replaceFirst('#', ''),
                          customerId: o['customerId'] ?? '',
                          farmerId: '',
                          status: o['status'] ?? 'PENDING',
                          createdAt: o['createdAt'] as DateTime,
                          updatedAt: o['createdAt'] as DateTime,
                          deliveryAddressId: o['deliveryAddressId'],
                          total: o['rawTotal'] as double?,
                          subtotal: o['subtotal'] as double?,
                          deliveryFee: o['deliveryFee'] as double?,
                          paymentMethod: o['paymentMethod'],
                        ),
                        customerName: o['customerName'] ?? 'Customer',
                        customerImage: o['customerImage']?.toString() ?? '',
                      ),
                    ),
                  ).then((_) => setState(() {}));
                },
                tooltip: 'View Details',
              ),
              IconButton(
                icon: Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: (status == 'DELIVERED' || status == 'CANCELLED')
                      ? Colors.grey
                      : _primary,
                ),
                onPressed: (status == 'DELIVERED' || status == 'CANCELLED')
                    ? null
                    : () => _processOrderConfirmation(o),
                tooltip: status == 'PENDING'
                    ? 'Confirm Order'
                    : status == 'CONFIRMED'
                        ? 'Prepare Order'
                        : status == 'PROCESSING'
                            ? 'Ship Order'
                            : status == 'SHIPPED'
                                ? 'Deliver Order'
                                : 'Order Completed',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _processOrderConfirmation(Map<String, dynamic> o) async {
    final orderIdStr = o['orderId'] ?? '#0000';
    final rawOrderId = o['rawOrderId']?.toString();
    if (rawOrderId == null) return;

    final status = o['status']?.toString().toUpperCase() ?? 'PENDING';
    
    String nextStatus = 'CONFIRMED';
    String actionText = 'Confirm Order';
    String confirmationMsg = 'Are you sure you want to mark Order $orderIdStr as CONFIRMED?';

    if (status == 'CONFIRMED') {
      nextStatus = 'PROCESSING';
      actionText = 'Prepare Order';
      confirmationMsg = 'Are you sure you want to mark Order $orderIdStr as PROCESSING?';
    } else if (status == 'PROCESSING') {
      nextStatus = 'SHIPPED';
      actionText = 'Ship Order';
      confirmationMsg = 'Are you sure you want to mark Order $orderIdStr as SHIPPED?';
    } else if (status == 'SHIPPED') {
      nextStatus = 'DELIVERED';
      actionText = 'Deliver Order';
      confirmationMsg = 'Are you sure you want to mark Order $orderIdStr as DELIVERED?';
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          actionText,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          confirmationMsg,
          style: GoogleFonts.inter(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(color: _muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(actionText, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Updating order status...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      try {
        await OrderService().updateOrderStatus(rawOrderId, nextStatus);
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order $orderIdStr status updated to $nextStatus'),
              backgroundColor: _primary,
            ),
          );
          setState(() {}); // Refresh list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update status: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
