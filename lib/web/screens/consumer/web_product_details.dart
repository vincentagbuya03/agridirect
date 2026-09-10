import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/models/product/product_review_model.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/services/commerce/product_service.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../constants/web_design_tokens.dart';
import '../../widgets/web_footer.dart';
import '../../widgets/ecom/web_ecom_header.dart';
import '../../widgets/ecom/web_farm_storefront_card.dart';
import '../../widgets/ecom/web_product_card.dart';

/// Flagship E-Commerce Product Details Page for AgriDirect Web
class WebProductDetails extends StatefulWidget {
  final ProductItem? initialProduct;

  const WebProductDetails({super.key, this.initialProduct});

  @override
  State<WebProductDetails> createState() => _WebProductDetailsState();
}

class _WebProductDetailsState extends State<WebProductDetails>
    with SingleTickerProviderStateMixin {
  final ProductService _productService = ProductService();
  final SupabaseDataService _dataService = SupabaseDataService();

  ProductItem? _product;
  Map<String, dynamic>? _farmerProfile;
  List<ProductReview> _reviews = const [];
  List<ProductItem> _moreFromFarmer = const [];
  bool _isLoading = true;

  int _selectedImageIndex = 0;
  int _quantity = 1;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPage();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPage([ProductItem? target]) async {
    setState(() => _isLoading = true);
    try {
      ProductItem? product = target ?? widget.initialProduct;
      if (product?.productId != null && product!.productId!.isNotEmpty) {
        product =
            await _dataService.getProductById(product.productId!) ?? product;
      } else {
        final products = await _dataService.getNearbyProducts();
        if (products.isNotEmpty) {
          product = products.first;
        }
      }

      if (product == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final farmerFuture =
          product.farmerId != null && product.farmerId!.isNotEmpty
              ? _dataService.getFarmerProfileByFarmerId(product.farmerId!)
              : Future.value(null);

      final reviewsFuture =
          product.productId != null && product.productId!.isNotEmpty
              ? _productService.getProductReviews(product.productId!, limit: 8)
              : Future.value(<ProductReview>[]);

      final relatedFuture =
          product.farmerId != null && product.farmerId!.isNotEmpty
              ? _dataService.getProductsByFarmerId(product.farmerId!)
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
            .take(5)
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _numericPrice {
    if (_product == null) return 0.0;
    return double.tryParse(_product!.price.replaceAll(RegExp(r'[^\d.]'), '')) ??
        0.0;
  }

  double get _numericOriginalPrice {
    if (_product?.originalPrice == null) return 0.0;
    return double.tryParse(
            _product!.originalPrice!.replaceAll(RegExp(r'[^\d.]'), '')) ??
        0.0;
  }

  void _handleAddToCart() {
    if (_product == null) return;
    CartService().addItem(_product!, _quantity);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: WebDesignTokens.primaryDark,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Added $_quantity ${_product!.unit} of ${_product!.name} to your cart!',
                style: GoogleFonts.nunitoSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBuyNow() {
    if (_product == null) return;
    CartService().addItem(_product!, _quantity);
    context.go(AppRoutes.cartCheckout);
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final containerWidth = WebBreakpoints.containerWidth(sw);
    final isMobile = WebBreakpoints.isMobile(sw);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: WebDesignTokens.bg,
        body: Column(
          children: [
            WebEcomHeader(currentIndex: 1, onNavigate: (index, [route]) {}),
            const Expanded(
              child: Center(
                child:
                    CircularProgressIndicator(color: WebDesignTokens.primary),
              ),
            ),
          ],
        ),
      );
    }

    if (_product == null) {
      return Scaffold(
        backgroundColor: WebDesignTokens.bg,
        body: Column(
          children: [
            WebEcomHeader(currentIndex: 1, onNavigate: (index, [route]) {}),
            Expanded(
              child: Center(
                child: Text('Product not found', style: GoogleFonts.rubik()),
              ),
            ),
          ],
        ),
      );
    }

    final product = _product!;
    final images = product.imageUrls.isNotEmpty
        ? product.imageUrls
        : (product.imageUrl.isNotEmpty ? [product.imageUrl] : <String>[]);

    return Scaffold(
      backgroundColor: WebDesignTokens.bg,
      body: Column(
        children: [
          // ─── Sticky Header ───
          WebEcomHeader(
            currentIndex: 1,
            onNavigate: (index, [route]) {
              if (route != null) {
                context.go(route);
              } else {
                context.go(AppRoutes.webTabRoute(index));
              }
            },
          ),

          // ─── Main Product Details View ───
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: containerWidth),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Breadcrumbs
                            _buildBreadcrumbs(product),
                            const SizedBox(height: 20),

                            // 50/50 Desktop Split Layout
                            if (isMobile)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildMediaGallery(images),
                                  const SizedBox(height: 24),
                                  _buildPurchaseEngine(product),
                                ],
                              )
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Column: Media Gallery & Timeline (5 cols)
                                  Expanded(
                                    flex: 5,
                                    child: _buildMediaGallery(images),
                                  ),
                                  const SizedBox(width: 36),
                                  // Right Column: Purchase & Farm Trust Engine (6 cols)
                                  Expanded(
                                    flex: 6,
                                    child: _buildPurchaseEngine(product),
                                  ),
                                ],
                              ),

                            const SizedBox(height: 48),

                            // Tabbed Information Section
                            _buildTabbedDetails(product),
                            const SizedBox(height: 48),

                            // More Fresh Picks from this Farmer
                            if (_moreFromFarmer.isNotEmpty) ...[
                              _buildMoreFromFarmerSection(),
                              const SizedBox(height: 48),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Footer
                  const AgriDirectWebFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs(ProductItem product) {
    return Row(
      children: [
        InkWell(
          onTap: () => context.go(AppRoutes.marketplace),
          child: Text(
            'Home',
            style: GoogleFonts.nunitoSans(
                fontSize: 13, color: WebDesignTokens.slate500),
          ),
        ),
        const Text('  /  ',
            style: TextStyle(color: WebDesignTokens.slate400, fontSize: 12)),
        InkWell(
          onTap: () => context.go(AppRoutes.shop),
          child: Text(
            'Shop',
            style: GoogleFonts.nunitoSans(
                fontSize: 13, color: WebDesignTokens.slate500),
          ),
        ),
        if (product.categoryName != null) ...[
          const Text('  /  ',
              style: TextStyle(color: WebDesignTokens.slate400, fontSize: 12)),
          Text(
            product.categoryName!,
            style: GoogleFonts.nunitoSans(
                fontSize: 13, color: WebDesignTokens.slate500),
          ),
        ],
        const Text('  /  ',
            style: TextStyle(color: WebDesignTokens.slate400, fontSize: 12)),
        Flexible(
          child: Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunitoSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: WebDesignTokens.primaryDark,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Left Column: Gallery & Origin Timeline ───
  Widget _buildMediaGallery(List<String> images) {
    final currentImage =
        images.isNotEmpty && _selectedImageIndex < images.length
            ? images[_selectedImageIndex]
            : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Image Viewer
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            color: WebDesignTokens.surface,
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: currentImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: currentImage,
                            fit: BoxFit.cover,
                            errorWidget: (_, error, stackTrace) =>
                                const Icon(Icons.eco,
                                    size: 80, color: WebDesignTokens.primary),
                          )
                        : const Icon(Icons.eco,
                            size: 80, color: WebDesignTokens.primary),
                  ),
                  // Origin Stamp Overlay
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            _product!.farm,
                            style: GoogleFonts.nunitoSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Thumbnail Strip
        if (images.length > 1)
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isSelected = _selectedImageIndex == index;
                return InkWell(
                  onTap: () => setState(() => _selectedImageIndex = index),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? WebDesignTokens.primary
                            : WebDesignTokens.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: images[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 20),

        // Freshness Milestone Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: WebDesignTokens.primaryLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: WebDesignTokens.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_outlined,
                      size: 16, color: WebDesignTokens.primaryDark),
                  const SizedBox(width: 6),
                  Text(
                    'Pangasinan Farm Freshness Guarantee',
                    style: GoogleFonts.rubik(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: WebDesignTokens.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildTimelineNode(
                      '🌱 Picked', 'Morning Harvest', true),
                  _buildTimelineConnector(),
                  _buildTimelineNode(
                      '🔬 Quality', 'Inspected GAP', true),
                  _buildTimelineConnector(),
                  _buildTimelineNode('🚚 Dispatch', 'Same-Day Ready', true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineNode(String title, String subtitle, bool done) {
    return Expanded(
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.rubik(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: WebDesignTokens.primaryDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
              fontSize: 10,
              color: WebDesignTokens.slate600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineConnector() {
    return Container(
      width: 20,
      height: 1.5,
      color: WebDesignTokens.primary.withValues(alpha: 0.4),
    );
  }

  // ─── Right Column: Purchase & Farm Trust Engine ───
  Widget _buildPurchaseEngine(ProductItem product) {
    final hasDiscount = _numericOriginalPrice > _numericPrice;
    final rating = double.tryParse(product.rating ?? '5.0') ?? 5.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Badges
        Text(
          product.name,
          style: GoogleFonts.rubik(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: WebDesignTokens.dark,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),

        // Rating & Sold
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 15, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    rating.toStringAsFixed(1),
                    style: GoogleFonts.rubik(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: WebDesignTokens.dark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${product.reviews ?? '42'} Ratings • ${product.soldCount ?? 128} kg Sold',
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                color: WebDesignTokens.slate500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Price Block
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: WebDesignTokens.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: WebDesignTokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₱${_numericPrice.toStringAsFixed(0)}',
                    style: GoogleFonts.rubik(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: WebDesignTokens.primary,
                    ),
                  ),
                  Text(
                    ' / ${product.unit}',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: WebDesignTokens.slate500,
                    ),
                  ),
                  if (hasDiscount) ...[
                    const SizedBox(width: 12),
                    Text(
                      '₱${_numericOriginalPrice.toStringAsFixed(0)}',
                      style: GoogleFonts.rubik(
                        fontSize: 16,
                        color: WebDesignTokens.slate400,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: WebDesignTokens.discountRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'SAVINGS',
                        style: WebDesignTokens.badge(),
                      ),
                    ),
                  ],
                ],
              ),
              if (product.isWholesale) ...[
                const Divider(height: 24, color: WebDesignTokens.border),

                // Wholesale Bulk Tiers Table
                Text(
                  'Wholesale Bulk Pricing Tiers',
                  style: GoogleFonts.rubik(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: WebDesignTokens.dark,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildBulkTierCard('1–9 ${product.unit}',
                        '₱${_numericPrice.toStringAsFixed(0)}', 'Standard'),
                    const SizedBox(width: 8),
                    _buildBulkTierCard(
                      '10–49 ${product.unit}',
                      '₱${(_numericPrice * 0.9).toStringAsFixed(0)}',
                      'Save 10%',
                      isHighlighted: true,
                    ),
                    const SizedBox(width: 8),
                    _buildBulkTierCard(
                      '50+ ${product.unit}',
                      '₱${(_numericPrice * 0.8).toStringAsFixed(0)}',
                      'Save 20%',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Quantity Stepper + Remaining Stock
        Row(
          children: [
            Text(
              'Quantity:',
              style: GoogleFonts.rubik(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: WebDesignTokens.dark,
              ),
            ),
            const SizedBox(width: 14),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: WebDesignTokens.border),
                borderRadius: BorderRadius.circular(10),
                color: WebDesignTokens.surface,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_rounded, size: 16),
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                  ),
                  Container(
                    width: 44,
                    alignment: Alignment.center,
                    child: Text(
                      '$_quantity',
                      style: GoogleFonts.rubik(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: WebDesignTokens.dark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 16),
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Stock: ${product.stockQuantity?.toInt() ?? 25} ${product.unit} available',
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                color: WebDesignTokens.slate500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Action Buttons: Add to Cart + Buy Now
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: WebDesignTokens.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded,
                    size: 20, color: WebDesignTokens.primary),
                label: Text(
                  'Add to Cart',
                  style: GoogleFonts.rubik(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: WebDesignTokens.primary,
                  ),
                ),
                onPressed: _handleAddToCart,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: WebDesignTokens.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _handleBuyNow,
                child: Text(
                  'Buy Now',
                  style: GoogleFonts.rubik(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Farm Storefront Card
        WebFarmStorefrontCard(
          farmerName: product.farmerName ?? 'Pangasinan Local Grower',
          farmName: product.farm,
          barangay: 'San Carlos City',
          rating: rating,
          responseRate: '98%',
          soldKg: '3,450 kg',
          avatarUrl: _farmerProfile?['avatar_url']?.toString() ??
              product.farmerAvatarUrl,
          onChat: () => context.go(AppRoutes.messages),
          onVisitStore: () {
            if (product.farmerId != null) {
              context.go(AppRoutes.farmerProfile(product.farmerId!));
            } else {
              context.go(AppRoutes.localShops);
            }
          },
        ),
      ],
    );
  }

  Widget _buildBulkTierCard(String range, String price, String badge,
      {bool isHighlighted = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isHighlighted
              ? WebDesignTokens.primaryLight
              : WebDesignTokens.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHighlighted
                ? WebDesignTokens.primary
                : WebDesignTokens.border,
          ),
        ),
        child: Column(
          children: [
            Text(
              range,
              style: GoogleFonts.nunitoSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: WebDesignTokens.slate600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              price,
              style: GoogleFonts.rubik(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isHighlighted
                    ? WebDesignTokens.primaryDark
                    : WebDesignTokens.dark,
              ),
            ),
            Text(
              badge,
              style: GoogleFonts.nunitoSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isHighlighted
                    ? WebDesignTokens.primary
                    : WebDesignTokens.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tabbed Information (Specs, Reviews, Farmer) ───
  Widget _buildTabbedDetails(ProductItem product) {
    return Container(
      decoration: BoxDecoration(
        color: WebDesignTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WebDesignTokens.border),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            controller: _tabController,
            labelColor: WebDesignTokens.primary,
            unselectedLabelColor: WebDesignTokens.slate500,
            indicatorColor: WebDesignTokens.primary,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.rubik(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            tabs: [
              const Tab(text: 'Produce Specifications'),
              Tab(text: 'Customer Reviews (${_reviews.length})'),
              const Tab(text: 'Storage & Freshness Tips'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Specifications
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSpecRow('Variety / Type', product.name),
                      _buildSpecRow('Accredited Farm Origin', product.farm),
                      _buildSpecRow(
                        'Harvest Timing',
                        product.harvestDays ?? 'Picked within last 24 hours',
                      ),
                      _buildSpecRow(
                        'Farming Method',
                        product.isPreorder ? 'Pre-Order Batch' : 'GAP-Certified Farm Direct',
                      ),
                      _buildSpecRow(
                        'Description',
                        product.description ??
                            'Freshly harvested agricultural produce cultivated in Pangasinan soil with sustainable farming practices.',
                      ),
                    ],
                  ),
                ),

                // Tab 2: Reviews
                _reviews.isEmpty
                    ? Center(
                        child: Text(
                          'No customer reviews yet. Be the first to try this harvest!',
                          style: GoogleFonts.nunitoSans(
                            color: WebDesignTokens.slate500,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _reviews.length,
                        separatorBuilder: (_, index) => const Divider(
                            height: 16, color: WebDesignTokens.border),
                        itemBuilder: (context, index) {
                          final r = _reviews[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              backgroundColor: WebDesignTokens.primaryLight,
                              child: Icon(Icons.person,
                                  color: WebDesignTokens.primary),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  r.userName ?? 'Verified Buyer',
                                  style: GoogleFonts.rubik(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: List.generate(
                                    r.rating.round(),
                                    (_) => const Icon(Icons.star_rounded,
                                        size: 13, color: Colors.amber),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              r.reviewText ?? 'Very fresh and fast delivery!',
                              style: GoogleFonts.nunitoSans(fontSize: 12),
                            ),
                          );
                        },
                      ),

                // Tab 3: Storage Tips
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How to keep this harvest fresh:',
                        style: GoogleFonts.rubik(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Store in a cool, dry place away from direct sunlight.\n'
                        '• For leafy vegetables, wrap in a damp paper towel and refrigerate.\n'
                        '• Consume within 5–7 days for optimal nutritional value and peak flavor.',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 13,
                          color: WebDesignTokens.slate600,
                          height: 1.6,
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

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: WebDesignTokens.slate500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: WebDesignTokens.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── More from this Farmer Carousel ───
  Widget _buildMoreFromFarmerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More Harvests from ${_product!.farm}',
          style: GoogleFonts.rubik(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: WebDesignTokens.dark,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 340,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _moreFromFarmer.length,
            separatorBuilder: (_, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final item = _moreFromFarmer[index];
              return SizedBox(
                width: 220,
                child: WebProductCard(
                  product: item,
                  onTap: () {
                    context.go(AppRoutes.product(item.productId ?? 'view'),
                        extra: item);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
