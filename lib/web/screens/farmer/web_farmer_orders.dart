import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../widgets/animated_components.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/models/order/order_model.dart';
import '../../../mobile/screens/farmer/farmer_order_details_screen.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../widgets/web_consumer_nav_bar.dart';
import '../../widgets/web_hamburger_menu_button.dart';

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

class _WebFarmerOrdersState extends State<WebFarmerOrders>
    with TickerProviderStateMixin {
  late AnimationController _fadeInController;
  int _hoveredNav = -1;
  String _searchQuery = '';
  String _selectedStatus = 'ALL';
  final List<String> _statusFilters = [
    'ALL',
    'PENDING',
    'SHIPPED',
    'DELIVERED',
    'CANCELLED',
  ];

  // Cached orders — only replaced when user explicitly refreshes or updates
  Future<List<Map<String, dynamic>>>? _ordersFuture;
  List<Map<String, dynamic>> _orders = [];
  bool _ordersLoaded = false;

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
    _loadOrders();
  }

  void _loadOrders() {
    _ordersFuture = SupabaseDataService().getFarmerOrders().then((data) {
      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data);
          _ordersLoaded = true;
        });
      }
      return data;
    });
  }

  /// Optimistic update: change just one row in-memory, no full reload
  void _updateOrderStatusLocally(String rawOrderId, String newStatus) {
    setState(() {
      final idx = _orders.indexWhere(
        (o) => o['rawOrderId']?.toString() == rawOrderId,
      );
      if (idx != -1) {
        _orders[idx] = Map<String, dynamic>.from(_orders[idx])
          ..['status'] = newStatus;
      }
    });
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredOrders {
    return _orders.where((o) {
      final id = o['orderId']?.toString().toLowerCase() ?? '';
      final customer = o['customerName']?.toString().toLowerCase() ?? '';
      final status = o['status']?.toString().toUpperCase() ?? '';

      final matchesSearch =
          _searchQuery.isEmpty ||
          id.contains(_searchQuery.toLowerCase()) ||
          customer.contains(_searchQuery.toLowerCase());
      final matchesStatus =
          _selectedStatus == 'ALL' || status == _selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();
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
              painter: DotPatternPainter(
                opacity: 0.03,
                color: const Color(0xFF10B981),
              ),
            ),
          ),
          Column(
            children: [
              _buildNavBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 40,
                    0,
                    isMobile ? 16 : 40,
                    40,
                  ),
                  child: FadeTransition(
                    opacity: _fadeInController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        SizedBox(height: isMobile ? 20 : 32),
                        _buildOrderList(),
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

    final navItems = [
      'Dashboard',
      'Products',
      'Orders',
      'Community',
      'Pre-Orders',
    ];
    return Container(
      margin: isMobile
          ? const EdgeInsets.fromLTRB(16, 16, 16, 8)
          : const EdgeInsets.fromLTRB(32, 24, 32, 12),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 28,
        vertical: isMobile ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
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
                      duration: const Duration(milliseconds: 200),
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

  Widget _buildHeader() {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;

    final title = Row(
      children: [
        Text(
          'Order Management',
          style: GoogleFonts.plusJakartaSans(
            fontSize: isMobile ? 24 : 32,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
        const Spacer(),
        // Refresh button
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _loadOrders,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.refresh_rounded, size: 20, color: _muted),
            ),
          ),
        ),
      ],
    );

    final filters = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _statusFilters.map((status) {
          final isSelected = _selectedStatus == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _selectedStatus = status),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _primary.withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _primary : _border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? _primary : _muted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );

    final searchField = Container(
      width: isMobile ? double.infinity : 280,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        style: GoogleFonts.inter(fontSize: 14, color: _dark),
        decoration: InputDecoration(
          hintText: 'Search order ID, customer...',
          hintStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 20),
          filters,
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
            Expanded(child: filters),
            const SizedBox(width: 16),
            searchField,
          ],
        ),
      ],
    );
  }

  Widget _buildOrderList() {
    if (!_ordersLoaded) {
      return _buildSkeleton();
    }

    final filtered = _filteredOrders;
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 650;

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 80),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 56,
                color: _muted.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No orders match your criteria',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: _muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isMobile) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _buildMobileOrderCard(filtered[i]),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Table header
            Container(
              color: _surface,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  _headerCell('Order ID', flex: 3),
                  _headerCell('Date', flex: 2),
                  _headerCell('Customer', flex: 3),
                  _headerCell('Items', flex: 3),
                  _headerCell('Total', flex: 2),
                  _headerCell('Status', flex: 2),
                  _headerCell('Actions', flex: 2),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            // Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
              itemBuilder: (context, i) => _buildOrderRow(filtered[i]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileOrderCard(Map<String, dynamic> o) {
    final status = o['status']?.toString().toUpperCase() ?? 'PENDING';
    final canProgress = status != 'DELIVERED' && status != 'CANCELLED';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
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
                o['orderId'] ?? '#0000',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              _StatusBadge(status: status, paymentMethod: o['paymentMethod']),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                o['timeAgo'] ?? '',
                style: GoogleFonts.inter(fontSize: 12, color: _muted),
              ),
              const Spacer(),
              Text(
                o['total'] ?? '₱0.00',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (o['customerName'] ?? 'C')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  o['customerName'] ?? 'Customer',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 14, color: _muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  o['items'] ?? '',
                  style: GoogleFonts.inter(fontSize: 12, color: _muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _viewOrderDetails(o),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: Text(
                  'Details',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _muted,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              const SizedBox(width: 8),
              if (canProgress)
                ElevatedButton.icon(
                  onPressed: () => _processOrderConfirmation(o),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: Text(
                    _getNextActionLabel(status, o['paymentMethod']),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _muted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildOrderRow(Map<String, dynamic> o) {
    final status = o['status']?.toString().toUpperCase() ?? 'PENDING';
    final canProgress = status != 'DELIVERED' && status != 'CANCELLED';

    return _HoverableRow(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // Order ID
            Expanded(
              flex: 3,
              child: Text(
                o['orderId'] ?? '#0000',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
            ),
            // Date
            Expanded(
              flex: 2,
              child: Text(
                o['timeAgo'] ?? '',
                style: GoogleFonts.inter(fontSize: 13, color: _muted),
              ),
            ),
            // Customer
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (o['customerName'] ?? 'C')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      o['customerName'] ?? 'Customer',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _dark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Items
            Expanded(
              flex: 3,
              child: Text(
                o['items'] ?? '',
                style: GoogleFonts.inter(fontSize: 12, color: _muted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Total
            Expanded(
              flex: 2,
              child: Text(
                o['total'] ?? '₱0.00',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
            ),
            // Status badge
            Expanded(
              flex: 2,
              child: _StatusBadge(
                status: status,
                paymentMethod: o['paymentMethod'],
              ),
            ),
            // Actions
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  _ActionButton(
                    icon: Icons.visibility_outlined,
                    tooltip: 'View Details',
                    color: _muted,
                    onTap: () => _viewOrderDetails(o),
                  ),
                  const SizedBox(width: 4),
                  _ActionButton(
                    icon: Icons.check_circle_outline_rounded,
                    tooltip: _getNextActionLabel(status, o['paymentMethod']),
                    color: canProgress ? _primary : Colors.grey.shade300,
                    onTap: canProgress
                        ? () => _processOrderConfirmation(o)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getNextActionLabel(String status, dynamic paymentMethod) {
    final isCop = paymentMethod?.toString().toUpperCase() == 'COP';
    switch (status) {
      case 'PENDING':
        return 'Confirm Order';
      case 'CONFIRMED':
        return 'Prepare Order';
      case 'PROCESSING':
        return isCop ? 'Mark Ready for Pickup' : 'Ship Order';
      case 'SHIPPED':
        return isCop ? 'Complete Pickup' : 'Mark Delivered';
      default:
        return 'Order Completed';
    }
  }

  Widget _buildSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: List.generate(
          6,
          (i) => Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: i < 5
                  ? const Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))
                  : null,
            ),
            child: Row(
              children: [
                _skeletonBox(120),
                const SizedBox(width: 24),
                _skeletonBox(80),
                const SizedBox(width: 24),
                _skeletonBox(140),
                const SizedBox(width: 24),
                _skeletonBox(160),
                const Spacer(),
                _skeletonBox(60),
                const SizedBox(width: 16),
                _skeletonBox(80),
                const SizedBox(width: 16),
                _skeletonBox(64),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _skeletonBox(double width) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: _border,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  void _viewOrderDetails(Map<String, dynamic> o) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, a1, a2) => FarmerOrderDetailsScreen(
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
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Future<void> _processOrderConfirmation(Map<String, dynamic> o) async {
    final orderIdStr = o['orderId'] ?? '#0000';
    final rawOrderId = o['rawOrderId']?.toString();
    if (rawOrderId == null) return;

    final status = o['status']?.toString().toUpperCase() ?? 'PENDING';
    final isCop = o['paymentMethod']?.toString().toUpperCase() == 'COP';

    String nextStatus = 'CONFIRMED';
    String actionText = 'Confirm Order';
    String confirmationMsg = 'Mark Order $orderIdStr as CONFIRMED?';

    if (status == 'CONFIRMED') {
      nextStatus = 'PROCESSING';
      actionText = 'Prepare Order';
      confirmationMsg = 'Mark Order $orderIdStr as PROCESSING?';
    } else if (status == 'PROCESSING') {
      nextStatus = 'SHIPPED';
      actionText = isCop ? 'Ready for Pickup' : 'Ship Order';
      confirmationMsg = isCop
          ? 'Mark Order $orderIdStr as Ready for Pickup?'
          : 'Mark Order $orderIdStr as SHIPPED?';
    } else if (status == 'SHIPPED') {
      nextStatus = 'DELIVERED';
      actionText = isCop ? 'Complete Pickup' : 'Deliver Order';
      confirmationMsg = isCop
          ? 'Mark Order $orderIdStr as Picked Up?'
          : 'Mark Order $orderIdStr as DELIVERED?';
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: actionText,
        message: confirmationMsg,
        confirmLabel: actionText,
      ),
    );

    if (confirm == true && mounted) {
      // Optimistic update — no full reload
      _updateOrderStatusLocally(rawOrderId, nextStatus);

      try {
        await OrderService().updateOrderStatus(rawOrderId, nextStatus);
        if (mounted) {
          String successMsg = 'Order status updated successfully.';
          if (nextStatus == 'SHIPPED') {
            successMsg = isCop
                ? 'Order is ready for pickup! Customer has been notified.'
                : 'Order is shipped and on the way!';
          } else if (nextStatus == 'DELIVERED') {
            successMsg = isCop
                ? 'Pickup completed successfully! Order finalized.'
                : 'Order delivered successfully!';
          } else if (nextStatus == 'CONFIRMED') {
            successMsg = 'Order accepted! Preparing items.';
          } else if (nextStatus == 'PROCESSING') {
            successMsg = 'Order is now processing!';
          }

          late OverlayEntry overlayEntry;
          overlayEntry = OverlayEntry(
            builder: (context) => Scaffold(
              backgroundColor: Colors.transparent,
              body: _StatusSuccessOverlay(
                statusTitle: nextStatus,
                message: successMsg,
                onFinished: () {
                  overlayEntry.remove();
                },
              ),
            ),
          );
          Overlay.of(context).insert(overlayEntry);
        }
      } catch (e) {
        // Revert optimistic update on failure
        _updateOrderStatusLocally(rawOrderId, status);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }
}

// ─── Status Badge ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  final dynamic paymentMethod;
  const _StatusBadge({required this.status, this.paymentMethod});

  Color get _bg {
    switch (status) {
      case 'DELIVERED':
        return const Color(0xFF16A34A);
      case 'SHIPPED':
        return const Color(0xFF2563EB);
      case 'PROCESSING':
        return const Color(0xFF7C3AED);
      case 'CONFIRMED':
        return const Color(0xFF0891B2);
      case 'CANCELLED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706); // PENDING
    }
  }

  String get _labelText {
    final isCop = paymentMethod?.toString().toUpperCase() == 'COP';
    if (isCop) {
      if (status == 'DELIVERED') return 'PICKED UP';
      if (status == 'SHIPPED') return 'READY FOR PICKUP';
    }
    return status;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bg.withValues(alpha: 0.25)),
      ),
      child: Text(
        _labelText,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _bg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Action Button ───────────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: isDisabled
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _hovered && !isDisabled
                  ? widget.color.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 18, color: widget.color),
          ),
        ),
      ),
    );
  }
}

// ─── Hoverable Row ───────────────────────────────────────────────────────────

class _HoverableRow extends StatefulWidget {
  final Widget child;
  const _HoverableRow({required this.child});

  @override
  State<_HoverableRow> createState() => _HoverableRowState();
}

class _HoverableRowState extends State<_HoverableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _hovered ? const Color(0xFFF9FAFB) : Colors.white,
        child: widget.child,
      ),
    );
  }
}

// ─── Confirm Dialog ──────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  static const Color _primary = Color(0xFF16A34A);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: _primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: GoogleFonts.inter(fontSize: 14, color: _muted),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(color: _muted),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
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

// ─── Success Overlay Animation (Like Mobile) ───────────────────────────────

class _StatusSuccessOverlay extends StatefulWidget {
  final String statusTitle;
  final String message;
  final VoidCallback onFinished;

  const _StatusSuccessOverlay({
    required this.statusTitle,
    required this.message,
    required this.onFinished,
  });

  @override
  State<_StatusSuccessOverlay> createState() => _StatusSuccessOverlayState();
}

class _StatusSuccessOverlayState extends State<_StatusSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 35),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(_controller);

    _controller.forward().then((_) => widget.onFinished());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent,
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Status Updated!',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
