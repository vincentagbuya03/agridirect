import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/data/app_data.dart';
import '../../../shared/models/product/product_review_model.dart';
import '../../../shared/models/product/crop_milestone_model.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/services/commerce/product_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../widgets/crop_milestones_timeline.dart';

class WebPreorderDetails extends StatefulWidget {
  const WebPreorderDetails({super.key, this.initialProduct});

  final ProductItem? initialProduct;

  @override
  State<WebPreorderDetails> createState() => _WebPreorderDetailsState();
}

class _WebPreorderDetailsState extends State<WebPreorderDetails> {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _white = Colors.white;

  final ProductService _productService = ProductService();

  ProductItem? _product;
  Map<String, dynamic>? _farmerProfile;
  List<ProductReview> _reviews = const [];
  List<ProductItem> _moreFromFarmer = const [];
  List<CropMilestone> _milestones = const [];
  bool _isLoading = true;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    super.dispose();
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
      final milestonesFuture =
          product.productId != null && product.productId!.isNotEmpty
          ? _productService.getCropMilestones(product.productId!)
          : Future.value(<CropMilestone>[]);

      final results = await Future.wait<dynamic>([
        farmerFuture,
        reviewsFuture,
        relatedFuture,
        milestonesFuture,
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
        _milestones = results[3] as List<CropMilestone>;
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
    if (raw.trim().startsWith('₱')) {
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

  double _averageReviewRating() {
    if (_reviews.isEmpty) return double.tryParse(_product?.rating ?? '0') ?? 0;
    return _reviews.fold<double>(0, (sum, review) => sum + review.rating) /
        _reviews.length;
  }

  Future<void> _addToCart() async {
    if (_product == null) return;
    await CartService().addItem(_product!);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${_product!.name} added to cart')));
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
                  CropMilestonesTimeline(milestones: _milestones),
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
              onPressed: () => context.go('${AppRoutes.shop}?mode=preorders'),
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
      child: Column(
        children: [
          ClipRRect(
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
        ],
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

    final totalDays = int.tryParse(_product?.harvestDays ?? '') ?? 0;
    final remainingDays = _product?.createdAt == null
        ? totalDays
        : _product!.createdAt!
                  .add(Duration(days: totalDays))
                  .difference(DateTime.now())
                  .inDays +
              1;
    final isHarvested = remainingDays <= 0;

    String availabilityValue;
    if (isHarvested) {
      final diff = remainingDays.abs();
      availabilityValue = diff == 0
          ? 'Harvested today'
          : 'Harvested $diff days ago';
    } else {
      availabilityValue = 'Harvest in $remainingDays days';
    }

    final target = _product!.targetQuantity ?? 100.0;
    final reserved = _product!.reservedQuantity ?? 0.0;
    final percent = (reserved / (target > 0 ? target : 1)).clamp(0.0, 1.0);
    final displayUnit = _product!.unit.split('/').last.trim();

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isHarvested
                      ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                      : const Color(0xFFEA580C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isHarvested
                      ? 'READY FOR ORDER (HARVESTED)'
                      : 'UPCOMING HARVEST (PRE-ORDER)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isHarvested
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFEA580C),
                  ),
                ),
              ),
            ],
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
              _metaRow(
                Icons.storefront_rounded,
                _farmName(),
                _primary,
                onTap:
                    _farmerProfile?['farmer_id']?.toString().isNotEmpty == true
                    ? () => context.go(
                        AppRoutes.farmerProfile(
                          _farmerProfile!['farmer_id'].toString(),
                        ),
                      )
                    : null,
              ),
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
                  availabilityValue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoTile(
                  Icons.inventory_2_rounded,
                  'Stock Goal',
                  _product!.targetQuantity != null
                      ? '${_product!.targetQuantity!.toStringAsFixed(0)} $displayUnit'
                      : 'Available',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (!isHarvested) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            size: 16,
                            color: Color(0xFF1D4ED8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Pre-Order Reservation Status',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${(percent * 100).toStringAsFixed(0)}% Reserved',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      backgroundColor: const Color(0xFFDBEAFE),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF1D4ED8),
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reserved: ${reserved.toStringAsFixed(0)} $displayUnit',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E3A8A),
                        ),
                      ),
                      Text(
                        'Goal: ${target.toStringAsFixed(0)} $displayUnit',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: Color(0xFF15803D),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Harvest Complete',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF166534),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'This batch has been harvested! You can still order it now as standard fresh stock.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF166534),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
          _buildQuantityRow(),
          const SizedBox(height: 32),
          if (_product?.farmerId != null &&
              _product?.farmerId == SupabaseConfig.currentUser?.id)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'This is your product.',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addToCart,
                    icon: Icon(
                      isHarvested
                          ? Icons.shopping_cart_outlined
                          : Icons.calendar_today_rounded,
                    ),
                    label: Text(
                      isHarvested ? 'Add to Cart' : 'Add Pre-order to Cart',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: BorderSide(color: _primary.withValues(alpha: 0.28)),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      context.push(
                        AppRoutes.checkout,
                        extra: {
                          'product': _product,
                          'quantity': _quantity,
                          'isPreOrder': !isHarvested,
                        },
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: _white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      isHarvested ? 'Order Now' : 'Reserve Pre-order',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _metaRow(
    IconData icon,
    String value,
    Color color, {
    VoidCallback? onTap,
  }) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _dark,
          ),
        ),
      ],
    );

    if (onTap == null) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: child),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityRow() {
    return Row(
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              _qtyButton(Icons.remove_rounded, () {
                if (_quantity > 1) setState(() => _quantity--);
              }),
              Container(
                width: 54,
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
              _qtyButton(Icons.add_rounded, () {
                if (_quantity < 99) setState(() => _quantity++);
              }),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(_unitLabel(), style: const TextStyle(fontSize: 13, color: _muted)),
      ],
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: _dark),
    );
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            child: const Text(
              'View Farm',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    if (_reviews.isEmpty) return const SizedBox.shrink();

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
          Row(
            children: [
              const Text(
                'Ratings & Reviews',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const Spacer(),
              Text(
                _averageReviewRating().toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ..._reviews.take(4).map(_buildReviewCard),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName?.trim().isNotEmpty == true
                            ? review.userName!
                            : 'Customer',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                      Text(
                        '${review.createdAt.month}/${review.createdAt.day}/${review.createdAt.year}',
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < review.rating.round()
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 15,
                      color: const Color(0xFFF59E0B),
                    );
                  }),
                ),
              ],
            ),
            if (review.reviewText?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                review.reviewText!,
                style: const TextStyle(fontSize: 14, color: _dark, height: 1.7),
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
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.rating ?? '0.0',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _dark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${item.price} ${item.unit}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
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
