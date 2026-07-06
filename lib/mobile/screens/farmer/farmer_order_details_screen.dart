import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/models/order/order_model.dart';
import '../../../shared/models/order/order_item_model.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/widgets/image_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
            {'title': 'Confirmed', 'desc': 'Order accepted', 'icon': Icons.check_circle_rounded},
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
  }

  int get _currentStepIndex {
    switch (_currentStatus) {
      case 'CONFIRMED': return 1;
      case 'PROCESSING': return 2;
      case 'SHIPPED': return 3;
      case 'DELIVERED': return 4;
      case 'CANCELLED': return -1;
      default: return 0;
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
      Map<String, dynamic>? address;
      if (widget.order.deliveryAddressId != null && widget.order.deliveryAddressId!.isNotEmpty) {
        address = await _orderService.getDeliveryAddress(widget.order.deliveryAddressId!);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textHeadline),
        ),
        title: Text('Track Order', style: AppTextStyles.headline3.copyWith(fontSize: 18)),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: (_currentStatus == 'DELIVERED' || _currentStatus == 'CANCELLED')
                  ? null
                  : () => _showStatusUpdateSheet(),
              icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _isLoading
            ? const Center(
                key: ValueKey('loading'),
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                key: const ValueKey('content'),
                physics: const BouncingScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroCard(),
                          const SizedBox(height: 28),
                          _buildSectionLabel('Timeline'),
                          const SizedBox(height: 14),
                          _buildTimeline(),
                          const SizedBox(height: 28),
                          _buildCustomerCard(),
                          const SizedBox(height: 28),
                          _buildSectionLabel('Order Items'),
                          const SizedBox(height: 14),
                          _buildItemsList(),
                          const SizedBox(height: 28),
                          _buildSectionLabel('Price Breakdown'),
                          const SizedBox(height: 14),
                          _buildPriceBreakdown(),
                          const SizedBox(height: 28),
                          _buildSectionLabel('Delivery Location'),
                          const SizedBox(height: 14),
                          _buildDeliverySection(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
      bottomNavigationBar: _isLoading ? null : _buildBottomBar(),
    );
  }

  // ── Hero Card ──
  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${widget.order.orderNumber}',
                  style: AppTextStyles.headline3.copyWith(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_items.length} items · ₱${(widget.order.total ?? 0).toStringAsFixed(2)}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _currentStatus == 'CANCELLED' 
                  ? Colors.red.withValues(alpha: 0.08)
                  : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _currentStatus == 'CANCELLED'
                    ? Colors.red.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              _currentStatus,
              style: AppTextStyles.labelSmall.copyWith(
                color: _currentStatus == 'CANCELLED' ? Colors.red : AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Label ──
  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text, style: AppTextStyles.headline3.copyWith(fontSize: 16, letterSpacing: 0.3)),
    );
  }

  // ── Timeline ──
  Widget _buildTimeline() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List.generate(_steps.length, (i) {
          final done = _currentStepIndex >= i && _currentStepIndex >= 0;
          final current = _currentStepIndex == i;
          final isLast = i == _steps.length - 1;
          
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Circle and Line
              SizedBox(
                width: 36,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: current 
                            ? AppColors.primary 
                            : done 
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: done ? AppColors.primary : AppColors.textSubtle.withValues(alpha: 0.2),
                          width: 2,
                        ),
                        boxShadow: current ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ] : null,
                      ),
                      child: Icon(
                        _steps[i]['icon'] as IconData, size: 18,
                        color: current 
                            ? Colors.white 
                            : done 
                                ? AppColors.primary 
                                : AppColors.textSubtle.withValues(alpha: 0.3),
                      ),
                    ),
                    if (!isLast)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 2,
                        height: 32, // Fixed height connector
                        color: done && _currentStepIndex > i
                            ? AppColors.primary
                            : AppColors.textSubtle.withValues(alpha: 0.1),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right Column: Text Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _steps[i]['title'] as String,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                          fontSize: current ? 15 : 14,
                          color: current 
                              ? AppColors.textHeadline 
                              : done 
                                  ? AppColors.textHeadline.withValues(alpha: 0.8)
                                  : AppColors.textSubtle,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _steps[i]['desc'] as String,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: current ? AppColors.textHeadline.withValues(alpha: 0.6) : AppColors.textSubtle,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (done && i == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _formatTime(widget.order.createdAt),
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  // ── Customer Card ──
  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: widget.customerImage.isNotEmpty
                ? ClipOval(
                    child: SafeNetworkImage(
                      imageUrl: widget.customerImage,
                      width: 52, height: 52, fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.person_rounded, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.customerName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  'Payment: ${widget.order.paymentMethod ?? 'COD'}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              context.push(
                AppRoutes.farmerMessages,
                extra: {'customerId': widget.order.customerId},
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Items List ──
  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: Text('No items found')),
      );
    }
    return Column(
      children: _items.map((item) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: item.productImage != null
                  ? SafeNetworkImage(imageUrl: item.productImage!, width: 64, height: 64, fit: BoxFit.cover)
                  : Container(width: 64, height: 64, color: AppColors.background,
                      child: const Icon(Icons.eco_rounded, size: 28, color: AppColors.textSubtle)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName ?? 'Product', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Qty: ${item.quantity} x ₱${item.unitPrice.toStringAsFixed(2)}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
                ],
              ),
            ),
            Text('₱${(item.subtotal ?? 0).toStringAsFixed(2)}',
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ],
        ),
      )).toList(),
    );
  }

  // ── Price Breakdown ──
  Widget _buildPriceBreakdown() {
    final subtotal = widget.order.subtotal ?? widget.order.total ?? 0;
    final fee = widget.order.deliveryFee ?? 0;
    final total = widget.order.total ?? subtotal;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          _priceRow('Subtotal', '₱${subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          _priceRow('Delivery Fee', fee > 0 ? '₱${fee.toStringAsFixed(2)}' : 'Free'),
          Divider(color: AppColors.textHeadline.withValues(alpha: 0.06), height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppTextStyles.headline3.copyWith(fontSize: 16)),
              Text('₱${total.toStringAsFixed(2)}',
                  style: AppTextStyles.headline3.copyWith(fontSize: 18, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSubtle, fontWeight: FontWeight.w500)),
        Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textHeadline)),
      ],
    );
  }

  // ── Delivery Section ──
  Widget _buildDeliverySection() {
    if (_address == null) {
      final method = widget.order.paymentMethod?.toUpperCase() ?? '';
      final isPickup = method == 'COP';
      final isReadyForPickup = widget.order.status.toUpperCase() == 'SHIPPED';
      final hasLocation = _farmerProfile?.location != null && _farmerProfile!.location!.isNotEmpty;
      final lat = _farmerProfile?.farmLatitude;
      final lng = _farmerProfile?.farmLongitude;
      final shouldShowFarmAddress = isPickup && isReadyForPickup && hasLocation;

      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isPickup
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : Colors.orange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPickup
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isPickup ? Icons.store_rounded : Icons.location_off_rounded,
                  color: isPickup ? AppColors.primary : Colors.orange,
                  size: 36,
                ),
                const SizedBox(height: 10),
                Text(
                  isPickup ? 'Cash on Pickup' : 'Address Not Found',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  isPickup
                      ? 'Customer will pick up from your farm location'
                      : 'No delivery address ID associated with this order (check database v_orders view).',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle),
                ),
              ],
            ),
          ),
          if (shouldShowFarmAddress) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Farm Pickup Address',
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_farmerProfile!.location!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
                ],
              ),
            ),
            if (lat != null && lng != null) ...[
              const SizedBox(height: 16),
              Container(
                key: ValueKey('farm_map_${lat}_$lng'),
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.08)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
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
                              point: LatLng(lat, lng), width: 80, height: 80,
                              child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                            ),
                          ]),
                        ],
                      ),
                      Positioned(
                        bottom: 12, right: 12,
                        child: FloatingActionButton.small(
                          heroTag: 'farm_nav_btn',
                          onPressed: () => _launchNavigation(lat, lng),
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.navigation_rounded, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
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

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _address!['label']?.toString() ?? 'Delivery Address',
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (addressText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(addressText, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
              ],
              if (_address!['recipient_name'] != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textSubtle),
                    const SizedBox(width: 8),
                    Text('${_address!['recipient_name']}', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
              if (_address!['recipient_phone'] != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 16, color: AppColors.textSubtle),
                    const SizedBox(width: 8),
                    Text('${_address!['recipient_phone']}', style: AppTextStyles.bodySmall),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (lat != null && lng != null) ...[
          const SizedBox(height: 16),
          Container(
            key: ValueKey('map_${lat}_$lng'),
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.08)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
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
                          point: LatLng(lat, lng), width: 80, height: 80,
                          child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                        ),
                      ]),
                    ],
                  ),
                  Positioned(
                    bottom: 12, right: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'nav_btn',
                      onPressed: () => _launchNavigation(lat, lng),
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.navigation_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Bottom Bar ──
  Widget _buildBottomBar() {
    final isFinished = _currentStatus == 'DELIVERED' || _currentStatus == 'CANCELLED';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 40,
              child: ElevatedButton.icon(
                onPressed: isFinished ? null : () => _showStatusUpdateSheet(),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Update Status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFinished ? Colors.grey.shade400 : AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: isFinished ? 0 : 6,
                  shadowColor: isFinished ? Colors.transparent : AppColors.primary.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  minimumSize: const Size(double.infinity, 54),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status Update Sheet ──
  void _showStatusUpdateSheet() {
    final isCop = widget.order.paymentMethod?.toUpperCase() == 'COP';
    final allStatuses = [
      {'label': 'CONFIRMED', 'title': 'CONFIRMED', 'icon': Icons.check_circle_outline, 'color': Colors.blue},
      {'label': 'PROCESSING', 'title': 'PROCESSING', 'icon': Icons.loop_rounded, 'color': Colors.indigo},
      {
        'label': 'SHIPPED',
        'title': isCop ? 'READY FOR PICKUP' : 'SHIPPED',
        'icon': isCop ? Icons.storefront_rounded : Icons.local_shipping_outlined,
        'color': Colors.deepPurple
      },
      {
        'label': 'DELIVERED',
        'title': isCop ? 'COMPLETED PICKUP' : 'DELIVERED',
        'icon': isCop ? Icons.done_all_rounded : Icons.done_all_rounded,
        'color': Colors.green
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.textSubtle.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Update Order Status', style: AppTextStyles.headline3),
            const SizedBox(height: 6),
            Text('Select the next status step', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
            const SizedBox(height: 20),
            if (allowedStatuses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('No further status updates available.', style: AppTextStyles.bodyMedium),
              )
            else
              ...allowedStatuses.map((s) => ListTile(
                leading: Icon(s['icon'] as IconData, color: s['color'] as Color),
                title: Text(s['title'] as String, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await OrderService().updateOrderStatus(widget.order.orderId, s['label'] as String);
                    if (mounted) {
                      setState(() => _currentStatus = (s['label'] as String).toUpperCase());
                      
                      String successMsg = 'Order status updated successfully.';
                      if (s['label'] == 'SHIPPED') {
                        successMsg = isCop 
                            ? 'Order is ready for pickup! Customer has been notified.' 
                            : 'Order is shipped and on the way!';
                      } else if (s['label'] == 'DELIVERED') {
                        successMsg = isCop 
                            ? 'Pickup completed successfully! Order finalized.' 
                            : 'Order delivered successfully!';
                      } else if (s['label'] == 'CONFIRMED') {
                        successMsg = 'Order accepted! Preparing items.';
                      }

                      late OverlayEntry overlayEntry;
                      overlayEntry = OverlayEntry(
                        builder: (context) => Scaffold(
                          backgroundColor: Colors.transparent,
                          body: _StatusSuccessOverlay(
                            statusTitle: s['title'] as String,
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
                        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              )),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──
  Future<void> _launchNavigation(double lat, double lng) async {
    final url = 'google.navigation:q=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      await launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'));
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

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
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.easeOutBack)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 15),
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
