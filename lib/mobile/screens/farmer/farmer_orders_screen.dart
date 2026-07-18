import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/models/order/order_model.dart';
import 'farmer_order_details_screen.dart';
import '../../../shared/styles/app_theme.dart';

// Farmer Orders Screen - Professional Enterprise UI
class FarmerOrdersScreen extends StatefulWidget {
  const FarmerOrdersScreen({super.key});

  @override
  State<FarmerOrdersScreen> createState() => _FarmerOrdersScreenState();
}

class _FarmerOrdersScreenState extends State<FarmerOrdersScreen> {
  int _selectedTab = 0;
  final _tabs = ['Active', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildPremiumHeader(),
          _buildSleekTabBar(),
          Expanded(child: _buildOrdersList()),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textHeadline.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ORDER MANAGEMENT',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recent Orders',
                    style: AppTextStyles.headline2.copyWith(fontSize: 24),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSleekTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textHeadline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final isSelected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  _tabs[i],
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSubtle,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOrdersList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseDataService().getFarmerOrders(
        status: _tabs[_selectedTab],
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppShimmerLoader());
        }

        final orders = snapshot.data ?? [];
        var filteredOrders = orders;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          physics: const BouncingScrollPhysics(),
          children: [
            if (_selectedTab == 0) _buildSummaryChart(filteredOrders),
            if (filteredOrders.isEmpty)
              _buildEmptyOrdersState()
            else
              ...filteredOrders.map((order) => _buildOrderCard(order)),
          ],
        );
      },
    );
  }

  Widget _buildSummaryChart(List<Map<String, dynamic>> orders) {
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
      margin: const EdgeInsets.only(bottom: 24, top: 2),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
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
                'TODAY\'S REVENUE',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Icon(
                Icons.auto_graph_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₱${todayRevenue.toStringAsFixed(2)}',
            style: AppTextStyles.headline1.copyWith(
              color: Colors.white,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMetricChip(
                Icons.pending_actions_rounded,
                '$pendingCount Pending',
              ),
              const SizedBox(width: 12),
              _buildMetricChip(
                Icons.local_shipping_rounded,
                '$activeCount Active',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerAvatar(String imageUrl) {
    if (imageUrl.trim().isEmpty) {
      return Container(
        width: 44,
        height: 44,
        color: AppColors.background,
        child: const Icon(
          Icons.person_rounded,
          color: AppColors.textSubtle,
          size: 24,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: 44,
      height: 44,
      fit: BoxFit.cover,
      placeholder: (context, _) => Container(
        width: 44,
        height: 44,
        color: AppColors.background,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: 44,
        height: 44,
        color: AppColors.background,
        child: const Icon(
          Icons.person_rounded,
          color: AppColors.textSubtle,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildMetricChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final isCop = order['paymentMethod']?.toString().toUpperCase() == 'COP';
    final rawStatus = order['status'].toString().toUpperCase();
    String displayStatus = order['status'].toString();
    if (isCop) {
      if (rawStatus == 'SHIPPED') {
        displayStatus = 'Ready for Pickup';
      } else if (rawStatus == 'DELIVERED') {
        displayStatus = 'Picked Up';
      }
    }

    return InkWell(
      onTap: () {
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
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: AppDecorations.cardDecoration.copyWith(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: _buildCustomerAvatar(
                            order['customerImage']?.toString() ?? '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order['customerName'],
                              style: AppTextStyles.headline3.copyWith(
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Order #${order['orderId']} • ${order['timeAgo']}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSubtle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (order['statusColor'] as Color).withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          displayStatus,
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: order['statusColor'],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Items Ordered',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSubtle,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order['items'],
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total Value',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSubtle,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order['total'],
                              style: AppTextStyles.headline3.copyWith(
                                color: AppColors.primary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                    if (order['specialInstructions'] != null &&
                        order['specialInstructions'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 14,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Special Instructions',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                order['specialInstructions'],
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textHeadline,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (order['cancellationReason'] != null &&
                        order['cancellationReason'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.cancel_outlined,
                                    size: 14,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'CANCELLATION REASON',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                order['cancellationReason'],
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.red.shade900,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.textHeadline.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      Icons.check_circle_outline_rounded,
                      'Update Status',
                      (order['status']?.toString().toUpperCase() ==
                                  'DELIVERED' ||
                              order['status']?.toString().toUpperCase() ==
                                  'CANCELLED')
                          ? null
                          : () => _showStatusUpdateSheet(order),
                      isPrimary: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.textHeadline.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: AppColors.textSubtle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool isPrimary = false,
  }) {
    final bool isDisabled = onTap == null;
    return Material(
      color: isDisabled
          ? Colors.grey.shade300
          : isPrimary
          ? AppColors.primary
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: isPrimary || isDisabled
                ? null
                : Border.all(
                    color: AppColors.textHeadline.withValues(alpha: 0.3),
                  ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isDisabled
                    ? Colors.grey.shade600
                    : isPrimary
                    ? Colors.white
                    : AppColors.textHeadline,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: isDisabled
                      ? Colors.grey.shade600
                      : isPrimary
                      ? Colors.white
                      : AppColors.textHeadline,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrdersState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(60),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Orders Yet',
              style: AppTextStyles.headline2.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'When you receive orders, they will appear here for management.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusUpdateSheet(Map<String, dynamic> order) {
    final currentStatus = (order['status']?.toString() ?? 'PENDING')
        .toUpperCase();

    final allStatuses = [
      {
        'label': 'CONFIRMED',
        'icon': Icons.check_circle_outline,
        'color': Colors.blue,
      },
      {
        'label': 'PROCESSING',
        'icon': Icons.loop_rounded,
        'color': Colors.indigo,
      },
      {
        'label': 'SHIPPED',
        'icon': Icons.local_shipping_outlined,
        'color': Colors.deepPurple,
      },
      {
        'label': 'DELIVERED',
        'icon': Icons.done_all_rounded,
        'color': Colors.green,
      },
      {
        'label': 'CANCELLED',
        'icon': Icons.cancel_outlined,
        'color': Colors.red,
      },
    ];

    List<Map<String, dynamic>> allowedStatuses = [];
    if (currentStatus == 'PENDING') {
      allowedStatuses = allStatuses
          .where((s) => s['label'] == 'CONFIRMED' || s['label'] == 'CANCELLED')
          .toList();
    } else if (currentStatus == 'CONFIRMED') {
      allowedStatuses = allStatuses
          .where((s) => s['label'] == 'PROCESSING' || s['label'] == 'CANCELLED')
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Update Order Status', style: AppTextStyles.headline2),
            const SizedBox(height: 8),
            Text(
              'Select the next status step for Order #${order['orderId']}',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 24),
            if (allowedStatuses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No further status updates available.',
                  style: AppTextStyles.bodyMedium,
                ),
              )
            else
              ...allowedStatuses.map(
                (s) => _statusTile(
                  s['label'] as String,
                  s['icon'] as IconData,
                  s['color'] as Color,
                  order,
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _statusTile(
    String status,
    IconData icon,
    Color color,
    Map<String, dynamic> order,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        status,
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
      ),
      onTap: () async {
        if (status == 'CANCELLED') {
          // Close the status sheet first, then show reason sheet
          Navigator.pop(context);
          await _showCancellationReasonSheet(order);
        } else {
          Navigator.pop(context);
          try {
            await OrderService().updateOrderStatus(
              order['rawOrderId'].toString(),
              status,
            );
            if (mounted) {
              setState(() {}); // Refresh list
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Order status updated to $status'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update status: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      },
    );
  }

  Future<void> _showCancellationReasonSheet(
    Map<String, dynamic> order,
  ) async {
    final predefinedReasons = [
      'Out of stock',
      'Customer requested',
      'Pricing issue',
      'Unable to deliver',
      'Duplicate order',
      'Payment failed',
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
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppColors.textSubtle.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Icon + title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cancel_outlined,
                              color: Colors.red,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cancel Order',
                                style: AppTextStyles.headline2.copyWith(
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                'Order #${order['orderId']}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSubtle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please select a reason for cancellation:',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSubtle,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Predefined reason chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...predefinedReasons.map((reason) {
                            final isSelected = selectedReason == reason && !isCustom;
                            return GestureDetector(
                              onTap: () => setSheetState(() {
                                selectedReason = reason;
                                isCustom = false;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.red
                                      : Colors.red.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.red
                                        : Colors.red.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  reason,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.red.shade700,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }),
                          // "Other" chip
                          GestureDetector(
                            onTap: () => setSheetState(() {
                              isCustom = true;
                              selectedReason = null;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isCustom
                                    ? Colors.red
                                    : Colors.red.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isCustom
                                      ? Colors.red
                                      : Colors.red.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                '✏️ Other',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isCustom
                                      ? Colors.white
                                      : Colors.red.shade700,
                                  fontWeight: isCustom
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Custom text field (visible only when "Other" selected)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: isCustom
                            ? Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: TextField(
                                  controller: customController,
                                  autofocus: true,
                                  maxLines: 2,
                                  maxLength: 200,
                                  style: AppTextStyles.bodyMedium,
                                  decoration: InputDecoration(
                                    hintText: 'Describe the reason…',
                                    hintStyle: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSubtle,
                                    ),
                                    filled: true,
                                    fillColor:
                                        AppColors.background,
                                    contentPadding: const EdgeInsets.all(14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.red.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Colors.red,
                                        width: 1.5,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color:
                                            Colors.red.withValues(alpha: 0.2),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(
                                  color: AppColors.textSubtle
                                      .withValues(alpha: 0.4),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'Go Back',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSubtle,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final reason = isCustom
                                    ? customController.text.trim()
                                    : selectedReason ?? '';
                                if (reason.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please select or enter a reason.',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }
                                Navigator.pop(ctx);
                                try {
                                  await OrderService().updateOrderStatus(
                                    order['rawOrderId'].toString(),
                                    'CANCELLED',
                                    cancellationReason: reason,
                                  );
                                  if (mounted) {
                                    setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Order cancelled successfully'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to cancel order: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'Cancel Order',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white,
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
}
