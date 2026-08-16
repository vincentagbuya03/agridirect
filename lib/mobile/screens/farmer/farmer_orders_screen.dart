import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/models/order/order_model.dart';
import 'farmer_order_details_screen.dart';
import '../../../shared/styles/app_theme.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';

class FarmerOrdersScreen extends StatefulWidget {
  const FarmerOrdersScreen({super.key});

  @override
  State<FarmerOrdersScreen> createState() => _FarmerOrdersScreenState();
}

class _FarmerOrdersScreenState extends State<FarmerOrdersScreen> {
  int _selectedTab = 0;
  final List<String> _tabs = ['Active', 'Completed', 'Cancelled'];
  String _activeSubFilter = 'ALL';

  List<Map<String, dynamic>>? _orders;
  bool _isLoadingOrders = true;
  final Map<String, bool> _updatingOrders = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoadingOrders = true);
    try {
      final orders = await SupabaseDataService().getFarmerOrders(
        status: _tabs[_selectedTab],
      );
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _orders = [];
          _isLoadingOrders = false;
        });
      }
    }
  }

  void _onTabChanged(int index) {
    if (_selectedTab == index) return;
    setState(() {
      _selectedTab = index;
      _activeSubFilter = 'ALL';
    });
    _loadOrders();
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFD97706); // Amber 600
      case 'CONFIRMED':
        return const Color(0xFF2563EB); // Blue 600
      case 'PROCESSING':
        return const Color(0xFF4F46E5); // Indigo 600
      case 'SHIPPED':
        return const Color(0xFF7C3AED); // Purple 600
      case 'DELIVERED':
        return const Color(0xFF059669); // Emerald 600
      case 'CANCELLED':
      case 'REFUNDED':
        return const Color(0xFFDC2626); // Red 600
      default:
        return const Color(0xFF64748B); // Slate 500
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFFEF3C7);
      case 'CONFIRMED':
        return const Color(0xFFDBEAFE);
      case 'PROCESSING':
        return const Color(0xFFE0E7FF);
      case 'SHIPPED':
        return const Color(0xFFEDE9FE);
      case 'DELIVERED':
        return const Color(0xFFD1FAE5);
      case 'CANCELLED':
      case 'REFUNDED':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  List<Map<String, dynamic>> _getFilteredOrders() {
    if (_orders == null) return [];
    var list = _orders!;

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      list = list.where((o) {
        final name = (o['customerName'] ?? '').toString().toLowerCase();
        final orderId = (o['orderId'] ?? '').toString().toLowerCase();
        final items = (o['items'] ?? '').toString().toLowerCase();
        return name.contains(query) ||
            orderId.contains(query) ||
            items.contains(query);
      }).toList();
    }

    if (_selectedTab == 0 && _activeSubFilter != 'ALL') {
      list = list.where((o) {
        final status = (o['status'] ?? '').toString().toUpperCase();
        return status == _activeSubFilter;
      }).toList();
    }

    return list;
  }

  String _formatOrderId(dynamic rawOrderId) {
    if (rawOrderId == null) return '#0000';
    final str = rawOrderId.toString().replaceFirst('#', '');
    if (str.length > 14) {
      return '#${str.substring(0, 8)}…${str.substring(str.length - 4)}';
    }
    return '#$str';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildModernHeader(),
            _buildSegmentedTabBar(),
            if (_selectedTab == 0) _buildSubStatusFilterChips(),
            Expanded(child: _buildOrdersContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FARMER PORTAL',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Orders & Sales',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isSearchExpanded
                      ? Icons.close_rounded
                      : Icons.search_rounded,
                  color: const Color(0xFF475569),
                  size: 22,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _isSearchExpanded = !_isSearchExpanded;
                    if (!_isSearchExpanded) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _loadOrders,
              ),
            ],
          ),
          if (_isSearchExpanded) ...[
            const SizedBox(height: 12),
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF0F172A),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search customer, order #, or item…',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentedTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final isSelected = _selectedTab == i;
          final count = _getTabOrderCount(i);

          return Expanded(
            child: GestureDetector(
              onTap: () => _onTabChanged(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _tabs[i],
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  int _getTabOrderCount(int tabIndex) {
    if (_selectedTab == tabIndex && _orders != null) {
      return _orders!.length;
    }
    return 0;
  }

  Widget _buildSubStatusFilterChips() {
    final subFilters = [
      {'label': 'All Active', 'key': 'ALL'},
      {'label': 'Pending', 'key': 'PENDING'},
      {'label': 'Processing', 'key': 'PROCESSING'},
      {'label': 'Shipped', 'key': 'SHIPPED'},
    ];

    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: subFilters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final item = subFilters[idx];
          final isSelected = _activeSubFilter == item['key'];
          return ChoiceChip(
            label: Text(item['label']!),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                setState(() => _activeSubFilter = item['key']!);
              }
            },
            labelStyle: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : const Color(0xFF64748B),
            ),
            selectedColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected
                  ? AppColors.primary
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          );
        },
      ),
    );
  }

  Widget _buildOrdersContent() {
    if (_isLoadingOrders) {
      return _buildShimmerOrdersList();
    }

    final filteredOrders = _getFilteredOrders();

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          if (_selectedTab == 0 && _orders != null && _orders!.isNotEmpty)
            _buildModernRevenueBanner(_orders!),
          if (filteredOrders.isEmpty)
            _buildEmptyOrdersState()
          else
            ...filteredOrders.map((order) => _buildModernOrderCard(order)),
        ],
      ),
    );
  }

  Widget _buildModernRevenueBanner(List<Map<String, dynamic>> orders) {
    final now = DateTime.now();
    final todayOrders = orders.where((o) {
      final date = o['createdAt'] as DateTime;
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();

    final todayRevenue = todayOrders.fold(
      0.0,
      (sum, o) => sum + (o['rawTotal'] as double),
    );
    final pendingCount = orders
        .where((o) => o['status'].toString().toUpperCase() == 'PENDING')
        .length;
    final activeCount = orders
        .where(
          (o) => [
            'CONFIRMED',
            'SHIPPED',
            'PROCESSING',
          ].contains(o['status'].toString().toUpperCase()),
        )
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF047857), Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TODAY\'S SALES REVENUE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${todayOrders.length} Today',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '₱${todayRevenue.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMetricPill(
                icon: Icons.hourglass_top_rounded,
                label: '$pendingCount Pending',
                color: Colors.amber.shade200,
              ),
              const SizedBox(width: 8),
              _buildMetricPill(
                icon: Icons.local_shipping_rounded,
                label: '$activeCount In Progress',
                color: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernOrderCard(Map<String, dynamic> order) {
    final rawStatus = (order['status'] ?? 'PENDING').toString().toUpperCase();
    final isCop = order['paymentMethod']?.toString().toUpperCase() == 'COP';
    String displayStatus = order['status']?.toString() ?? 'Pending';

    if (isCop) {
      if (rawStatus == 'SHIPPED') {
        displayStatus = 'Ready for Pickup';
      } else if (rawStatus == 'DELIVERED') {
        displayStatus = 'Picked Up';
      }
    }

    final statusColor = _getStatusColor(rawStatus);
    final statusBg = _getStatusBgColor(rawStatus);
    final orderIdStr = order['rawOrderId']?.toString() ?? '';
    final isUpdating = _updatingOrders[orderIdStr] ?? false;
    final isDeliveredOrCancelled =
        rawStatus == 'DELIVERED' || rawStatus == 'CANCELLED';

    final orderNumber = order['orderId']?.toString() ?? 'AD-0000';
    final customerName = order['customerName']?.toString() ?? 'Customer';
    final timeAgo = order['timeAgo']?.toString() ?? '';
    final paymentMethod =
        order['paymentMethod']?.toString() ?? (isCop ? 'Pickup' : 'Cash on Delivery');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _navigateToOrderDetails(order),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Order Number & Status Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.receipt_rounded,
                              size: 13,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                orderNumber.startsWith('#')
                                    ? orderNumber
                                    : '#$orderNumber',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        displayStatus.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Customer Profile Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildCustomerAvatar(
                      order['customerImage']?.toString() ?? '',
                      customerName,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeAgo.isNotEmpty ? timeAgo : 'Recently',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFCBD5E1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                paymentMethod,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Products & Total Amount Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      _buildProductThumbnail(
                        order['productImage']?.toString() ?? '',
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ITEMS ORDERED',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF94A3B8),
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order['items']?.toString() ?? 'Produce items',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'TOTAL VALUE',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order['total']?.toString() ?? '₱0.00',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 4. Special Instructions (Clean note card style)
                if (order['specialInstructions'] != null &&
                    order['specialInstructions'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB), // Amber 50
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFDE68A), // Amber 200
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.note_alt_outlined,
                          size: 15,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order['specialInstructions'].toString(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 5. Cancellation Reason (Alert card style)
                if (order['cancellationReason'] != null &&
                    order['cancellationReason'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2), // Red 50
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFECACA), // Red 200
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.cancel_rounded,
                          size: 15,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cancellation Reason',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFB91C1C),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                order['cancellationReason'].toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // 6. Bottom Action Row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isDeliveredOrCancelled || isUpdating
                            ? null
                            : () => _showStatusUpdateSheet(order),
                        icon: isUpdating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : Icon(
                                isDeliveredOrCancelled
                                    ? Icons.check_circle_rounded
                                    : Icons.sync_alt_rounded,
                                size: 16,
                              ),
                        label: Text(
                          isUpdating
                              ? 'Updating…'
                              : (isDeliveredOrCancelled
                                  ? 'Order Finalized'
                                  : 'Update Status'),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFF1F5F9),
                          disabledForegroundColor: const Color(0xFF94A3B8),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF475569),
                      ),
                      tooltip: 'View Details',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF8FAFC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      onPressed: () => _navigateToOrderDetails(order),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerAvatar(String imageUrl, String name) {
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';

    if (imageUrl.trim().isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 44,
          height: 44,
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 44,
          height: 44,
          color: AppColors.primary.withValues(alpha: 0.12),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductThumbnail(String? rawUrl) {
    final imageUrl = (rawUrl ?? '').trim();
    if (imageUrl.isEmpty) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.inventory_2_rounded,
            color: AppColors.primary,
            size: 24,
          ),
        ),
      );
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: AppColors.primary.withValues(alpha: 0.1),
            child: const Center(
              child: Icon(
                Icons.inventory_2_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToOrderDetails(Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FarmerOrderDetailsScreen(
          order: Order(
            orderId: order['rawOrderId'].toString(),
            orderNumber: order['orderId'].toString().replaceFirst('#', ''),
            customerId: order['customerId'] ?? '',
            farmerId: '',
            status: order['status'],
            createdAt: order['createdAt'] as DateTime,
            updatedAt: order['createdAt'] as DateTime,
            deliveryAddressId: order['deliveryAddressId'],
            total: order['rawTotal'] as double?,
            subtotal: order['subtotal'] as double?,
            deliveryFee: order['deliveryFee'] as double?,
            paymentMethod: order['paymentMethod'],
          ),
          customerName: order['customerName'] ?? 'Customer',
          customerImage: order['customerImage']?.toString() ?? '',
        ),
      ),
    );
  }

  void _showStatusUpdateSheet(Map<String, dynamic> order) {
    final currentStatus =
        (order['status']?.toString() ?? 'PENDING').toUpperCase();

    final allStatuses = [
      {
        'label': 'CONFIRMED',
        'title': 'Confirm Order',
        'desc': 'Accept and notify customer preparation has started',
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFF2563EB),
      },
      {
        'label': 'PROCESSING',
        'title': 'Mark as Processing',
        'desc': 'Harvesting or packing items for dispatch',
        'icon': Icons.inventory_2_rounded,
        'color': const Color(0xFF4F46E5),
      },
      {
        'label': 'SHIPPED',
        'title': 'Out for Delivery / Ready',
        'desc': 'Handed over to courier or ready for pickup',
        'icon': Icons.local_shipping_rounded,
        'color': const Color(0xFF7C3AED),
      },
      {
        'label': 'DELIVERED',
        'title': 'Mark as Delivered',
        'desc': 'Customer has received and accepted order',
        'icon': Icons.task_alt_rounded,
        'color': const Color(0xFF059669),
      },
      {
        'label': 'CANCELLED',
        'title': 'Cancel Order',
        'desc': 'Unable to fulfill (reason required)',
        'icon': Icons.cancel_rounded,
        'color': const Color(0xFFDC2626),
      },
    ];

    List<Map<String, dynamic>> allowedStatuses = [];
    if (currentStatus == 'PENDING') {
      allowedStatuses = allStatuses
          .where((s) => s['label'] == 'CONFIRMED' || s['label'] == 'CANCELLED')
          .toList();
    } else if (currentStatus == 'CONFIRMED') {
      allowedStatuses = allStatuses
          .where(
            (s) => s['label'] == 'PROCESSING' || s['label'] == 'CANCELLED',
          )
          .toList();
    } else if (currentStatus == 'PROCESSING') {
      allowedStatuses = allStatuses
          .where((s) => s['label'] == 'SHIPPED' || s['label'] == 'CANCELLED')
          .toList();
    } else if (currentStatus == 'SHIPPED') {
      allowedStatuses = allStatuses
          .where((s) => s['label'] == 'DELIVERED' || s['label'] == 'CANCELLED')
          .toList();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sync_alt_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Order Status',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Order ${_formatOrderId(order['orderId'])} • Current: $currentStatus',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (allowedStatuses.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No further status transitions available for this order.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                )
              else
                ...allowedStatuses.map(
                  (s) => _buildStatusSelectionTile(
                    label: s['label'] as String,
                    title: s['title'] as String,
                    desc: s['desc'] as String,
                    icon: s['icon'] as IconData,
                    color: s['color'] as Color,
                    order: order,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSelectionTile({
    required String label,
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required Map<String, dynamic> order,
  }) {
    final isCancel = label == 'CANCELLED';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isCancel ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCancel ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isCancel ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          desc,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF64748B),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF94A3B8),
        ),
        onTap: () async {
          if (label == 'CANCELLED') {
            Navigator.pop(context);
            await _showCancellationReasonSheet(order);
          } else {
            Navigator.pop(context);
            final orderIdStr = order['rawOrderId'].toString();
            setState(() {
              _updatingOrders[orderIdStr] = true;
            });
            try {
              await OrderService().updateOrderStatus(
                orderIdStr,
                label,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Order status updated to $label'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                if (_orders != null) {
                  final idx = _orders!.indexWhere(
                    (o) => o['rawOrderId'].toString() == orderIdStr,
                  );
                  if (idx != -1) {
                    if (_selectedTab == 0 &&
                        (label == 'DELIVERED' || label == 'CANCELLED')) {
                      _orders!.removeAt(idx);
                    } else {
                      _orders![idx] = {
                        ..._orders![idx],
                        'status': label,
                        'statusColor': _getStatusColor(label),
                      };
                    }
                  }
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update status: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            } finally {
              if (mounted) {
                setState(() {
                  _updatingOrders[orderIdStr] = false;
                });
              }
            }
          }
        },
      ),
    );
  }

  Future<void> _showCancellationReasonSheet(Map<String, dynamic> order) async {
    final predefinedReasons = [
      'Item out of stock',
      'Customer requested cancellation',
      'Harvest delay or weather damage',
      'Logistics / delivery unavailable',
      'Duplicate order',
      'Payment verification failed',
    ];

    String? selectedReason;
    final customController = TextEditingController();
    bool isCustom = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cancel_rounded,
                              color: Color(0xFFDC2626),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cancel Order',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Order ${_formatOrderId(order['orderId'])}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select a reason for cancellation:',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...predefinedReasons.map((reason) {
                            final isSelected =
                                selectedReason == reason && !isCustom;
                            return GestureDetector(
                              onTap: () => setSheetState(() {
                                selectedReason = reason;
                                isCustom = false;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  reason,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            );
                          }),
                          GestureDetector(
                            onTap: () => setSheetState(() {
                              isCustom = true;
                              selectedReason = null;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isCustom
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCustom
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                '✏️ Other Reason',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isCustom
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isCustom
                                      ? Colors.white
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isCustom) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: customController,
                          autofocus: true,
                          maxLines: 2,
                          maxLength: 200,
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Provide detailed cancellation reason…',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFDC2626),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Go Back',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final reason = isCustom
                                    ? customController.text.trim()
                                    : selectedReason ?? '';
                                if (reason.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Please select or provide a reason.',
                                      ),
                                      backgroundColor: Colors.orange,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.pop(ctx);
                                final orderIdStr =
                                    order['rawOrderId'].toString();
                                setState(() {
                                  _updatingOrders[orderIdStr] = true;
                                });
                                try {
                                  await OrderService().updateOrderStatus(
                                    orderIdStr,
                                    'CANCELLED',
                                    cancellationReason: reason,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Order cancelled successfully',
                                        ),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                    if (_orders != null) {
                                      final idx = _orders!.indexWhere(
                                        (o) =>
                                            o['rawOrderId'].toString() ==
                                            orderIdStr,
                                      );
                                      if (idx != -1) {
                                        if (_selectedTab == 0) {
                                          _orders!.removeAt(idx);
                                        } else {
                                          _orders![idx] = {
                                            ..._orders![idx],
                                            'status': 'CANCELLED',
                                            'statusColor': Colors.red,
                                            'cancellationReason': reason,
                                          };
                                        }
                                      }
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to cancel order: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _updatingOrders[orderIdStr] = false;
                                    });
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Confirm Cancel',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyOrdersState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No Matching Orders'
                  : 'No ${_tabs[_selectedTab]} Orders',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching with a different keyword.'
                  : 'Orders in this category will automatically show up here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _activeSubFilter = 'ALL';
                });
                _loadOrders();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh Orders'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerOrdersList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppShimmerLoader.rectangle(width: 140, height: 14, borderRadius: 4),
              const SizedBox(height: 12),
              AppShimmerLoader.rectangle(width: 160, height: 28, borderRadius: 6),
              const Spacer(),
              Row(
                children: [
                  AppShimmerLoader.rectangle(width: 90, height: 26, borderRadius: 8),
                  const SizedBox(width: 10),
                  AppShimmerLoader.rectangle(width: 90, height: 26, borderRadius: 8),
                ],
              ),
            ],
          ),
        ),
        ...List.generate(
          3,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AppShimmerLoader.circle(size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppShimmerLoader.rectangle(
                            width: 120,
                            height: 14,
                            borderRadius: 4,
                          ),
                          const SizedBox(height: 6),
                          AppShimmerLoader.rectangle(
                            width: 80,
                            height: 11,
                            borderRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    AppShimmerLoader.rectangle(
                      width: 70,
                      height: 22,
                      borderRadius: 8,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppShimmerLoader.rectangle(
                        width: 110,
                        height: 14,
                        borderRadius: 4,
                      ),
                      AppShimmerLoader.rectangle(
                        width: 70,
                        height: 16,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppShimmerLoader.rectangle(
                  height: 38,
                  borderRadius: 12,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
