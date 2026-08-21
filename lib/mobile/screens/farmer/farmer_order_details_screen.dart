import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/order/order_model.dart';
import '../../../shared/models/order/order_item_model.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/farmer/farmer_service.dart';
import '../../../shared/models/farmer/farmer_profile_model.dart';

class FarmerOrderDetailsScreen extends StatefulWidget {
  final Order order;
  final String customerName;
  final String customerImage;

  const FarmerOrderDetailsScreen({
    super.key,
    required this.order,
    this.customerName = 'Customer',
    this.customerImage = '',
  });

  @override
  State<FarmerOrderDetailsScreen> createState() => _FarmerOrderDetailsScreenState();
}

class _FarmerOrderDetailsScreenState extends State<FarmerOrderDetailsScreen> {
  final OrderService _orderService = OrderService();
  List<OrderItem> _items = [];
  Map<String, dynamic>? _address;
  FarmerProfile? _farmerProfile;
  bool _isLoading = true;
  late String _currentStatus;
  bool _isUpdating = false;

  static const Color _primary = Color(0xFF059669);
  static const Color _primaryDark = Color(0xFF047857);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  List<Map<String, dynamic>> get _steps {
    final isCop = widget.order.paymentMethod?.toUpperCase() == 'COP';
    final isPreorder = widget.order.isPreorder == true;
    return isPreorder
        ? [
            {'title': 'Pre-ordered', 'desc': 'Reservation received', 'icon': Icons.bookmark_added_rounded},
            {'title': 'Confirmed', 'desc': 'Pre-order accepted', 'icon': Icons.check_circle_rounded},
            {'title': 'Growing', 'desc': 'Awaiting harvest', 'icon': Icons.agriculture_rounded},
            {
              'title': isCop ? 'Ready for Pickup' : 'Shipped',
              'desc': isCop ? 'Ready at farm' : 'On the way',
              'icon': isCop ? Icons.storefront_rounded : Icons.local_shipping_rounded,
            },
            {
              'title': isCop ? 'Picked Up' : 'Delivered',
              'desc': 'Completed',
              'icon': isCop ? Icons.done_all_rounded : Icons.home_work_rounded,
            },
          ]
        : [
            {'title': 'Placed', 'desc': 'Order received', 'icon': Icons.assignment_turned_in_rounded},
            {'title': 'Confirmed', 'desc': 'Order accepted', 'icon': Icons.check_circle_rounded},
            {'title': 'Preparing', 'desc': 'Harvesting & packing', 'icon': Icons.inventory_2_rounded},
            {
              'title': isCop ? 'Ready for Pickup' : 'Shipped',
              'desc': isCop ? 'Ready at farm' : 'On the way',
              'icon': isCop ? Icons.storefront_rounded : Icons.local_shipping_rounded,
            },
            {
              'title': isCop ? 'Picked Up' : 'Delivered',
              'desc': 'Completed',
              'icon': isCop ? Icons.done_all_rounded : Icons.home_work_rounded,
            },
          ];
  }

  int get _currentStepIndex {
    switch (_currentStatus) {
      case 'CONFIRMED':
        return 1;
      case 'PROCESSING':
        return 2;
      case 'SHIPPED':
        return 3;
      case 'DELIVERED':
        return 4;
      case 'CANCELLED':
        return -1;
      default:
        return 0; // PENDING
    }
  }

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status.toUpperCase();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final items = await _orderService.getOrderItems(widget.order.orderId);
      String? deliveryAddressId = widget.order.deliveryAddressId;
      if (deliveryAddressId == null || deliveryAddressId.isEmpty) {
        try {
          final orderData = await Supabase.instance.client
              .from('orders')
              .select('delivery_address_id')
              .eq('order_id', widget.order.orderId)
              .maybeSingle();
          if (orderData != null) {
            deliveryAddressId = orderData['delivery_address_id']?.toString();
          }
        } catch (_) {}
      }

