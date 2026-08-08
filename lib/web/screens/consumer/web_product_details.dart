import 'package:flutter/material.dart';

import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/data/app_data.dart';
import '../../../shared/models/product/product_review_model.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/services/commerce/product_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/widgets/image_widgets.dart';
import '../../../shared/services/commerce/voucher_service.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/utils/share_util.dart';
import '../../../shared/widgets/app_open_banner.dart';
import 'package:google_fonts/google_fonts.dart';

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

  ProductItem? _product;
  Map<String, dynamic>? _farmerProfile;
  List<ProductReview> _reviews = const [];
  List<ProductItem> _moreFromFarmer = const [];
  bool _isLoading = true;
  bool _canReviewProduct = false;
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
      final canReviewFuture =
          product.productId != null && product.productId!.isNotEmpty
          ? _productService
                .getCompletedOrderIdForReview(product.productId!)
                .then((orderId) => orderId != null)
          : Future.value(false);
      final relatedFuture =
          product.farmerId != null && product.farmerId!.isNotEmpty
          ? SupabaseDataService().getProductsByFarmerId(product.farmerId!)
          : Future.value(<ProductItem>[]);

      final results = await Future.wait<dynamic>([
        farmerFuture,
        reviewsFuture,
        canReviewFuture,
        relatedFuture,
      ]);

      if (!mounted) return;
      setState(() {
        _product = product;
        _farmerProfile = results[0] as Map<String, dynamic>?;
        _reviews = results[1] as List<ProductReview>;
        _canReviewProduct = results[2] as bool;
        _moreFromFarmer = (results[3] as List<ProductItem>)
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
      targetQuantity: (raw['target_quantity'] as num?)?.toDouble(),
      stockQuantity: (raw['stock_quantity'] as num?)?.toDouble(),
    );
  }

  String _currencyLabel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('₱')) return trimmed;
    if (trimmed.startsWith('P')) {
      return '₱${trimmed.substring(1)}';
    }
    return '₱$trimmed';
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
    final errorMsg = await CartService().addItem(_product!, _quantity);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errorMsg ?? '${_product!.name} added to cart')));
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
      backgroundColor: Colors.white,
      body: AppOpenBanner(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 16 : 32,
                  16,
                  isCompact ? 16 : 32,
                  64,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBreadcrumbs(),
                        const SizedBox(height: 32),
                        isCompact
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildImageGallery(),
                                  const SizedBox(height: 32),
                                  _buildDetailsCard(),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 4, child: _buildImageGallery()),
                                  const SizedBox(width: 48),
                                  Expanded(flex: 5, child: _buildDetailsCard()),
                                ],
                              ),
                        const SizedBox(height: 64),
                        _buildSellerSection(),
                        const SizedBox(height: 48),
                        _buildReviewsSection(),
                        const SizedBox(height: 64),
                        _buildMoreFromFarmerSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _border.withValues(alpha: 0.5))),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.shop),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _dark, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Product Details',
              style: GoogleFonts.nunitoSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.cart),
              icon: const Icon(Icons.shopping_cart_outlined, color: _primary),
              label: Text(
                'Cart',
                style: GoogleFonts.nunitoSans(color: _primary, fontWeight: FontWeight.w800),
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

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(32),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: productImage.isNotEmpty
              ? SafeNetworkImage(
                  imageUrl: productImage,
                  fit: BoxFit.cover,
                  placeholder: Container(color: _surface),
                  errorWidget: _buildImageFallback(),
                )
              : _buildImageFallback(),
        ),
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: _surface,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 64, color: _muted),
      ),
    );
  }

  Widget _buildDetailsCard() {
    final averageRating = _averageReviewRating();
    final reviewCount = _reviews.isNotEmpty
        ? _reviews.length
        : int.tryParse(_product!.reviews ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            (_product!.categoryName ?? 'Product').toUpperCase(),
            style: GoogleFonts.nunitoSans(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: _primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _product!.name,
          style: GoogleFonts.nunitoSans(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: _dark,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 12,
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
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _currencyLabel(_product!.price),
              style: GoogleFonts.nunitoSans(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: _primary,
                letterSpacing: -0.5,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _product!.unit.isNotEmpty ? 'per ${_product!.unit}' : 'per unit',
                style: GoogleFonts.nunitoSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          _product!.description?.trim().isNotEmpty == true
              ? _product!.description!
              : 'Fresh produce from local farmers. High quality and organically grown.',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: _dark.withValues(alpha: 0.8),
            height: 1.7,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(
              child: _infoTile(
                Icons.schedule_rounded,
                'Availability',
                _product!.targetQuantity != null ? 'Pre-order' : 'Available now',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _infoTile(
                Icons.inventory_2_rounded,
                'Stock Level',
                _product!.targetQuantity != null
                    ? '${_product!.targetQuantity!.toStringAsFixed(0)} target'
                    : (_product!.stockQuantity != null && _product!.stockQuantity! > 0
                        ? '${_product!.stockQuantity!.toStringAsFixed(0)} items'
                        : 'Out of stock'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildProductVouchersSection(),
        const SizedBox(height: 32),
        Row(
          children: [
            Text(
              'Quantity',
              style: GoogleFonts.nunitoSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    _qtyButton(Icons.remove_rounded, () {
                      if (_quantity > 1) setState(() => _quantity--);
                    }),
                    Container(
                      constraints: const BoxConstraints(minWidth: 48),
                      alignment: Alignment.center,
                      child: Text(
                        '$_quantity',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: _dark,
                        ),
                      ),
                    ),
                    _qtyButton(Icons.add_rounded, () {
                      final isPreorder = _product!.targetQuantity != null;
                      final maxQty = isPreorder ? 999 : (_product!.stockQuantity?.toInt() ?? 0);
                      if (isPreorder || _quantity < maxQty) {
                        setState(() => _quantity++);
                      }
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _unitLabel(),
                style: GoogleFonts.nunitoSans(fontSize: 15, fontWeight: FontWeight.w700, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 48),
          if (_product?.farmerId != null && _product?.farmerId == SupabaseConfig.currentUser?.id)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_rounded, color: Colors.amber),
                        const SizedBox(width: 12),
                        Text(
                          'This is your product.',
                          style: GoogleFonts.nunitoSans(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            _buildActionsRow(),
        ],
      );
  }

  bool _isHarvested(ProductItem? product) {
    if (product == null) return false;
    final days = int.tryParse(product.harvestDays ?? '');
    if (days == null) return false;
    if (days <= 0) return true;
    if (product.createdAt != null) {
      final harvestDate = product.createdAt!.add(Duration(days: days));
      final now = DateTime.now();
      return harvestDate.difference(now).isNegative;
    }
    return false;
  }

  Widget _buildActionButtonsSection() {
    final isPreOrder = _product?.targetQuantity != null;
    final harvested = _isHarvested(_product);

    if (isPreOrder && !harvested) {
      return Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: () {
                final farmerId = _farmerProfile!['farmer_id']?.toString();
                if (farmerId == null || farmerId.isEmpty) return;
                context.go(AppRoutes.farmerProfile(farmerId));
              },
              style: FilledButton.styleFrom(
                backgroundColor: _dark,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                'Pre-Order Now',
                style: GoogleFonts.nunitoSans(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
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
            label: Text(
              'Add to Cart',
              style: GoogleFonts.nunitoSans(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: FilledButton(
            onPressed: () {
              context.push(
                AppRoutes.checkout,
                extra: {'product': _product, 'quantity': _quantity},
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: _white,
              padding: const EdgeInsets.symmetric(vertical: 22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
              child: Text(
                'Buy Now',
                style: GoogleFonts.nunitoSans(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        Expanded(child: _buildActionButtonsSection()),
        const SizedBox(width: 12),
        MenuAnchor(
          style: MenuStyle(
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          builder: (context, controller, child) {
            return IconButton.outlined(
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: const Icon(Icons.ios_share_rounded, color: _primary),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(22),
                backgroundColor: _surface,
                shape: const CircleBorder(),
              ),
              tooltip: 'Share Product',
            );
          },
          menuChildren: [
            MenuItemButton(
              leadingIcon: const Icon(Icons.share_rounded, size: 20, color: _primary),
              onPressed: () async {
                if (_product?.productId == null) return;
                final shareUrl = ShareUtil.generateProductShareLink(_product!.productId!);
                // ignore: deprecated_member_use
                await Share.share(shareUrl, subject: 'Check out ${_product!.name} on AgriDirect!');
              },
              child: Text('Share Link', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.qr_code_2_rounded, size: 20, color: _primary),
              onPressed: () {
                if (_product?.productId == null) return;
                final shareUrl = ShareUtil.generateProductShareLink(_product!.productId!);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'Product QR Code',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Scan to view this product',
                          style: GoogleFonts.inter(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: QrImageView(
                            data: shareUrl,
                            version: QrVersions.auto,
                            size: 200.0,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF0F172A),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Close',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
              child: Text('Show QR Code', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ],
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
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
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.nunitoSans(
              fontSize: 20,
              fontWeight: FontWeight.w900,
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
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(32),
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
                  style: GoogleFonts.nunitoSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _specialty(),
                  style: GoogleFonts.inter(fontSize: 15, color: _muted),
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

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reviews & Ratings',
                style: GoogleFonts.nunitoSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _dark,
                ),
              ),
              if (_canReviewProduct)
                FilledButton.icon(
                  onPressed: _showAddReviewDialog,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary.withValues(alpha: 0.1),
                    foregroundColor: _primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: Text(
                    'Write a Review',
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (!_canReviewProduct)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 18, color: _muted),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Only consumers with a completed order for this product can write a review.',
                      style: TextStyle(fontSize: 13, color: _muted),
                    ),
                  ),
                ],
              ),
            ),
          if (reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No reviews yet. Check back later to see what other consumers say about this product.',
                style: TextStyle(fontSize: 14, color: _muted),
              ),
            )
          else
            ...reviews.map(_buildReviewCard),
        ],
      ),
    );
  }

  void _showAddReviewDialog() {
    final productId = _product?.productId;
    if (productId == null || productId.isEmpty) return;

    double selectedRating = 5.0;
    bool isSubmittingReview = false;
    final reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Write a Review',
                style: TextStyle(fontWeight: FontWeight.w800, color: _dark),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rating',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        return IconButton(
                          onPressed: () {
                            setDialogState(() {
                              selectedRating = index + 1.0;
                            });
                          },
                          icon: Icon(
                            index < selectedRating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: const Color(0xFFF59E0B),
                            size: 32,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Review',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reviewController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Share your experience with this product...',
                        filled: true,
                        fillColor: _surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: isSubmittingReview
                      ? null
                      : () async {
                          setDialogState(() => isSubmittingReview = true);
                          try {
                            await _productService.createReview(
                              productId: productId,
                              rating: selectedRating,
                              reviewText: reviewController.text,
                            );
                            if (!mounted || !ctx.mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Review submitted!'),
                              ),
                            );
                            await _loadPage(_product);
                          } catch (e) {
                            if (!mounted) return;
                            setDialogState(() => isSubmittingReview = false);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isSubmittingReview ? 'Submitting...' : 'Submit Review',
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(reviewController.dispose);
  }

  Widget _buildReviewCard(ProductReview review) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(24),
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
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                ),
                Text(
                  review.rating.toStringAsFixed(1),
                  style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            if (review.reviewText?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                review.reviewText!,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: _dark.withValues(alpha: 0.8),
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMoreFromFarmerSection() {
    if (_moreFromFarmer.isEmpty) return const SizedBox.shrink();

    final sw = MediaQuery.of(context).size.width;
    final crossCount = sw < 600 ? 2 : (sw < 900 ? 3 : 4);
    final aspect = sw < 600 ? 0.76 : 0.82;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More From This Farm',
          style: GoogleFonts.nunitoSans(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: _dark,
          ),
        ),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: aspect,
          ),
          itemCount: _moreFromFarmer.length.clamp(0, crossCount),
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
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _dark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _currencyLabel(item.price),
                              style: GoogleFonts.nunitoSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
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

  Widget _buildProductVouchersSection() {
    final farmerId = _product?.farmerId;
    final currentUserId = AuthService().userId;
    if (farmerId == null || farmerId.isEmpty || currentUserId.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: VoucherService().getFarmerVouchersForUser(
        farmerId: farmerId,
        userId: currentUserId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final vouchers = snapshot.data!;
        if (vouchers.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.confirmation_number_outlined, color: _primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Vouchers available for this shop:',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _dark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: vouchers.length,
                itemBuilder: (context, idx) {
                  final v = vouchers[idx];
                  final code = v['code'] ?? '';
                  final val = (v['discount_value'] as num).toDouble();
                  final type = v['discount_type'] ?? '';
                  final isClaimed = v['is_claimed'] as bool? ?? false;

                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 170,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _primary.withValues(alpha: 0.2)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                type == 'flat' ? '₱${val.toStringAsFixed(0)} OFF' : '${val.toStringAsFixed(0)}% OFF',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: _primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                code,
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: _muted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        isClaimed
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Claimed',
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: _muted,
                                  ),
                                ),
                              )
                            : GestureDetector(
                                onTap: () async {
                                  final ok = await VoucherService().claimVoucher(currentUserId, v['voucher_id']);
                                  if (ok) {
                                    setState(() {});
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Claim',
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
