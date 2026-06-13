import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/data/app_data.dart';
import '../../../shared/models/auth/user_address_model.dart';
import '../../../shared/models/product/product_review_model.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/services/commerce/product_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/user/user_service.dart';
import '../../../shared/widgets/image_widgets.dart';

class WebProductDetails extends StatefulWidget {
  const WebProductDetails({super.key, this.initialProduct});

  final ProductItem? initialProduct;

  @override
  State<WebProductDetails> createState() => _WebProductDetailsState();
}

class _WebProductDetailsState extends State<WebProductDetails> {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _white = Colors.white;

  final ProductService _productService = ProductService();
  final OrderService _orderService = OrderService();
  final UserService _userService = UserService();
  final TextEditingController _instructionsController = TextEditingController();

  ProductItem? _product;
  Map<String, dynamic>? _farmerProfile;
  List<ProductReview> _reviews = const [];
  List<ProductItem> _moreFromFarmer = const [];
  List<UserAddress> _addresses = const [];
  UserAddress? _selectedAddress;
  bool _isLoading = true;
  bool _isLoadingAddresses = true;
  bool _isSubmittingOrder = false;
  int _quantity = 1;
  String _selectedPaymentMethod = 'COD';

  static const List<String> _paymentOptions = ['COD', 'COP'];