      Map<String, dynamic>? address;
      if (deliveryAddressId != null && deliveryAddressId.isNotEmpty) {
        address = await _orderService.getDeliveryAddress(deliveryAddressId);

        if (address != null && (address['latitude'] == null || address['longitude'] == null)) {
          try {
            final street = address['street']?.toString() ?? '';
            final barangay = address['barangay']?.toString() ?? '';
            final city = address['city']?.toString() ?? '';
            final province = address['province']?.toString() ?? '';

            String cleanBrgy(String val) =>
                val.replaceAll(RegExp(r'\b(brgy|brgy\.|barangay)\b', caseSensitive: false), '').trim();
            String cleanStreet(String val) =>
                val.replaceAll(RegExp(r'#\d+'), '').replaceAll(RegExp(r'\d+'), '').trim();

            final listQueries = <String>[];
            final parts1 = <String>[street, barangay, city, province].where((s) => s.isNotEmpty).toList();
            if (parts1.isNotEmpty) listQueries.add(parts1.join(', '));

            final cStreet = cleanStreet(street);
            final cBrgy = cleanBrgy(barangay);
            final parts2 = <String>[cStreet, cBrgy, city, province].where((s) => s.isNotEmpty).toList();
            if (parts2.isNotEmpty) listQueries.add(parts2.join(', '));

            final parts3 = <String>[cBrgy, city, province].where((s) => s.isNotEmpty).toList();
            if (parts3.isNotEmpty) listQueries.add(parts3.join(', '));

            final parts4 = <String>[city, province].where((s) => s.isNotEmpty).toList();
            if (parts4.isNotEmpty) listQueries.add(parts4.join(', '));

            LatLng? foundCoords;
            for (final q in listQueries) {
              if (q.trim().isEmpty) continue;
              final encodedAddr = Uri.encodeComponent(q);
              final searchUri = Uri.parse(
                'https://nominatim.openstreetmap.org/search?format=json&q=$encodedAddr&limit=1',
              );
              final res = await http.get(
                searchUri,
                headers: const {
                  'User-Agent': 'AgriDirect/1.0 (support: noreplyagridirect@gmail.com)',
                },
              );
              if (res.statusCode == 200) {
                final list = jsonDecode(res.body) as List;
                if (list.isNotEmpty) {
                  final first = list.first as Map<String, dynamic>;
                  final latVal = double.tryParse(first['lat']?.toString() ?? '');
                  final lonVal = double.tryParse(first['lon']?.toString() ?? '');
                  if (latVal != null && lonVal != null) {
                    foundCoords = LatLng(latVal, lonVal);
                    break;
                  }
                }
              }
            }

            if (foundCoords != null) {
              address = Map<String, dynamic>.from(address);
              address['latitude'] = foundCoords.latitude;
              address['longitude'] = foundCoords.longitude;
            }
          } catch (_) {}
        }
      }

      FarmerProfile? farmerProfile;
      if (widget.order.farmerId.isNotEmpty) {
        farmerProfile = await FarmerService().getFarmerProfileByFarmerId(widget.order.farmerId);
      }

      if (mounted) {
        setState(() {
          _items = items;
          _address = address;
          _farmerProfile = farmerProfile;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading order details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw >= 960;

    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(isDesktop),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primary),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 36 : 16,
                20,
                isDesktop ? 36 : 16,
                isDesktop ? 48 : 100,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderBanner(isDesktop),
                      const SizedBox(height: 24),
                      if (isDesktop) _buildDesktop2ColumnLayout() else _buildMobileStackedLayout(),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: (!isDesktop && !_isLoading) ? _buildMobileBottomBar() : null,
    );
  }

