import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/models/order/order_model.dart';
import 'package:agridirect/shared/widgets/image_widgets.dart';

/// Orders Screen - Professional Order Management (Responsive Web & Mobile)
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _selectedTab = 0;
  final _tabs = ['Active', 'Completed', 'Cancelled'];
  late Stream<List<Order>> _ordersStream;

  @override
  void initState() {
    super.initState();
    _ordersStream = OrderService().watchMyOrders();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;

    if (isWeb) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _buildWebHeader(),
            _buildWebTabs(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: _buildOrdersListContent(isWeb: true),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildPremiumHeader(),
          _buildSleekTabs(),
          Expanded(child: _buildOrdersListContent(isWeb: false)),
        ],
      ),
    );
  }

  Widget _buildWebHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textHeadline),
                ),
                const SizedBox(width: 12),
                Text(
                  'Your Orders',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeadline,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final isSelected = _selectedTab == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _tabs[i],
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: isSelected ? Colors.white : AppColors.textSubtle,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Orders',
                        style: AppTextStyles.headline1.copyWith(fontSize: 22),
                      ),
                    ],
                  ),
                  _buildHeaderNotification(),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.textHeadline.withValues(alpha: 0.1),
                  ),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search your orders...',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSubtle,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSubtle,
                      size: 22,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderNotification() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.textHeadline.withValues(alpha: 0.1),
        ),
      ),
      child: Stack(
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.textHeadline,
            size: 24,
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleekTabs() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final isSelected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  _tabs[i],
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isSelected ? Colors.white : AppColors.textSubtle,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                size: 56,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeadline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersListContent({required bool isWeb}) {
    return StreamBuilder<List<Order>>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return _buildEmptyState('No orders found');
        }

        List<Order> filteredOrders;
        if (_selectedTab == 0) {
          filteredOrders = orders.where((o) => o.isPending || o.isConfirmed || o.isShipped).toList();
        } else if (_selectedTab == 1) {
          filteredOrders = orders.where((o) => o.isDelivered).toList();
        } else {
          filteredOrders = orders.where((o) => o.isCancelled).toList();
        }

        if (filteredOrders.isEmpty) {
          return _buildEmptyState('No ${_tabs[_selectedTab].toLowerCase()} orders');
        }

        return ListView.builder(
          shrinkWrap: isWeb,
          physics: isWeb ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
          padding: isWeb ? EdgeInsets.zero : const EdgeInsets.fromLTRB(20, 12, 20, 24),
          itemCount: filteredOrders.length,
          itemBuilder: (context, index) {
            final order = filteredOrders[index];

            Color statusColor = AppColors.primary;
            double progress = 0.5;

            if (order.isPending) {
              statusColor = AppColors.warning;
              progress = 0.2;
            } else if (order.isConfirmed) {
              statusColor = const Color(0xFF0EA5E9);
              progress = 0.4;
            } else if (order.isShipped) {
              statusColor = AppColors.primary;
              progress = 0.8;
            } else if (order.isDelivered) {
              statusColor = AppColors.success;
              progress = 1.0;
            } else if (order.isCancelled) {
              statusColor = AppColors.error;
              progress = 0.0;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildOrderCard(
                order: order,
                farmImage: order.farmerAvatarUrl,
                farmName: order.farmName ?? 'AgriDirect Farm',
                orderId: order.orderNumber,
                itemCount: order.itemCount ?? 1,
                price: '₱${(order.total ?? 0).toStringAsFixed(2)}',
                status: order.status,
                statusColor: statusColor,
                estimatedTime: order.isDelivered ? 'Delivered' : 'Pending Update',
                progress: progress,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrderCard({
    required Order order,
    required String? farmImage,
    required String farmName,
    required String orderId,
    required int itemCount,
    required String price,
    required String status,
    required Color statusColor,
    required String estimatedTime,
    required double progress,
  }) {
    return GestureDetector(
      onTap: () => _showOrderDetails(order),
      child: Container(
        decoration: AppDecorations.cardDecoration.copyWith(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: farmImage != null && farmImage.isNotEmpty
                        ? SafeNetworkImage(
                            imageUrl: farmImage,
                            defaultBucket: 'uploads',
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            placeholder: const Icon(
                              Icons.agriculture_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            errorWidget: const Icon(
                              Icons.agriculture_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          )
                        : const Icon(
                            Icons.agriculture_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        farmName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHeadline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '#${orderId.toUpperCase()}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSubtle,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$itemCount ${itemCount > 1 ? 'items' : 'item'}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSubtle,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  price,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status.toUpperCase(),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  estimatedTime,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: statusColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showOrderDetails(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Track Order',
                      style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.textHeadline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Icon(
                    Icons.messenger_outline_rounded,
                    size: 20,
                    color: AppColors.textHeadline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetails(Order order) {
    final isWeb = MediaQuery.of(context).size.width > 800;

    if (isWeb) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: SingleChildScrollView(
                child: _buildOrderDetailsContent(order),
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: _buildOrderDetailsContent(order),
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildOrderDetailsContent(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handle bar (only on mobile bottom sheet)
        if (MediaQuery.of(context).size.width <= 800)
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.textSubtle.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Order Details',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeadline,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.close_rounded, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Farm Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: order.farmerAvatarUrl != null && order.farmerAvatarUrl!.isNotEmpty
                      ? SafeNetworkImage(
                          imageUrl: order.farmerAvatarUrl,
                          defaultBucket: 'uploads',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: const Icon(
                            Icons.agriculture_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          errorWidget: const Icon(
                            Icons.agriculture_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        )
                      : const Icon(
                          Icons.agriculture_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.farmName ?? 'AgriDirect Farm',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHeadline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order from farm',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Order Number & Status
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Number',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSubtle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#${order.orderNumber}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHeadline,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: _getStatusColor(order.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                order.status.toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  color: _getStatusColor(order.status),
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Timeline Section
        Text(
          'Order Tracking',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textHeadline,
          ),
        ),
        const SizedBox(height: 16),
        _buildTimeline(order),
        const SizedBox(height: 32),

        // Order Items
        Text(
          'Items Ordered',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textHeadline,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${order.itemCount ?? 1} item${(order.itemCount ?? 1) > 1 ? 's' : ''}',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Order placed on ${order.createdAt.toString().split(' ')[0]}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSubtle,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Price Breakdown
        Text(
          'Price Breakdown',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textHeadline,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSubtle,
                    ),
                  ),
                  Text(
                    '₱${(order.subtotal ?? 0).toStringAsFixed(2)}',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Delivery Fee',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSubtle,
                    ),
                  ),
                  Text(
                    '₱${(order.deliveryFee ?? 0).toStringAsFixed(2)}',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
              Divider(
                color: AppColors.textHeadline.withValues(alpha: 0.1),
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHeadline,
                    ),
                  ),
                  Text(
                    '₱${(order.total ?? 0).toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Payment Method
        if (order.paymentMethod != null) ...[
          Text(
            'Payment Method',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeadline,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  order.paymentMethod?.toUpperCase() == 'COD'
                      ? Icons.payments_rounded
                      : Icons.account_balance_wallet_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  order.paymentMethod ?? 'Unknown',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTimeline(Order order) {
    final status = order.status.toUpperCase();
    final steps = [
      {'title': 'Placed', 'desc': 'Order received', 'code': 'PENDING', 'icon': Icons.assignment_turned_in_rounded},
      {'title': 'Confirmed', 'desc': 'Order verified', 'code': 'CONFIRMED', 'icon': Icons.check_circle_rounded},
      {'title': 'Preparing', 'desc': 'Getting ready', 'code': 'PROCESSING', 'icon': Icons.inventory_2_rounded},
      {'title': 'Shipped', 'desc': 'On the way', 'code': 'SHIPPED', 'icon': Icons.local_shipping_rounded},
      {'title': 'Delivered', 'desc': 'Completed', 'code': 'DELIVERED', 'icon': Icons.home_work_rounded},
    ];

    int currentStep = 0;
    if (status == 'CONFIRMED') {
      currentStep = 1;
    } else if (status == 'PROCESSING') {
      currentStep = 2;
    } else if (status == 'SHIPPED') {
      currentStep = 3;
    } else if (status == 'DELIVERED') {
      currentStep = 4;
    } else if (status == 'CANCELLED') {
      currentStep = -1;
    }

    return Column(
      children: List.generate(steps.length, (index) {
        final isCompleted = currentStep >= index && currentStep != -1;
        final isCurrent = currentStep == index;
        final isLast = index == steps.length - 1;

        return IntrinsicHeight(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCompleted ? AppColors.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted ? AppColors.primary : AppColors.textSubtle.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      steps[index]['icon'] as IconData,
                      size: 16,
                      color: isCompleted ? Colors.white : AppColors.textSubtle.withValues(alpha: 0.3),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isCompleted && currentStep > index ? AppColors.primary : AppColors.textSubtle.withValues(alpha: 0.1),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[index]['title'] as String,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                          color: isCompleted ? AppColors.textHeadline : AppColors.textSubtle,
                        ),
                      ),
                      Text(
                        steps[index]['desc'] as String,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isCompleted && index == 0)
                Text(
                  order.createdAt.toString().split(' ')[0],
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle),
                ),
            ],
          ),
        );
      }),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return AppColors.warning;
      case 'CONFIRMED':
      case 'PROCESSING':
        return const Color(0xFF0EA5E9);
      case 'SHIPPED':
        return AppColors.primary;
      case 'DELIVERED':
        return AppColors.success;
      case 'CANCELLED':
      case 'REFUNDED':
        return AppColors.error;
      default:
        return AppColors.textSubtle;
    }
  }
}
