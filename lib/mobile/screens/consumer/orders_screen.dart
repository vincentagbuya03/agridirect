import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/community/notification_service.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/models/order/order_model.dart';
import '../../../shared/router/app_routes.dart';
import 'package:agridirect/shared/widgets/image_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agridirect/shared/services/farmer/farmer_service.dart';
import 'package:agridirect/shared/models/farmer/farmer_profile_model.dart';
import '../../../shared/models/order/order_item_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agridirect/shared/services/core/supabase_config.dart';

/// Orders Screen - Professional Order Management (Responsive Web & Mobile)
class OrdersScreen extends StatefulWidget {
  final String? initialOrderId;
  const OrdersScreen({super.key, this.initialOrderId});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _selectedTab = 0;
  final _tabs = ['Active', 'Completed', 'Cancelled'];
  late Stream<List<Order>> _ordersStream;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ordersStream = OrderService().watchMyOrders();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    if (widget.initialOrderId != null) {
      _loadAndShowOrderDetails(widget.initialOrderId!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAndShowOrderDetails(String orderId) async {
    try {
      final order = await OrderService().getOrderById(orderId);
      if (order != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showOrderDetails(order);
        });
      }
    } catch (e) {
      debugPrint('Error loading initial order details: $e');
    }
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
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.home);
                    }
                  },
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
                  controller: _searchController,
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
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppColors.textSubtle, size: 20),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
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
    final userId = AuthService().userId;
    return FutureBuilder<int>(
      future: NotificationService().getUnreadNotificationCount(userId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return GestureDetector(
          onTap: () => context.push(AppRoutes.notifications),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.textHeadline.withValues(alpha: 0.1),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.textHeadline,
                  size: 24,
                ),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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

        final query = _searchController.text.trim().toLowerCase();
        if (query.isNotEmpty) {
          filteredOrders = filteredOrders.where((o) =>
            o.orderNumber.toLowerCase().contains(query) ||
            o.status.toLowerCase().contains(query) ||
            (o.farmName ?? '').toLowerCase().contains(query) ||
            o.orderId.toLowerCase().contains(query)
          ).toList();
        }

        if (filteredOrders.isEmpty) {
          return _buildEmptyState(query.isNotEmpty ? 'No orders match "$query"' : 'No ${_tabs[_selectedTab].toLowerCase()} orders');
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

            final isCop = order.paymentMethod?.toUpperCase() == 'COP';
            String displayStatus = order.status;
            if (isCop) {
              if (order.isShipped) {
                displayStatus = 'Ready for Pickup';
              } else if (order.isDelivered) {
                displayStatus = 'Picked Up';
              }
            }

            String displayEstimatedTime = 'Pending Update';
            if (order.isDelivered) {
              displayEstimatedTime = isCop ? 'Picked Up' : 'Delivered';
            } else if (order.isShipped) {
              displayEstimatedTime = isCop ? 'Ready for Pickup' : 'Shipped';
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
                status: displayStatus,
                statusColor: statusColor,
                estimatedTime: displayEstimatedTime,
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
                InkWell(
                  onTap: () {
                    context.push(
                      AppRoutes.customerMessages,
                      extra: {'farmerId': order.farmerId},
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
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
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
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

  Future<void> _confirmCancelOrder(BuildContext context, Order order) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancel Order',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to cancel order #${order.orderNumber}? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'No, Keep It',
              style: GoogleFonts.inter(color: AppColors.textSubtle, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Yes, Cancel',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );

      try {
        await OrderService().cancelOrder(order.orderId);
        navigator.pop(); // Pop loading
        navigator.pop(); // Pop details sheet
        messenger.showSnackBar(
          SnackBar(
            content: Text('Order #${order.orderNumber} has been cancelled successfully.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } catch (e) {
        navigator.pop(); // Pop loading
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to cancel order: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildOrderDetailsContent(Order order) {
    final status = order.status.toUpperCase();
    final isCop = order.paymentMethod?.toUpperCase() == 'COP';
    
    double percentage = 20.0;
    int currentStep = 0;
    if (status == 'CONFIRMED') {
      percentage = 40.0;
      currentStep = 1;
    } else if (status == 'PROCESSING') {
      percentage = 60.0;
      currentStep = 2;
    } else if (status == 'SHIPPED') {
      percentage = 80.0;
      currentStep = 3;
    } else if (status == 'DELIVERED') {
      percentage = 100.0;
      currentStep = 4;
    } else if (status == 'CANCELLED') {
      percentage = 0.0;
      currentStep = -1;
    }

    final steps = order.isPreorder == true
        ? [
            {'title': 'Pre-ordered', 'desc': 'Reservation received', 'icon': Icons.bookmark_added_rounded},
            {'title': 'Confirmed', 'desc': 'Pre-order verified', 'icon': Icons.check_circle_rounded},
            {'title': 'Growing', 'desc': 'Awaiting harvest', 'icon': Icons.agriculture_rounded},
            {
              'title': isCop ? 'Ready for Pickup' : 'Shipped',
              'desc': isCop ? 'Ready at farm' : 'On the way',
              'icon': isCop ? Icons.storefront_rounded : Icons.local_shipping_rounded
            },
            {
              'title': isCop ? 'Picked Up' : 'Delivered',
              'desc': 'Completed',
              'icon': isCop ? Icons.done_all_rounded : Icons.home_work_rounded
            },
          ]
        : [
            {'title': 'Placed', 'desc': 'Order received', 'icon': Icons.assignment_turned_in_rounded},
            {'title': 'Confirmed', 'desc': 'Order verified', 'icon': Icons.check_circle_rounded},
            {'title': 'Preparing', 'desc': 'Getting ready', 'icon': Icons.inventory_2_rounded},
            {
              'title': isCop ? 'Ready for Pickup' : 'Shipped',
              'desc': isCop ? 'Ready at farm' : 'On the way',
              'icon': isCop ? Icons.storefront_rounded : Icons.local_shipping_rounded
            },
            {
              'title': isCop ? 'Picked Up' : 'Delivered',
              'desc': 'Completed',
              'icon': isCop ? Icons.done_all_rounded : Icons.home_work_rounded
            },
          ];

    final activeStep = currentStep >= 0 
        ? steps[currentStep] 
        : {'title': 'Cancelled', 'desc': 'Order cancelled', 'icon': Icons.cancel_rounded};

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

        // Title Header
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

        // Farm Info Card & Address
        FutureBuilder<FarmerProfile?>(
          future: FarmerService().getFarmerProfileByFarmerId(order.farmerId),
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final isReadyForPickup = order.status.toUpperCase() == 'SHIPPED';
            final hasLocation = profile?.location != null && profile!.location!.isNotEmpty;
            final hasCoords = profile?.farmLatitude != null && profile?.farmLongitude != null;
            final shouldShowFarmAddress = isCop && isReadyForPickup && hasLocation;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                if (order.isDelivered) ...[
                  const SizedBox(height: 12),
                  _FarmerRatingSection(order: order),
                ],
                if (snapshot.connectionState == ConnectionState.waiting) ...[
                  const SizedBox(height: 12),
                  const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                    child: LinearProgressIndicator(
                      color: AppColors.primary,
                      backgroundColor: Colors.transparent,
                      minHeight: 2,
                    ),
                  ),
                ] else if (shouldShowFarmAddress) ...[
                  const SizedBox(height: 12),
                  Container(
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
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Farm Address',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textHeadline,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          profile.location ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textBody,
                            height: 1.4,
                          ),
                        ),
                        if (hasCoords) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final lat = profile.farmLatitude;
                                final lng = profile.farmLongitude;
                                final url = 'google.navigation:q=$lat,$lng';
                                if (await canLaunchUrl(Uri.parse(url))) {
                                    await launchUrl(Uri.parse(url));
                                } else {
                                    await launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'));
                                }
                              },
                              icon: const Icon(Icons.directions_rounded, size: 18),
                              label: Text(
                                'Get Directions',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // Order Number Stats Header (TikTok Style)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.06)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.orderNumber}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHeadline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${order.itemCount ?? 1} item${(order.itemCount ?? 1) > 1 ? 's' : ''} • ₱${(order.total ?? 0).toStringAsFixed(2)}',
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
              const SizedBox(width: 12),
              _CircularProgressRing(
                percentage: percentage,
                color: status == 'CANCELLED' ? AppColors.error : AppColors.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Prominent Current Status Card (TikTok Style)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: status == 'CANCELLED'
                  ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                  : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: (status == 'CANCELLED' ? Colors.red : Colors.blue)
                    .withValues(alpha: 0.25),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      activeStep['icon'] as IconData,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeStep['title'] as String,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeStep['desc'] as String,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Horizontal progress steps inside the card
              _HorizontalProgressLine(
                currentStep: currentStep,
                totalSteps: steps.length,
                activeColor: Colors.white,
                inactiveColor: Colors.white,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Timeline Section
        Text(
          'Timeline',
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
        FutureBuilder<List<OrderItem>>(
          future: OrderService().getOrderItems(order.orderId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No item details found.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSubtle),
                ),
              );
            }
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.06)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => Divider(
                  color: AppColors.textHeadline.withValues(alpha: 0.05),
                  height: 24,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _OrderItemRow(item: item, order: order);
                },
              ),
            );
          },
        ),
        const SizedBox(height: 32),

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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.06)),
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
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Divider(
                color: AppColors.textHeadline.withValues(alpha: 0.06),
                height: 24,
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.06)),
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
        if (!order.isShipped && !order.isDelivered && !order.isCancelled) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _confirmCancelOrder(context, order),
              icon: const Icon(Icons.cancel_outlined, color: Colors.white),
              label: Text(
                'Cancel Order',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 2,
                shadowColor: AppColors.error.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTimeline(Order order) {
    final status = order.status.toUpperCase();
    final isCop = order.paymentMethod?.toUpperCase() == 'COP';
    final steps = order.isPreorder == true
        ? [
            {'title': 'Pre-ordered', 'desc': 'Reservation received', 'code': 'PENDING', 'icon': Icons.bookmark_added_rounded},
            {'title': 'Confirmed', 'desc': 'Pre-order verified', 'code': 'CONFIRMED', 'icon': Icons.check_circle_rounded},
            {'title': 'Growing', 'desc': 'Awaiting harvest', 'code': 'PROCESSING', 'icon': Icons.agriculture_rounded},
            {
              'title': isCop ? 'Ready for Pickup' : 'Shipped',
              'desc': isCop ? 'Ready at farm' : 'On the way',
              'code': 'SHIPPED',
              'icon': isCop ? Icons.storefront_rounded : Icons.local_shipping_rounded
            },
            {
              'title': isCop ? 'Picked Up' : 'Delivered',
              'desc': 'Completed',
              'code': 'DELIVERED',
              'icon': isCop ? Icons.done_all_rounded : Icons.home_work_rounded
            },
          ]
        : [
            {'title': 'Placed', 'desc': 'Order received', 'code': 'PENDING', 'icon': Icons.assignment_turned_in_rounded},
            {'title': 'Confirmed', 'desc': 'Order verified', 'code': 'CONFIRMED', 'icon': Icons.check_circle_rounded},
            {'title': 'Preparing', 'desc': 'Getting ready', 'code': 'PROCESSING', 'icon': Icons.inventory_2_rounded},
            {
              'title': isCop ? 'Ready for Pickup' : 'Shipped',
              'desc': isCop ? 'Ready at farm' : 'On the way',
              'code': 'SHIPPED',
              'icon': isCop ? Icons.storefront_rounded : Icons.local_shipping_rounded
            },
            {
              'title': isCop ? 'Picked Up' : 'Delivered',
              'code': 'DELIVERED',
              'desc': 'Completed',
              'icon': isCop ? Icons.done_all_rounded : Icons.home_work_rounded
            },
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
}

class _CircularProgressRing extends StatelessWidget {
  final double percentage;
  final Color color;

  const _CircularProgressRing({
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: percentage),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                value: value / 100.0,
                strokeWidth: 4,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '${value.toInt()}%',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HorizontalProgressLine extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final Color activeColor;
  final Color inactiveColor;

  const _HorizontalProgressLine({
    required this.currentStep,
    required this.totalSteps,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps * 2 - 1, (index) {
        if (index.isEven) {
          // Circle Dot
          final stepIndex = index ~/ 2;
          final isActive = stepIndex <= currentStep;
          return Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? activeColor : inactiveColor.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          );
        } else {
          // Connecting Line
          final lineIndex = index ~/ 2;
          final isActive = lineIndex < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              color: isActive ? activeColor : inactiveColor.withValues(alpha: 0.15),
            ),
          );
        }
      }),
    );
  }
}

class _OrderItemRow extends StatefulWidget {
  final OrderItem item;
  final Order order;

  const _OrderItemRow({
    required this.item,
    required this.order,
  });

  @override
  State<_OrderItemRow> createState() => _OrderItemRowState();
}

class _OrderItemRowState extends State<_OrderItemRow> {
  bool _hasReviewed = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkReviewStatus();
  }

  Future<void> _checkReviewStatus() async {
    try {
      final userId = AuthService().userId;
      final customerResponse = await SupabaseConfig.client
          .from('customers')
          .select('customer_id')
          .eq('user_id', userId)
          .maybeSingle();

      final customerId = customerResponse?['customer_id']?.toString();
      if (customerId != null) {
        final reviewResponse = await SupabaseConfig.client
            .from('product_reviews')
            .select('review_id')
            .eq('order_id', widget.order.orderId)
            .eq('product_id', widget.item.productId)
            .eq('customer_id', customerId)
            .maybeSingle();
        if (mounted) {
          setState(() {
            _hasReviewed = reviewResponse != null;
            _checking = false;
          });
        }
      } else {
        if (mounted) setState(() => _checking = false);
      }
    } catch (e) {
      debugPrint('Error checking review status: $e');
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showWriteReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _WriteReviewDialog(
        item: widget.item,
        order: widget.order,
        onReviewSubmitted: () {
          setState(() {
            _hasReviewed = true;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.productImage != null
                  ? SafeNetworkImage(
                      imageUrl: item.productImage,
                      defaultBucket: 'products',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    )
                  : const Icon(
                      Icons.shopping_basket_rounded,
                      color: AppColors.primary,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName ?? 'Product',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textHeadline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${item.quantity.toInt()} x ₱${item.unitPrice.toStringAsFixed(2)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSubtle,
                  ),
                ),
                if (widget.order.isDelivered && !_checking) ...[
                  const SizedBox(height: 6),
                  _hasReviewed
                      ? Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reviewed',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        )
                      : MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _showWriteReviewDialog(context),
                            child: Text(
                              'Write a Review',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₱${(item.subtotal ?? (item.quantity * item.unitPrice)).toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textHeadline,
            ),
          ),
        ],
      ),
    );
  }
}

class _FarmerRatingSection extends StatefulWidget {
  final Order order;

  const _FarmerRatingSection({required this.order});

  @override
  State<_FarmerRatingSection> createState() => _FarmerRatingSectionState();
}

class _FarmerRatingSectionState extends State<_FarmerRatingSection> {
  bool _hasRated = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkRatingStatus();
  }

  Future<void> _checkRatingStatus() async {
    try {
      final userId = AuthService().userId;
      final customerResponse = await SupabaseConfig.client
          .from('customers')
          .select('customer_id')
          .eq('user_id', userId)
          .maybeSingle();

      final customerId = customerResponse?['customer_id']?.toString();
      if (customerId != null) {
        final ratingResponse = await SupabaseConfig.client
            .from('farmer_ratings')
            .select('rating_id')
            .eq('order_id', widget.order.orderId)
            .eq('farmer_id', widget.order.farmerId)
            .eq('customer_id', customerId)
            .maybeSingle();
        if (mounted) {
          setState(() {
            _hasRated = ratingResponse != null;
            _checking = false;
          });
        }
      } else {
        if (mounted) setState(() => _checking = false);
      }
    } catch (e) {
      debugPrint('Error checking farmer rating status: $e');
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showRateFarmerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _RateFarmerDialog(
        order: widget.order,
        onRatingSubmitted: () {
          setState(() {
            _hasRated = true;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _hasRated
            ? AppColors.success.withValues(alpha: 0.05)
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasRated
              ? AppColors.success.withValues(alpha: 0.2)
              : AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _hasRated ? Icons.stars_rounded : Icons.star_border_rounded,
                color: _hasRated ? AppColors.success : AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _hasRated ? 'Farmer Rated' : 'Rate this Farmer',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _hasRated ? AppColors.success : AppColors.primary,
                ),
              ),
            ],
          ),
          if (!_hasRated)
            TextButton(
              onPressed: () => _showRateFarmerDialog(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Rate Now',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Row(
              children: [
                const Icon(Icons.check_rounded, color: AppColors.success, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Completed',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WriteReviewDialog extends StatefulWidget {
  final OrderItem item;
  final Order order;
  final VoidCallback onReviewSubmitted;

  const _WriteReviewDialog({
    required this.item,
    required this.order,
    required this.onReviewSubmitted,
  });

  @override
  State<_WriteReviewDialog> createState() => _WriteReviewDialogState();
}

class _WriteReviewDialogState extends State<_WriteReviewDialog> {
  double _rating = 5.0;
  final _reviewTextController = TextEditingController();
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _reviewImageUrl;

  @override
  void dispose() {
    _reviewTextController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploadingImage || _isSaving) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final bytes = await image.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_review_${image.name}';
      final path = 'reviews/$fileName';

      final resultPath = await SupabaseDatabase.uploadImage(
        bucket: 'uploads',
        path: path,
        bytes: bytes,
      );

      if (resultPath != null) {
        final publicUrl = SupabaseConfig.client.storage
            .from('uploads')
            .getPublicUrl(path);

        setState(() {
          _reviewImageUrl = publicUrl;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading review image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading review image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _submitReview() async {
    setState(() => _isSaving = true);
    try {
      final userId = AuthService().userId;
      final customerResponse = await SupabaseConfig.client
          .from('customers')
          .select('customer_id')
          .eq('user_id', userId)
          .maybeSingle();

      final customerId = customerResponse?['customer_id']?.toString();
      if (customerId == null) {
        throw Exception('Customer profile not found');
      }

      final reviewResult = await SupabaseConfig.client
          .from('product_reviews')
          .insert({
            'product_id': widget.item.productId,
            'customer_id': customerId,
            'order_id': widget.order.orderId,
            'rating': _rating,
            'review_text': _reviewTextController.text.trim().isEmpty ? null : _reviewTextController.text.trim(),
            'is_verified_purchase': true,
          })
          .select('review_id')
          .single();

      final reviewId = reviewResult['review_id']?.toString();
      if (reviewId != null && _reviewImageUrl != null) {
        await SupabaseConfig.client
            .from('review_images')
            .insert({
              'review_id': reviewId,
              'image_url': _reviewImageUrl!,
            });
      }

      widget.onReviewSubmitted();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your review has been submitted.'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting review: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Write a Review',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textHeadline,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.item.productName ?? 'Product',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHeadline,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starVal = index + 1;
                          return IconButton(
                            icon: Icon(
                              _rating >= starVal
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: Colors.amber,
                              size: 36,
                            ),
                            onPressed: () => setState(() => _rating = starVal.toDouble()),
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _rating == 1
                            ? 'Terrible'
                            : _rating == 2
                                ? 'Poor'
                                : _rating == 3
                                    ? 'Fair'
                                    : _rating == 4
                                        ? 'Good'
                                        : 'Excellent!',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Review Description',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHeadline,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reviewTextController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Share details of your experience with this product...',
                    hintStyle: GoogleFonts.inter(color: AppColors.textSubtle, fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.textSubtle.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Add Photo',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHeadline,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.textSubtle.withValues(alpha: 0.2),
                          ),
                        ),
                        child: _isUploadingImage
                            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                            : const Icon(Icons.add_a_photo_rounded, color: AppColors.primary),
                      ),
                    ),
                    if (_reviewImageUrl != null) ...[
                      const SizedBox(width: 16),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.textSubtle.withValues(alpha: 0.2),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SafeNetworkImage(
                            imageUrl: _reviewImageUrl!,
                            defaultBucket: 'uploads',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving || _isUploadingImage ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Submit Review',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
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

class _RateFarmerDialog extends StatefulWidget {
  final Order order;
  final VoidCallback onRatingSubmitted;

  const _RateFarmerDialog({
    required this.order,
    required this.onRatingSubmitted,
  });

  @override
  State<_RateFarmerDialog> createState() => _RateFarmerDialogState();
}

class _RateFarmerDialogState extends State<_RateFarmerDialog> {
  double _rating = 5.0;
  final _reviewTextController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _reviewTextController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    setState(() => _isSaving = true);
    try {
      final userId = AuthService().userId;
      final customerResponse = await SupabaseConfig.client
          .from('customers')
          .select('customer_id')
          .eq('user_id', userId)
          .maybeSingle();

      final customerId = customerResponse?['customer_id']?.toString();
      if (customerId == null) {
        throw Exception('Customer profile not found');
      }

      await SupabaseConfig.client
          .from('farmer_ratings')
          .insert({
            'farmer_id': widget.order.farmerId,
            'customer_id': customerId,
            'order_id': widget.order.orderId,
            'rating': _rating,
            'review_text': _reviewTextController.text.trim().isEmpty ? null : _reviewTextController.text.trim(),
          });

      widget.onRatingSubmitted();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your rating for the farmer has been submitted.'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting farmer rating: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rate Farmer',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textHeadline,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.order.farmName ?? 'Farmer / Farm',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHeadline,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starVal = index + 1;
                          return IconButton(
                            icon: Icon(
                              _rating >= starVal
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: Colors.amber,
                              size: 36,
                            ),
                            onPressed: () => setState(() => _rating = starVal.toDouble()),
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _rating == 1
                            ? 'Terrible'
                            : _rating == 2
                                ? 'Poor'
                                : _rating == 3
                                    ? 'Fair'
                                    : _rating == 4
                                        ? 'Good'
                                        : 'Excellent!',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Review details (optional)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHeadline,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reviewTextController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Share details of your experience with this farmer...',
                    hintStyle: GoogleFonts.inter(color: AppColors.textSubtle, fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.textSubtle.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submitRating,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Submit Rating',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
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