  // ─── App Bar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(bool isDesktop) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded, color: _dark),
        tooltip: 'Back to Orders',
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDesktop) ...[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'Orders',
                  style: GoogleFonts.inter(fontSize: 14, color: _muted, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 16, color: _muted),
            const SizedBox(width: 8),
          ],
          Text(
            'Order #${widget.order.orderNumber}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: isDesktop ? 16 : 15,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _loadDetails,
          icon: const Icon(Icons.refresh_rounded, color: _muted, size: 20),
          tooltip: 'Refresh Details',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ─── Header Banner ─────────────────────────────────────────────────────────
  Widget _buildHeaderBanner(bool isDesktop) {
    final isCop = widget.order.paymentMethod?.toUpperCase() == 'COP';

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: _primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Order #${widget.order.orderNumber}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isDesktop ? 20 : 16,
                          fontWeight: FontWeight.w900,
                          color: _dark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.order.orderNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Order Number copied!'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Icon(Icons.copy_rounded, size: 14, color: _muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Placed on ${_formatDateTime(widget.order.createdAt)}',
                      style: GoogleFonts.inter(fontSize: 12.5, color: _muted, fontWeight: FontWeight.w500),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCop ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCop ? '🏪 Farm Pickup (COP)' : '🚚 Standard Delivery',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isCop ? const Color(0xFFB45309) : const Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 16),
            _buildStatusBadge(_currentStatus, widget.order.paymentMethod),
          ],
        ],
      ),
    );
  }

  // ─── Desktop 2-Column Layout ───────────────────────────────────────────────
  Widget _buildDesktop2ColumnLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (62%): Fulfillment Pipeline + Items Table + Map
        Expanded(
          flex: 62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFulfillmentPipelineCard(),
              const SizedBox(height: 24),
              _buildHarvestItemsCard(),
              const SizedBox(height: 24),
              _buildDeliveryLocationCard(),
            ],
          ),
        ),
        const SizedBox(width: 24),

        // Right Column (38%): Action Console + Customer Card + Price Breakdown
        Expanded(
          flex: 38,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildActionConsoleCard(),
              const SizedBox(height: 24),
              _buildCustomerCard(),
              const SizedBox(height: 24),
              _buildPriceBreakdownCard(),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Mobile Stacked Layout ─────────────────────────────────────────────────
  Widget _buildMobileStackedLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFulfillmentPipelineCard(),
        const SizedBox(height: 20),
        _buildActionConsoleCard(),
        const SizedBox(height: 20),
        _buildCustomerCard(),
        const SizedBox(height: 20),
        _buildHarvestItemsCard(),
        const SizedBox(height: 20),
        _buildPriceBreakdownCard(),
        const SizedBox(height: 20),
        _buildDeliveryLocationCard(),
      ],
    );
  }

  // ─── 1. Fulfillment Pipeline Stepper Card ──────────────────────────────────
  Widget _buildFulfillmentPipelineCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fulfillment Timeline',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              _buildStatusBadge(_currentStatus, widget.order.paymentMethod),
            ],
          ),
          const SizedBox(height: 20),
          // Stepper row
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              if (isNarrow) {
                // Vertical Stepper for narrow mobile
                return Column(
                  children: List.generate(_steps.length, (i) {
                    final done = _currentStepIndex >= i && _currentStepIndex >= 0;
                    final current = _currentStepIndex == i;
                    final isLast = i == _steps.length - 1;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: current ? _primary : (done ? const Color(0xFFECFDF5) : Colors.white),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: done ? _primary : const Color(0xFFCBD5E1),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _steps[i]['icon'] as IconData,
                                size: 16,
                                color: current ? Colors.white : (done ? _primary : const Color(0xFF94A3B8)),
                              ),
                            ),
                            if (!isLast)
                              Container(
                                width: 2,
                                height: 28,
                                color: done && _currentStepIndex > i ? _primary : const Color(0xFFE2E8F0),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _steps[i]['title'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                                    color: current ? _dark : (done ? const Color(0xFF334155) : _muted),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _steps[i]['desc'] as String,
                                  style: GoogleFonts.inter(fontSize: 11.5, color: _muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                );
              }

              // Horizontal Stepper for desktop & tablets
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(_steps.length, (i) {
                  final done = _currentStepIndex >= i && _currentStepIndex >= 0;
                  final current = _currentStepIndex == i;
                  final isLast = i == _steps.length - 1;

                  return Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: current ? _primary : (done ? const Color(0xFFECFDF5) : Colors.white),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: done ? _primary : const Color(0xFFCBD5E1),
                                    width: 2,
                                  ),
                                  boxShadow: current
                                      ? [
                                          BoxShadow(
                                            color: _primary.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  _steps[i]['icon'] as IconData,
                                  size: 18,
                                  color: current ? Colors.white : (done ? _primary : const Color(0xFF94A3B8)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _steps[i]['title'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                                  color: current ? _dark : (done ? const Color(0xFF334155) : _muted),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _steps[i]['desc'] as String,
                                style: GoogleFonts.inter(fontSize: 10.5, color: _muted),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Container(
                            margin: const EdgeInsets.only(top: 18),
                            height: 2,
                            width: 20,
                            color: done && _currentStepIndex > i ? _primary : const Color(0xFFE2E8F0),
                          ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── 2. Harvest Items Invoice Table Card ───────────────────────────────────
  Widget _buildHarvestItemsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Items (${_items.length})',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              Text(
                'Itemized Breakdown',
                style: GoogleFonts.inter(fontSize: 12, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No items found in this order.', style: GoogleFonts.inter(color: _muted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(height: 20, color: Color(0xFFF8FAFC)),
              itemBuilder: (ctx, i) {
                final item = _items[i];
                return Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: item.productImage != null
                          ? SafeNetworkImage(
                              imageUrl: item.productImage!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              color: const Color(0xFFF1F5F9),
                              child: const Icon(Icons.eco_rounded, size: 24, color: _muted),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName ?? 'Produce Item',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${item.unitPrice.toStringAsFixed(2)} × ${item.quantity}',
                            style: GoogleFonts.inter(fontSize: 12.5, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₱${(item.subtotal ?? (item.unitPrice * item.quantity)).toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _primaryDark,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── 3. Action Console Card (Sidebar / Top Stack) ──────────────────────────
  Widget _buildActionConsoleCard() {
    final isFinished = _currentStatus == 'DELIVERED' || _currentStatus == 'CANCELLED';
    final isCop = widget.order.paymentMethod?.toUpperCase() == 'COP';

    String nextActionLabel = 'Confirm Order';
    String nextStatus = 'CONFIRMED';
    IconData actionIcon = Icons.check_circle_outline_rounded;

    if (_currentStatus == 'CONFIRMED') {
      nextActionLabel = 'Start Preparing Harvest';
      nextStatus = 'PROCESSING';
      actionIcon = Icons.inventory_2_outlined;
    } else if (_currentStatus == 'PROCESSING') {
      nextActionLabel = isCop ? 'Mark Ready for Pickup' : 'Ship via Courier';
      nextStatus = 'SHIPPED';
      actionIcon = isCop ? Icons.storefront_rounded : Icons.local_shipping_outlined;
    } else if (_currentStatus == 'SHIPPED') {
      nextActionLabel = isCop ? 'Complete Buyer Pickup' : 'Mark Delivered';
      nextStatus = 'DELIVERED';
      actionIcon = Icons.done_all_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Text(
            'Order Fulfillment Action',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFinished
                ? 'This order has been completed and finalized.'
                : 'Advance the fulfillment pipeline to keep the buyer updated.',
            style: GoogleFonts.inter(fontSize: 12.5, color: _muted),
          ),
          const SizedBox(height: 16),
          if (!isFinished) ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isUpdating ? null : () => _advanceStatus(nextStatus, nextActionLabel),
                icon: _isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(actionIcon, size: 18),
                label: Text(
                  _isUpdating ? 'Updating...' : nextActionLabel,
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: _isUpdating ? null : _showStatusUpdateSheet,
                icon: const Icon(Icons.edit_note_rounded, size: 18, color: _dark),
                label: Text('Change to Other Status...', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: _dark)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, size: 20, color: _primary),
                  const SizedBox(width: 8),
                  Text(
                    'Order Finalized',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _primaryDark),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 4. Customer Card ──────────────────────────────────────────────────────
  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Text(
            'Buyer Information',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: widget.customerImage.isNotEmpty
                    ? ClipOval(
                        child: SafeNetworkImage(
                          imageUrl: widget.customerImage,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Text(
                          (widget.customerName.isNotEmpty ? widget.customerName[0] : 'C').toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _primary,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customerName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Verified AgriDirect Buyer',
                      style: GoogleFonts.inter(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.push(
                  AppRoutes.farmerMessages,
                  extra: {'customerId': widget.order.customerId},
                );
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: const Text('Message Buyer Directly'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 5. Price Breakdown Card ───────────────────────────────────────────────
  Widget _buildPriceBreakdownCard() {
    final subtotal = widget.order.subtotal ?? widget.order.total ?? 0;
    final fee = widget.order.deliveryFee ?? 0;
    final total = widget.order.total ?? subtotal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Text(
            'Payment Summary',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 16),
          _summaryRow('Subtotal', '₱${subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 10),
          _summaryRow('Delivery Fee', fee > 0 ? '₱${fee.toStringAsFixed(2)}' : 'Free / Included'),
          const SizedBox(height: 10),
          _summaryRow('Payment Method', widget.order.paymentMethod?.toUpperCase() ?? 'COD'),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Payable',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              Text(
                '₱${total.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _primaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: _muted, fontWeight: FontWeight.w500)),
        Text(value, style: GoogleFonts.inter(fontSize: 13, color: _dark, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ─── 6. Delivery Location Card ─────────────────────────────────────────────
  Widget _buildDeliveryLocationCard() {
    if (_address == null) {
      final method = widget.order.paymentMethod?.toUpperCase() ?? '';
      final isPickup = method == 'COP';
      final hasLocation = _farmerProfile?.location != null && _farmerProfile!.location!.isNotEmpty;
      final lat = _farmerProfile?.farmLatitude;
      final lng = _farmerProfile?.farmLongitude;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPickup ? 'Farm Pickup Location' : 'Delivery Address',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 12),
            if (isPickup && hasLocation) ...[
              Text(
                _farmerProfile!.location!,
                style: GoogleFonts.inter(fontSize: 13, color: _dark, fontWeight: FontWeight.w500),
              ),
              if (lat != null && lng != null) ...[
                const SizedBox(height: 14),
                _buildMap(lat, lng),
              ],
            ] else ...[
              Text(
                isPickup
                    ? 'Customer will pick up from your farm address.'
                    : 'Standard customer delivery address on record.',
                style: GoogleFonts.inter(fontSize: 13, color: _muted),
              ),
            ],
          ],
        ),
      );
    }

    final lat = (_address!['latitude'] as num?)?.toDouble();
    final lng = (_address!['longitude'] as num?)?.toDouble();
    final parts = <String>[
      _address!['street']?.toString() ?? '',
      _address!['barangay']?.toString() ?? '',
      _address!['city']?.toString() ?? '',
      _address!['province']?.toString() ?? '',
    ].where((s) => s.isNotEmpty).toList();
    final addressText = parts.join(', ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery Location',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              if (addressText.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    final addressQuery = Uri.encodeComponent(addressText);
                    final mapUrl = 'https://www.google.com/maps/search/?api=1&query=$addressQuery';
                    if (await canLaunchUrl(Uri.parse(mapUrl))) {
                      await launchUrl(Uri.parse(mapUrl), mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.directions_rounded, size: 16, color: _primary),
                  label: Text('Directions', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: _primary)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            addressText.isNotEmpty ? addressText : 'Customer address details provided upon dispatch',
            style: GoogleFonts.inter(fontSize: 13.5, color: _dark, fontWeight: FontWeight.w500),
          ),
          if (_address!['recipient_name'] != null || _address!['recipient_phone'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Recipient: ${_address!['recipient_name'] ?? ''} · ${_address!['recipient_phone'] ?? ''}',
              style: GoogleFonts.inter(fontSize: 12.5, color: _muted),
            ),
          ],
          if (lat != null && lng != null) ...[
            const SizedBox(height: 16),
            _buildMap(lat, lng),
          ],
        ],
      ),
    );
  }

  Widget _buildMap(double lat, double lng) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(initialCenter: LatLng(lat, lng), initialZoom: 15),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.agridirect.app',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: LatLng(lat, lng),
                    width: 60,
                    height: 60,
                    child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
                  ),
                ]),
              ],
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: FloatingActionButton.small(
                heroTag: 'map_nav_btn',
                onPressed: () => _launchNavigation(lat, lng),
                backgroundColor: _primary,
                child: const Icon(Icons.navigation_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Mobile Sticky Bottom Bar ──────────────────────────────────────────────
  Widget _buildMobileBottomBar() {
    final isFinished = _currentStatus == 'DELIVERED' || _currentStatus == 'CANCELLED';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: (isFinished || _isUpdating) ? null : _showStatusUpdateSheet,
          icon: _isUpdating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.edit_note_rounded, size: 18),
          label: Text(
            _isUpdating ? 'Updating...' : (isFinished ? 'Order Finalized' : 'Update Order Status'),
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  // ─── Status Actions & Confirmation ─────────────────────────────────────────
  Future<void> _advanceStatus(String nextStatus, String actionTitle) async {
    final isCop = widget.order.paymentMethod?.toUpperCase() == 'COP';
    setState(() => _isUpdating = true);

    try {
      await OrderService().updateOrderStatus(widget.order.orderId, nextStatus);
      if (mounted) {
        setState(() => _currentStatus = nextStatus);

        String successMsg = 'Order status updated successfully.';
        if (nextStatus == 'SHIPPED') {
          successMsg = isCop
              ? 'Order is ready for farm pickup! Buyer notified.'
              : 'Order marked as shipped and in-transit!';
        } else if (nextStatus == 'DELIVERED') {
          successMsg = isCop
              ? 'Pickup completed! Order finalized.'
              : 'Order delivered successfully!';
        } else if (nextStatus == 'CONFIRMED') {
          successMsg = 'Order accepted! Ready to harvest & pack.';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showStatusUpdateSheet() {
    final isCop = widget.order.paymentMethod?.toUpperCase() == 'COP';
    final allStatuses = [
      {'label': 'CONFIRMED', 'title': 'CONFIRMED', 'icon': Icons.check_circle_outline, 'color': Colors.blue},
      {'label': 'PROCESSING', 'title': 'PROCESSING', 'icon': Icons.loop_rounded, 'color': Colors.indigo},
      {
        'label': 'SHIPPED',
        'title': isCop ? 'READY FOR PICKUP' : 'SHIPPED',
        'icon': isCop ? Icons.storefront_rounded : Icons.local_shipping_outlined,
        'color': Colors.deepPurple,
      },
      {
        'label': 'DELIVERED',
        'title': isCop ? 'COMPLETED PICKUP' : 'DELIVERED',
        'icon': isCop ? Icons.done_all_rounded : Icons.done_all_rounded,
        'color': _primary,
      },
      {'label': 'CANCELLED', 'title': 'CANCELLED', 'icon': Icons.cancel_outlined, 'color': Colors.red},
    ];

    List<Map<String, dynamic>> allowedStatuses = [];
    if (_currentStatus == 'PENDING') {
      allowedStatuses = allStatuses.where((s) => s['label'] == 'CONFIRMED' || s['label'] == 'CANCELLED').toList();
    } else if (_currentStatus == 'CONFIRMED') {
      allowedStatuses = allStatuses.where((s) => s['label'] == 'PROCESSING' || s['label'] == 'CANCELLED').toList();
    } else if (_currentStatus == 'PROCESSING') {
      allowedStatuses = allStatuses.where((s) => s['label'] == 'SHIPPED' || s['label'] == 'CANCELLED').toList();
    } else if (_currentStatus == 'SHIPPED') {
      allowedStatuses = allStatuses.where((s) => s['label'] == 'DELIVERED').toList();
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Update Order Status',
              style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: _dark),
            ),
            const SizedBox(height: 6),
            Text(
              'Select the next status step for Order #${widget.order.orderNumber}',
              style: GoogleFonts.inter(fontSize: 12.5, color: _muted),
            ),
            const SizedBox(height: 20),
            if (allowedStatuses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('No further status updates available.', style: GoogleFonts.inter(color: _muted)),
              )
            else
              ...allowedStatuses.map(
                (s) => ListTile(
                  leading: Icon(s['icon'] as IconData, color: s['color'] as Color),
                  title: Text(
                    s['title'] as String,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _dark),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _advanceStatus(s['label'] as String, s['title'] as String);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Status Badge ──────────────────────────────────────────────────────────
  Widget _buildStatusBadge(String status, dynamic paymentMethod) {
    final isCop = paymentMethod?.toString().toUpperCase() == 'COP';
    Color bg = const Color(0xFFFFFBEB);
    Color fg = const Color(0xFFD97706);
    IconData icon = Icons.hourglass_top_rounded;
    String label = status;

    if (status == 'DELIVERED') {
      bg = const Color(0xFFECFDF5);
      fg = _primary;
      icon = Icons.check_circle_rounded;
      label = isCop ? 'PICKED UP' : 'DELIVERED';
    } else if (status == 'SHIPPED') {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF2563EB);
      icon = isCop ? Icons.storefront_rounded : Icons.local_shipping_rounded;
      label = isCop ? 'READY FOR PICKUP' : 'SHIPPED';
    } else if (status == 'PROCESSING') {
      bg = const Color(0xFFF5F3FF);
      fg = const Color(0xFF7C3AED);
      icon = Icons.inventory_2_rounded;
      label = 'PROCESSING';
    } else if (status == 'CONFIRMED') {
      bg = const Color(0xFFECFEFF);
      fg = const Color(0xFF0891B2);
      icon = Icons.thumb_up_alt_rounded;
      label = 'CONFIRMED';
    } else if (status == 'CANCELLED') {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
      label = 'CANCELLED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  Future<void> _launchNavigation(double lat, double lng) async {
    final url = 'google.navigation:q=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      await launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'));
    }
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $h:$m $ampm';
  }
}

// ─── Animated Status Overlay ─────────────────────────────────────────────────
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

class _StatusSuccessOverlayState extends State<_StatusSuccessOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onFinished());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 24,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Updated',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.message,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF64748B),
                      ),
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
}
