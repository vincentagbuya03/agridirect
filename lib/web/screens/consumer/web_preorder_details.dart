import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/services/core/supabase_data_service.dart';

/// Web-only Pre-order Product Details — two-column layout.
/// Completely separate UI from the mobile product details.
class WebPreorderDetails extends StatefulWidget {
  const WebPreorderDetails({super.key, this.initialProduct});

  final ProductItem? initialProduct;

  @override
  State<WebPreorderDetails> createState() => _WebPreorderDetailsState();
}

class _WebPreorderDetailsState extends State<WebPreorderDetails> {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _accent = Color(0xFF22C55E);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _surface = Color(0xFFFAFAFA);

  int _quantity = 10;
  bool _isSubmittingOrder = false;
  String _selectedPaymentMethod = 'COD';
  ProductItem? _activeProduct;

  static const List<String> _paymentOptions = ['COD', 'COP'];

  @override
  void initState() {
    super.initState();
    _activeProduct = widget.initialProduct;
    if (_activeProduct == null) {
      _loadDefaultProduct();
    }
  }

  Future<void> _loadDefaultProduct() async {
    try {
      final products = await SupabaseDataService().getPreOrderProducts();
      if (!mounted || products.isEmpty) return;
      setState(() {
        _activeProduct = products.first;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 900;

          return Column(
            children: [
              _buildTopBar(context, isCompact: isCompact),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isCompact ? 20 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBreadcrumbs(),
                      SizedBox(height: isCompact ? 18 : 24),
                      _buildMainContent(isCompact: isCompact),
                      SizedBox(height: isCompact ? 36 : 48),
                      _buildFarmSection(),
                      SizedBox(height: isCompact ? 36 : 48),
                      _buildRelatedProducts(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Top Bar ───
  Widget _buildTopBar(BuildContext context, {required bool isCompact}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 32,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                  color: _dark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Product Details',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
          ),
          const Spacer(),
          if (!isCompact) ...[
            _buildHeaderButton(Icons.share_rounded, 'Share'),
            const SizedBox(width: 12),
            _buildHeaderButton(Icons.favorite_border_rounded, 'Save'),
          ] else ...[
            _buildHeaderIcon(Icons.share_rounded),
            const SizedBox(width: 8),
            _buildHeaderIcon(Icons.favorite_border_rounded),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Icon(icon, size: 16, color: _dark),
    );
  }

  Widget _buildHeaderButton(IconData icon, String label) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _dark),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Breadcrumbs ───
  Widget _buildBreadcrumbs() {
    final productName = _activeProduct?.name.trim().isNotEmpty == true
        ? _activeProduct!.name
        : 'Pre-order product';
    return Row(
      children: [
        Text('Marketplace', style: TextStyle(fontSize: 13, color: _muted)),
        Icon(Icons.chevron_right_rounded, size: 18, color: _muted),
        Text('Pre-Order', style: TextStyle(fontSize: 13, color: _muted)),
        Icon(Icons.chevron_right_rounded, size: 18, color: _muted),
        Expanded(
          child: Text(
            productName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _dark,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Two-column Main Content ───
  Widget _buildMainContent({required bool isCompact}) {
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageSection(),
          const SizedBox(height: 24),
          _buildDetailsSection(isCompact: true),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: _buildImageSection()),
        const SizedBox(width: 40),
        Expanded(flex: 4, child: _buildDetailsSection(isCompact: false)),
      ],
    );
  }

  Widget _buildImageSection() {
    final imageUrl = _activeProduct?.imageUrl.trim() ?? '';
    return Column(
      children: [
        // Main image
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              children: [
                if (imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (ctx, url) =>
                        Container(color: Colors.grey[100]),
                    errorWidget: (ctx, url, err) => _buildImageFallback(),
                  )
                else
                  _buildImageFallback(),
                // Pre-order badge
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'PRE-ORDER ACTIVE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF064E3B),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Thumbnail row
        if (imageUrl.isNotEmpty) ...[
          Row(
            children: List.generate(3, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (ctx, url) =>
                            Container(color: Colors.grey[100]),
                        errorWidget: (ctx, url, err) =>
                            Container(color: Colors.grey[100]),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: Colors.grey[100],
      width: double.infinity,
      child: const Center(
        child: Icon(Icons.image_rounded, size: 48, color: Color(0xFF9CA3AF)),
      ),
    );
  }

  Widget _buildDetailsSection({required bool isCompact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Farm tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 14, color: _primary),
              const SizedBox(width: 6),
              Text(
                _activeProduct?.farm ?? 'Farm',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Title
        Text(
          _activeProduct?.name ?? 'Pre-order Product',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: _dark,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        // Price
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _activeProduct?.price ?? '₱0',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _activeProduct?.unit.isNotEmpty == true
                    ? 'per ${_activeProduct!.unit}'
                    : 'per unit',
                style: TextStyle(fontSize: 15, color: _muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Info cards
        isCompact
            ? Column(
                children: [
                  _buildInfoChip(
                    Icons.calendar_today_rounded,
                    'Harvest',
                    _activeProduct?.harvestDays != null
                        ? 'In ${_activeProduct!.harvestDays} days'
                        : 'TBD',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoChip(
                    Icons.inventory_2_rounded,
                    'Stock Left',
                    _activeProduct?.targetQuantity != null
                        ? _activeProduct!.targetQuantity!.toStringAsFixed(0)
                        : 'TBD',
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      Icons.calendar_today_rounded,
                      'Harvest',
                      _activeProduct?.harvestDays != null
                          ? 'In ${_activeProduct!.harvestDays} days'
                          : 'TBD',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoChip(
                      Icons.inventory_2_rounded,
                      'Stock Left',
                      _activeProduct?.targetQuantity != null
                          ? _activeProduct!.targetQuantity!.toStringAsFixed(0)
                          : 'TBD',
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 24),
        // Quantity selector
        _buildQuantitySelector(isCompact: isCompact),
        const SizedBox(height: 20),
        _buildPaymentMethodSelector(isCompact: isCompact),
        const SizedBox(height: 28),
        // Total & CTA
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Price',
                    style: TextStyle(fontSize: 14, color: _muted),
                  ),
                  Text(
                    _computeTotalLabel(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmittingOrder ? null : _submitOfflinePreOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isSubmittingOrder
                            ? 'Submitting Order...'
                            : 'Pre-order Now',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!_isSubmittingOrder) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: Icon(
                    Icons.notifications_active_rounded,
                    size: 18,
                    color: _primary,
                  ),
                  label: Text(
                    'Notify me on harvest',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submitOfflinePreOrder() async {
    setState(() => _isSubmittingOrder = true);

    try {
      final active = _activeProduct;
      final productId = active?.productId;
      if (active == null || productId == null || productId.isEmpty) {
        throw Exception('No pre-order product selected.');
      }

      final quantity = _quantity.toDouble();
      final orderService = OrderService();

      final result = await orderService.createOfflinePreOrderByProductId(
        productId: productId,
        quantity: quantity,
        paymentMethod: _selectedPaymentMethod,
        notes: _selectedPaymentMethod == 'COD'
            ? 'Customer selected Cash on Delivery for this pre-order.'
            : 'Customer selected Cash on Pickup for this pre-order.',
      );

      if (!mounted) return;
      final orderId = (result['order'] as Map<String, dynamic>)['orderId'];
      final farmerUserId = result['farmer_user_id']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pre-order placed successfully. Order $orderId will be paid via $_selectedPaymentMethod.',
          ),
          backgroundColor: const Color(0xFF15803D),
        ),
      );

      if (farmerUserId != null && farmerUserId.isNotEmpty) {
        context.push(
          AppRoutes.messages,
          extra: {'farmerUserId': farmerUserId, 'asFarmer': false},
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place pre-order: $e'),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingOrder = false);
      }
    }
  }

  String _computeTotalLabel() {
    final rawPrice = (_activeProduct?.price ?? '₱0').replaceAll(
      RegExp(r'[^0-9.]'),
      '',
    );
    final unitPrice = double.tryParse(rawPrice) ?? 0;
    return '₱${(_quantity * unitPrice).toStringAsFixed(2)}';
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector({required bool isCompact}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.scale_rounded, size: 20, color: _dark),
                    SizedBox(width: 12),
                    Text(
                      'Quantity',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          _buildQtyButton(Icons.remove_rounded, () {
                            if (_quantity > 1) setState(() => _quantity--);
                          }),
                          Container(
                            width: 50,
                            alignment: Alignment.center,
                            child: Text(
                              '$_quantity',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _dark,
                              ),
                            ),
                          ),
                          _buildQtyButton(Icons.add_rounded, () {
                            if (_quantity < 50) setState(() => _quantity++);
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'kg',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Min order: 1 kg',
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.scale_rounded, size: 20, color: _dark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quantity',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                      Text(
                        'Min order: 1 kg',
                        style: TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      _buildQtyButton(Icons.remove_rounded, () {
                        if (_quantity > 1) setState(() => _quantity--);
                      }),
                      Container(
                        width: 50,
                        alignment: Alignment.center,
                        child: Text(
                          '$_quantity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                      ),
                      _buildQtyButton(Icons.add_rounded, () {
                        if (_quantity < 50) setState(() => _quantity++);
                      }),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'kg',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: _dark),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector({required bool isCompact}) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.local_atm_rounded,
                        color: _primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Choose Cash on Delivery or Cash on Pickup only',
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPaymentMethod,
                  items: _paymentOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedPaymentMethod = value);
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_atm_rounded,
                    color: _primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                      Text(
                        'Choose Cash on Delivery or Cash on Pickup only',
                        style: TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedPaymentMethod,
                    items: _paymentOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedPaymentMethod = value);
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ─── Farm Section ───
  Widget _buildFarmSection() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Farm story
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.yard_rounded, color: _primary, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Farm Story',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _primary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: AppData.farmStoryAvatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) =>
                              Container(color: Colors.grey[100]),
                          errorWidget: (ctx, url, err) =>
                              const Icon(Icons.person),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Farmer John Doe',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                        Text(
                          '"Grown with love since 1994"',
                          style: TextStyle(
                            fontSize: 13,
                            color: _muted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Our carrots are grown without pesticides in the rich mineral soils of the highland valley. We use traditional crop rotation techniques ensuring the best organic quality for your family.',
                  style: TextStyle(fontSize: 14, color: _muted, height: 1.7),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          // Farm map
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: _primary, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Farm Location',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 10,
                        child: CachedNetworkImage(
                          imageUrl: AppData.farmMapImageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (ctx, url) =>
                              Container(color: Colors.grey[100], height: 180),
                          errorWidget: (ctx, url, err) =>
                              Container(color: Colors.grey[100], height: 180),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.15),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    color: _primary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Highland Valley Farm',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _dark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Related Products ───
  Widget _buildRelatedProducts() {
    return FutureBuilder<List<ProductItem>>(
      future: SupabaseDataService().getPreOrderProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppShimmerLoader());
        }

        final allProducts = snapshot.data ?? [];
        final products = allProducts.take(4).toList();

        if (products.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You might also like',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              itemBuilder: (context, i) {
                final p = products[i];
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: p.imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (ctx, url) =>
                                  Container(color: Colors.grey[100]),
                              errorWidget: (ctx, url, err) =>
                                  Container(color: Colors.grey[100]),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _dark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${p.price}${p.unit}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