  @override
  void initState() {
    super.initState();
    _loadPage();
    _loadAddresses();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    try {
      final addresses = await _userService.getAllUserAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _selectedAddress = addresses.cast<UserAddress?>().firstWhere(
          (address) => address?.isDefault == true,
          orElse: () => addresses.isNotEmpty ? addresses.first : null,
        );
        _isLoadingAddresses = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingAddresses = false);
    }
  }

  Future<void> _openAddressBook() async {
    await context.push(AppRoutes.addressBook);
    if (!mounted) return;
    await _loadAddresses();
  }

  Future<void> _loadPage([ProductItem? target]) async {
    setState(() => _isLoading = true);
    try {
      ProductItem? product = target ?? widget.initialProduct;
      if (product?.productId != null && product!.productId!.isNotEmpty) {
        product =
            await SupabaseDataService().getProductById(product.productId!) ??
            product;
      } else {
        final products = await SupabaseDatabase.getProducts(limit: 1);
        if (products.isNotEmpty) {
          product = _productFromMap(products.first);
        }
      }

      if (product == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final farmerFuture =
          product.farmerId != null && product.farmerId!.isNotEmpty
          ? SupabaseDataService().getFarmerProfileByFarmerId(product.farmerId!)
          : Future.value(null);
      final reviewsFuture =
          product.productId != null && product.productId!.isNotEmpty
          ? _productService.getProductReviews(product.productId!, limit: 8)
          : Future.value(<ProductReview>[]);
      final relatedFuture =
          product.farmerId != null && product.farmerId!.isNotEmpty
          ? SupabaseDataService().getProductsByFarmerId(product.farmerId!)
          : Future.value(<ProductItem>[]);

      final results = await Future.wait<dynamic>([
        farmerFuture,
        reviewsFuture,
        relatedFuture,
      ]);

      if (!mounted) return;
      setState(() {
        _product = product;
        _farmerProfile = results[0] as Map<String, dynamic>?;
        _reviews = results[1] as List<ProductReview>;
        _moreFromFarmer = (results[2] as List<ProductItem>)
            .where((item) => item.productId != product!.productId)
            .take(6)
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  ProductItem _productFromMap(Map<String, dynamic> raw) {
    final farmer = raw['farmer'] as Map<String, dynamic>?;
    return ProductItem(
      productId: raw['product_id']?.toString(),
      farmerId:
          raw['farmer_id']?.toString() ?? farmer?['farmer_id']?.toString(),
      farmerName: farmer?['user']?['name']?.toString(),
      farmerAvatarUrl: farmer?['user']?['avatar_url']?.toString(),
      name: raw['name']?.toString() ?? 'Product',
      farm: farmer?['farm_name']?.toString() ?? 'Farm',
      price: 'P${raw['price']?.toString() ?? '0'}',
      unit: raw['unit_name']?.toString() ?? 'unit',
      imageUrl: raw['image_url']?.toString() ?? '',
      categoryName: raw['category_name']?.toString(),
      rating: raw['average_rating']?.toString(),
      reviews: raw['review_count']?.toString(),
      description: raw['description']?.toString(),
      harvestDays: raw['harvest_days']?.toString(),
      targetQuantity: (raw['stock_quantity'] as num?)?.toDouble(),
    );
  }

  String _currencyLabel(String raw) {
    if (raw.trim().startsWith('P')) return raw;
    if (raw.trim().startsWith('â‚±')) {
      return 'P${raw.trim().substring(1)}';
    }
    return 'P$raw';
  }

  String _farmName() {
    if (_farmerProfile?['farm_name']?.toString().trim().isNotEmpty == true) {
      return _farmerProfile!['farm_name'].toString();
    }
    return _product?.farm ?? 'Farm';
  }

  String _specialty() {
    if (_farmerProfile?['specialty']?.toString().trim().isNotEmpty == true) {
      return _farmerProfile!['specialty'].toString();
    }
    return 'Fresh produce';
  }

  String _unitLabel() {
    final unit = _product?.unit.trim();
    return unit == null || unit.isEmpty ? 'unit' : unit;
  }

  double _priceValue() {
    final raw = _product?.price ?? '0';
    return double.tryParse(raw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }

  double _averageReviewRating() {
    if (_reviews.isEmpty) return double.tryParse(_product?.rating ?? '0') ?? 0;
    return _reviews.fold<double>(0, (sum, review) => sum + review.rating) /
        _reviews.length;
  }

  Future<void> _addToCart() async {
    if (_product == null) return;
    await CartService().addItem(_product!, _quantity);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${_product!.name} added to cart')));
  }

  Future<void> _submitOrder() async {
    final product = _product;
    final productId = product?.productId;
    final farmerId = product?.farmerId;
    if (productId == null ||
        productId.isEmpty ||
        farmerId == null ||
        farmerId.isEmpty) {
      return;
    }

    if (_selectedPaymentMethod == 'COD' && _selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address.')),
      );
      return;
    }

    setState(() => _isSubmittingOrder = true);
    try {
      await _orderService.createOfflineOrder(
        farmerId: farmerId,
        items: [
          OrderItemInput(
            productId: productId,
            quantity: _quantity.toDouble(),
            unitPrice: _priceValue(),
          ),
        ],
        paymentMethod: _selectedPaymentMethod,
        deliveryAddressId:
            _selectedPaymentMethod == 'COP' ? null : _selectedAddress?.addressId,
        notes: _instructionsController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully.')),
      );
      context.go(AppRoutes.customerOrders);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSubmittingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    if (_product == null) {
      return const Scaffold(body: Center(child: Text('Product not found')));
    }

    final isCompact = MediaQuery.of(context).size.width < 980;

    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 32,
                20,
                isCompact ? 16 : 32,
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBreadcrumbs(),
                  const SizedBox(height: 20),
                  isCompact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildImageGallery(),
                            const SizedBox(height: 20),
                            _buildDetailsCard(),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: _buildImageGallery()),
                            const SizedBox(width: 24),
                            Expanded(flex: 4, child: _buildDetailsCard()),
                          ],
                        ),
                  const SizedBox(height: 28),
                  _buildSellerSection(),
                  const SizedBox(height: 28),
                  _buildReviewsSection(),
                  const SizedBox(height: 28),
                  _buildMoreFromFarmerSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: _white,
          border: Border(bottom: BorderSide(color: _border)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => context.go(AppRoutes.shop),
              icon: const Icon(Icons.arrow_back_rounded, color: _dark),
            ),
            const SizedBox(width: 8),
            const Text(
              'Product Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.cart),
              icon: const Icon(Icons.shopping_cart_outlined, color: _primary),
              label: const Text(
                'Cart',
                style: TextStyle(color: _primary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    return Row(
      children: [
        _breadcrumb('Marketplace', () => context.go(AppRoutes.marketplace)),
        _crumbArrow(),
        _breadcrumb('Shop', () => context.go(AppRoutes.shop)),
        _crumbArrow(),
        Expanded(
          child: Text(
            _product!.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _breadcrumb(String label, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: _primary),
        ),
      ),
    );
  }

  Widget _crumbArrow() =>
      const Icon(Icons.chevron_right_rounded, size: 18, color: _muted);

  Widget _buildImageGallery() {
    final productImage = (_product?.imageUrl ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 1.1,
          child: productImage.isNotEmpty
              ? SafeNetworkImage(
                  imageUrl: productImage,
                  fit: BoxFit.cover,
                  placeholder: Container(color: Colors.grey[100]),
                  errorWidget: _buildImageFallback(),
                )
              : _buildImageFallback(),
        ),
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: Colors.grey[100],
      child: const Center(
        child: Icon(Icons.image_outlined, size: 42, color: _muted),
      ),
    );
  }

  Widget _buildDetailsCard() {
    final averageRating = _averageReviewRating();
    final reviewCount = _reviews.isNotEmpty
        ? _reviews.length
        : int.tryParse(_product!.reviews ?? '0') ?? 0;
    final requiresAddress = _selectedPaymentMethod == 'COD';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _product!.categoryName ?? 'Product',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _product!.name,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: _dark,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _metaRow(Icons.storefront_rounded, _farmName(), _primary),
              _metaRow(
                Icons.star_rounded,
                averageRating.toStringAsFixed(1),
                const Color(0xFFF59E0B),
              ),
              _metaRow(Icons.reviews_rounded, '$reviewCount reviews', _dark),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _currencyLabel(_product!.price),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: _primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _product!.unit.isNotEmpty ? 'per ${_product!.unit}' : 'per unit',
            style: const TextStyle(fontSize: 14, color: _muted),
          ),
          const SizedBox(height: 18),
          Text(
            _product!.description?.trim().isNotEmpty == true
                ? _product!.description!
                : 'Fresh produce from local farmers.',
            style: const TextStyle(fontSize: 14, color: _dark, height: 1.7),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  Icons.schedule_rounded,
                  'Availability',
                  'Available now',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoTile(
                  Icons.inventory_2_rounded,
                  'Stock',
                  _product!.targetQuantity != null
                      ? _product!.targetQuantity!.toStringAsFixed(0)
                      : 'Available',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Text(
                'Quantity',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    _qtyButton(Icons.remove_rounded, () {
                      if (_quantity > 1) setState(() => _quantity--);
                    }),
                    Container(
                      constraints: const BoxConstraints(minWidth: 44),
                      alignment: Alignment.center,
                      child: Text(
                        '$_quantity',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                    ),
                    _qtyButton(Icons.add_rounded, () {
                      if (_quantity < 99) setState(() => _quantity++);
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _unitLabel(),
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _selectedPaymentMethod,
            items: _paymentOptions
                .map(
                  (method) => DropdownMenuItem<String>(
                    value: method,
                    child: Text(method),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedPaymentMethod = value);
            },
            decoration: InputDecoration(
              labelText: 'Payment method',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            requiresAddress ? 'Shipping Address' : 'Pickup Location (at Farm)',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 8),
          if (_isLoadingAddresses)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(color: _primary),
              ),
            )
          else if (requiresAddress)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAddressPanel(),
                const SizedBox(height: 12),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pickup will be arranged directly with the farmer.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _farmName(),
                    style: const TextStyle(fontSize: 13, color: _muted),
                  ),
                ],
              ),
            ),
          TextField(
            controller: _instructionsController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Special instructions (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildOrderSummary(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addToCart,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: BorderSide(color: _primary.withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: const Text(
                    'Add to Cart',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton(
                  onPressed: _isSubmittingOrder ? null : _submitOrder,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: _white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    _isSubmittingOrder ? 'Ordering...' : 'Buy Now',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Total: ${_currencyLabel((_priceValue() * _quantity).toStringAsFixed(2))}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressPanel() {
    if (_addresses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'No saved address found. Add one first to use Cash on Delivery.',
                style: TextStyle(fontSize: 13, color: _muted),
              ),
            ),
            TextButton(
              onPressed: _openAddressBook,
              child: const Text('Manage'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedAddress?.addressId,
          items: _addresses
              .map(
                (address) => DropdownMenuItem<String>(
                  value: address.addressId,
                  child: Text(
                    '${address.label} • ${address.city}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedAddress = _addresses.cast<UserAddress?>().firstWhere(
                (address) => address?.addressId == value,
                orElse: () => null,
              );
            });
          },
          decoration: InputDecoration(
            labelText: 'Delivery address',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_selectedAddress != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Text(
              '${_selectedAddress!.recipientName}\n${_selectedAddress!.fullAddress}\n${_selectedAddress!.recipientPhone}',
              style: const TextStyle(fontSize: 13, color: _muted, height: 1.5),
            ),
          ),
      ],
    );
  }

  Widget _buildOrderSummary() {
    final subtotal = _priceValue() * _quantity;
    final requiresAddress = _selectedPaymentMethod == 'COD';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 14),
          _summaryRow('Unit price', _currencyLabel(_product!.price)),
          _summaryRow('Quantity', '$_quantity ${_unitLabel()}'),
          _summaryRow(
            'Fulfillment',
            requiresAddress ? 'Delivery' : 'Pickup at farm',
          ),
          _summaryRow(
            'Payment',
            _selectedPaymentMethod == 'COD'
                ? 'Cash on Delivery'
                : 'Cash on Pickup',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          _summaryRow(
            'Total',
            _currencyLabel(subtotal.toStringAsFixed(2)),
            isEmphasized: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isEmphasized = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isEmphasized ? _dark : _muted,
                fontWeight: isEmphasized ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isEmphasized ? 15 : 13,
              color: _dark,
              fontWeight: isEmphasized ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: _dark),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _dark,
          ),
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }

  Widget _buildSellerSection() {
    if (_farmerProfile == null) return const SizedBox.shrink();

    final avatarUrl =
        _farmerProfile!['avatar_url']?.toString() ??
        _farmerProfile!['image_url']?.toString() ??
        '';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          SafeCircleAvatar(
            imageUrl: avatarUrl,
            radius: 30,
            backgroundColor: _surface,
            child: const Icon(Icons.storefront_rounded, color: _primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _farmName(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _specialty(),
                  style: const TextStyle(fontSize: 14, color: _muted),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              final farmerId = _farmerProfile!['farmer_id']?.toString();
              if (farmerId == null || farmerId.isEmpty) return;
              context.go(AppRoutes.farmerProfile(farmerId));
            },
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('View Farm'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    final reviews = _reviews.take(4).toList();
    if (reviews.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Reviews',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 18),
          ...reviews.map(_buildReviewCard),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ProductReview review) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SafeCircleAvatar(
                  imageUrl: review.userAvatar,
                  radius: 18,
                  backgroundColor: _white,
                  child: const Icon(
                    Icons.person_rounded,
                    color: _muted,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    review.userName?.trim().isNotEmpty == true
                        ? review.userName!
                        : 'Customer',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),
                Text(
                  review.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ],
            ),
            if (review.reviewText?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                review.reviewText!,
                style: const TextStyle(fontSize: 13, color: _muted, height: 1.6),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMoreFromFarmerSection() {
    if (_moreFromFarmer.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'More From This Farm',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.82,
          ),
          itemCount: _moreFromFarmer.length.clamp(0, 4),
          itemBuilder: (context, index) {
            final item = _moreFromFarmer[index];
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _loadPage(item),
                child: Container(
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          child: SafeNetworkImage(
                            imageUrl: item.imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: Container(color: Colors.grey[100]),
                            errorWidget: Container(color: Colors.grey[100]),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _dark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _currencyLabel(item.price),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
