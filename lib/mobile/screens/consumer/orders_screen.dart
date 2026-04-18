import 'package:flutter/material.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/models/order/order_model.dart';
import 'package:agridirect/shared/widgets/image_widgets.dart';
import 'dart:async';

/// Orders Screen - Professional Order Management
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _selectedTab = 0;
  final _tabs = ['Active', 'Completed', 'Cancelled'];

  List<Order>? _orders;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final orders = await OrderService().getMyOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _orders = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildPremiumHeader(),
          _buildSleekTabs(),
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
            color: AppColors.textHeadline.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                      const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 28),
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
                  border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.05)),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search your orders...',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSubtle),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSubtle, size: 22),
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
        border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.05)),
      ),
      child: Stack(
        children: [
          const Icon(Icons.notifications_none_rounded, color: AppColors.textHeadline, size: 24),
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
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ] : [],
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

  Widget _buildOrdersList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_orders == null || _orders!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: AppColors.textSubtle.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'No orders found',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSubtle),
            ),
          ],
        ),
      );
    }

    List<Order> filteredOrders;
    if (_selectedTab == 0) {
      // Active
      filteredOrders = _orders!.where((o) => o.isPending || o.isConfirmed || o.isShipped).toList();
    } else if (_selectedTab == 1) {
      // Completed
      filteredOrders = _orders!.where((o) => o.isDelivered).toList();
    } else {
      // Cancelled
      filteredOrders = _orders!.where((o) => o.isCancelled).toList();
    }

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: AppColors.textSubtle.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'No ${_tabs[_selectedTab].toLowerCase()} orders',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSubtle),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        
        // Map status to color and progress
        Color statusColor = AppColors.primary;
        double progress = 0.5;
        String statusText = order.status;
        
        if (order.isPending) {
          statusColor = AppColors.warning;
          progress = 0.2;
        } else if (order.isConfirmed) {
          statusColor = const Color(0xFF0EA5E9); // Info color
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
            farmImage: order.farmerAvatarUrl,
            farmName: order.farmName ?? 'AgriDirect Farm',
            orderId: order.orderNumber,
            itemCount: order.itemCount ?? 1,
            price: '₱${(order.total ?? 0).toStringAsFixed(2)}',
            status: statusText,
            statusColor: statusColor,
            estimatedTime: order.isDelivered ? 'Delivered' : 'Pending Update',
            progress: progress,
          ),
        );
      },
    );
  }

  Widget _buildOrderCard({
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
    return Container(
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SafeCircleAvatar(
                  imageUrl: farmImage,
                  radius: 28,
                  backgroundColor: Colors.transparent,
                  child: Icon(
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
                    Text(farmName, style: AppTextStyles.headline3.copyWith(fontSize: 16)),
                    Text('Order #$orderId • $itemCount items', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
                  ],
                ),
              ),
              Text(price, style: AppTextStyles.headline3.copyWith(fontSize: 17, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      status.toUpperCase(),
                      style: AppTextStyles.labelSmall.copyWith(color: statusColor, fontWeight: FontWeight.w800, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(estimatedTime, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: statusColor.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Track Order', style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.05)),
                ),
                child: const Icon(Icons.messenger_outline_rounded, size: 20, color: AppColors.textHeadline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
