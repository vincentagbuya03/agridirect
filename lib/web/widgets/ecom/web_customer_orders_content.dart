import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/order/order_model.dart';
import '../../../shared/models/order/order_item_model.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../../shared/router/app_routes.dart';

/// Dedicated Web Orders & Purchases component
class WebCustomerOrdersContent extends StatefulWidget {
  final int initialTabIndex;
  final String? initialOrderId;

  const WebCustomerOrdersContent({
    super.key,
    this.initialTabIndex = 0,
    this.initialOrderId,
  });

  @override
  State<WebCustomerOrdersContent> createState() => _WebCustomerOrdersContentState();
}

class _WebCustomerOrdersContentState extends State<WebCustomerOrdersContent> {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  late int _selectedTab;
  final TextEditingController _searchCtrl = TextEditingController();
  final OrderService _orderService = OrderService();

  bool _isLoading = true;
  String? _errorMessage;
  List<Order> _allOrders = [];
  StreamSubscription<List<Order>>? _ordersSub;
  final Map<String, List<OrderItem>> _itemsCache = {};

  final List<String> _tabs = [
    'All',
    'Pending',
    'To Ship',
    'To Receive',
    'Completed',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex.clamp(0, _tabs.length - 1);
    _searchCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    _initOrders();

    if (widget.initialOrderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openOrderDetailsById(widget.initialOrderId!);
      });
    }
  }

  void _initOrders() {
    // 1. Initial immediate fetch
    _orderService.getMyOrders(limit: 50).then((orders) {
      if (mounted) {
        setState(() {
          _allOrders = orders;
          _isLoading = false;
        });
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    });

    // 2. Realtime updates without re-triggering StreamBuilder teardown
    _ordersSub = _orderService.watchMyOrders(limit: 50).listen(
      (orders) {
        if (mounted) {
          setState(() {
            _allOrders = orders;
            _isLoading = false;
          });
        }
      },
      onError: (err) {
        debugPrint('Realtime orders error: $err');
      },
    );
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<OrderItem>> _getOrderItems(String orderId) async {
    if (_itemsCache.containsKey(orderId)) {
      return _itemsCache[orderId]!;
    }
    final items = await _orderService.getOrderItems(orderId);
    _itemsCache[orderId] = items;
    return items;
  }

  Future<void> _openOrderDetailsById(String orderId) async {
    final order = await _orderService.getOrderById(orderId);
    if (order != null && mounted) {
      _showOrderDetailsDialog(order);
    }
  }

  bool _matchesStatus(Order order, String tab) {
    final status = order.status.toUpperCase();
    switch (tab) {
      case 'All':
        return true;
      case 'Pending':
        return status == 'PENDING' || status == 'UNPAID';
      case 'To Ship':
        return status == 'CONFIRMED' ||
            status == 'PREPARING' ||
            status == 'PROCESSING' ||
            status == 'TO_SHIP';
      case 'To Receive':
        return status == 'SHIPPED' ||
            status == 'OUT_FOR_DELIVERY' ||
            status == 'IN_TRANSIT' ||
            status == 'TO_RECEIVE';
      case 'Completed':
        return status == 'DELIVERED' || status == 'COMPLETED';
      case 'Cancelled':
        return status == 'CANCELLED' || status == 'REFUNDED';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _allOrders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(color: _primary),
        ),
      );
    }

    if (_errorMessage != null && _allOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Could not load orders',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                style: GoogleFonts.inter(fontSize: 13, color: _muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _initOrders();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final allOrders = _allOrders;
    final query = _searchCtrl.text.trim().toLowerCase();

    final filteredOrders = allOrders.where((order) {
      final matchesTab = _matchesStatus(order, _tabs[_selectedTab]);
      if (!matchesTab) return false;

      if (query.isNotEmpty) {
        final orderNum = order.orderNumber.toLowerCase();
        final farm = (order.farmName ?? '').toLowerCase();
        return orderNum.contains(query) || farm.contains(query);
      }
      return true;
    }).toList();

    return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ───
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: _primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Purchases & Deliveries',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Track shipments, view harvest progress, and review your fresh produce orders.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: _border),

              // ─── Filter Tabs & Search Bar ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 750;

                    final tabsWidget = SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_tabs.length, (i) {
                          final title = _tabs[i];
                          final isSelected = _selectedTab == i;
                          final count = allOrders
                              .where((o) => _matchesStatus(o, title))
                              .length;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => setState(() => _selectedTab = i),
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _primary
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? _primary
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      title,
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                    if (count > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white.withValues(alpha: 0.25)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$count',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF64748B),
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

                    final searchField = SizedBox(
                      width: isCompact ? double.infinity : 260,
                      height: 38,
                      child: TextField(
                        controller: _searchCtrl,
                        style: GoogleFonts.inter(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Search order or farm...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                          prefixIcon: const Icon(Icons.search, size: 16),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 14),
                                  onPressed: () => _searchCtrl.clear(),
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: _primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    );

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          tabsWidget,
                          const SizedBox(height: 12),
                          searchField,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: tabsWidget),
                        const SizedBox(width: 16),
                        searchField,
                      ],
                    );
                  },
                ),
              ),

              const Divider(height: 1, color: _border),

              // ─── Orders List ───
              if (filteredOrders.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  itemCount: filteredOrders.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return _buildDesktopOrderCard(order);
                  },
                ),
            ],
          ),
        );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No orders found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _searchCtrl.text.isNotEmpty
                  ? 'Try searching with a different order number or keyword.'
                  : 'You have no ${_tabs[_selectedTab].toLowerCase()} purchases right now.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _muted,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.shop),
              icon: const Icon(Icons.storefront_outlined, size: 16),
              label: const Text('Browse Fresh Harvests'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopOrderCard(Order order) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final formattedDate = dateFormat.format(order.createdAt.toLocal());
    final statusColor = _getStatusColor(order.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          // ─── Card Header: Farm Info & Status ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      size: 18,
                      color: _primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order.farmName ?? 'AgriDirect Partner Farm',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Verified Seller',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(order.status, statusColor),
              ],
            ),
          ),

          // ─── Card Body: Order Items ───
          FutureBuilder<List<OrderItem>>(
            future: _getOrderItems(order.orderId),
            initialData: _itemsCache[order.orderId],
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              final isLoading = snapshot.connectionState == ConnectionState.waiting && items.isEmpty;

              if (isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                    ),
                  ),
                );
              }

              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, color: _muted),
                      const SizedBox(width: 12),
                      Text(
                        'Items: ${order.itemCount ?? 1} fresh produce item(s)',
                        style: GoogleFonts.inter(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  children: items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SafeNetworkImage(
                              imageUrl: item.productImage,
                              defaultBucket: 'products',
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                              errorWidget: Container(
                                width: 54,
                                height: 54,
                                color: const Color(0xFFF1F5F9),
                                child: const Icon(
                                  Icons.eco_rounded,
                                  color: _primary,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName ?? 'Farm Fresh Produce',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: _dark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Qty: ${item.quantity.toInt()}  •  ₱${item.unitPrice.toStringAsFixed(2)} each',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₱${(item.subtotal ?? (item.quantity * item.unitPrice)).toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),

          const Divider(height: 1, color: _border),

          // ─── Card Footer: Metadata, Total, Actions ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;

                final metaInfo = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.orderNumber}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                );

                final totalInfo = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Order Total: ',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: _muted,
                      ),
                    ),
                    Text(
                      '₱${(order.total ?? 0.0).toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                  ],
                );

                final actionButtons = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () => _showOrderDetailsDialog(order),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _dark,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('View Details', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _showOrderTrackingDialog(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Track Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          metaInfo,
                          totalInfo,
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: actionButtons),
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    metaInfo,
                    Row(
                      children: [
                        totalInfo,
                        const SizedBox(width: 20),
                        actionButtons,
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'UNPAID':
        return Colors.amber.shade800;
      case 'CONFIRMED':
      case 'PREPARING':
      case 'PROCESSING':
      case 'TO_SHIP':
        return Colors.blue.shade700;
      case 'SHIPPED':
      case 'OUT_FOR_DELIVERY':
      case 'IN_TRANSIT':
      case 'TO_RECEIVE':
        return Colors.purple.shade700;
      case 'DELIVERED':
      case 'COMPLETED':
        return _primary;
      case 'CANCELLED':
      case 'REFUNDED':
        return Colors.red.shade600;
      default:
        return _muted;
    }
  }

  void _showOrderDetailsDialog(Order order) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order Details',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Order Number: ${order.orderNumber}',
                  style: GoogleFonts.inter(fontSize: 13, color: _muted),
                ),
                const SizedBox(height: 4),
                Text(
                  'Farm: ${order.farmName ?? "AgriDirect Farm"}',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _dark),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal:', style: GoogleFonts.inter(fontSize: 13, color: _muted)),
                    Text('₱${(order.subtotal ?? (order.total ?? 0.0)).toStringAsFixed(2)}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Delivery Fee:', style: GoogleFonts.inter(fontSize: 13, color: _muted)),
                    Text('₱${(order.deliveryFee ?? 0.0).toStringAsFixed(2)}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Amount:',
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: _dark)),
                    Text('₱${(order.total ?? 0.0).toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: _primary)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderTrackingDialog(Order order) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Delivery & Harvest Tracking',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Order #${order.orderNumber}',
                  style: GoogleFonts.inter(fontSize: 12, color: _muted),
                ),
                const SizedBox(height: 20),
                _buildTrackingStep(
                  title: 'Order Confirmed',
                  desc: 'Farmer accepted the order and started preparing harvest.',
                  isDone: true,
                ),
                _buildTrackingStep(
                  title: 'Packing & Quality Check',
                  desc: 'Produce sorted, weighed, and packed for safe transport.',
                  isDone: order.status != 'PENDING',
                ),
                _buildTrackingStep(
                  title: 'Dispatched for Delivery',
                  desc: 'Courier/Rider on the way to your delivery address.',
                  isDone: order.status == 'SHIPPED' || order.status == 'DELIVERED',
                ),
                _buildTrackingStep(
                  title: 'Delivered',
                  desc: 'Fresh farm produce successfully delivered.',
                  isDone: order.status == 'DELIVERED' || order.status == 'COMPLETED',
                  isLast: true,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingStep({
    required String title,
    required String desc,
    required bool isDone,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isDone ? _primary : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDone ? Icons.check : Icons.circle,
                size: 13,
                color: isDone ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isDone ? _primary : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDone ? _dark : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: isDone ? _muted : const Color(0xFFCBD5E1),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}
