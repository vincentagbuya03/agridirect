import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/data/app_data.dart';
import '../../../shared/models/cached_product.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/offline/offline_cache_service.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/widgets/image_widgets.dart';

import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/models/product/crop_milestone_model.dart';
import '../../../shared/services/commerce/product_service.dart';
import '../../../web/widgets/crop_milestones_timeline.dart';

class PreOrderDetailsScreen extends StatefulWidget {
  const PreOrderDetailsScreen({super.key, this.initialProduct});

  final ProductItem? initialProduct;

  @override
  State<PreOrderDetailsScreen> createState() => _PreOrderDetailsScreenState();
}

class _PreOrderDetailsScreenState extends State<PreOrderDetailsScreen> {
  ProductItem? _product;
  int _quantity = 1;
  String _paymentMethod = 'COD';
  bool _isLoading = false;
  final OfflineCacheService _cacheService = OfflineCacheService();
  bool _isSaved = false;
  List<CropMilestone> _milestones = const [];

  @override
  void initState() {
    super.initState();
    _product = widget.initialProduct;
    _ensureCacheServiceReady();
    _cacheProductForOffline();
    _refreshSavedState();
    if (_product == null) {
      _loadFallbackProduct();
    } else {
      _loadMilestones();
    }
  }

  Future<void> _ensureCacheServiceReady() async {
    if (!_cacheService.isInitialized) {
      await _cacheService.init();
    }
  }

  Future<void> _loadFallbackProduct() async {
    setState(() => _isLoading = true);
    try {
      final products = await SupabaseDataService().getPreOrderProducts();
      if (!mounted || products.isEmpty) return;
      setState(() => _product = products.first);
      _cacheProductForOffline();
      _refreshSavedState();
      _loadMilestones();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMilestones() async {
    final productId = _product?.productId;
    if (productId == null || productId.isEmpty) return;
    try {
      final milestones = await ProductService().getCropMilestones(productId);
      if (mounted) {
        setState(() {
          _milestones = milestones;
        });
      }
    } catch (e) {
      debugPrint('Error loading milestones: $e');
    }
  }

  CachedProduct? _buildCachedProduct() {
    final product = _product;
    if (product == null) return null;

    return CachedProduct(
      id: product.productId ?? 'unknown_${product.name}',
      farmerId: product.farmerId ?? '',
      name: product.name,
      price: _unitPrice(product),
      description: product.description,
      imageUrl: product.imageUrl,
      unit: product.unit,
      farmName: product.farm,
      isPreorder: true,
      harvestDays: int.tryParse(product.harvestDays ?? '0') ?? 0,
      availableQuantity: product.targetQuantity?.toInt(),
      rating: double.tryParse(product.rating ?? '0'),
      category: product.categoryName,
      farmerAvatarUrl: product.farmerAvatarUrl,
      farmerImageUrl: product.farmerImageUrl,
    );
  }

  Future<void> _cacheProductForOffline() async {
    final cachedProduct = _buildCachedProduct();
    if (cachedProduct == null) return;

    await _ensureCacheServiceReady();
    await _cacheService.autoCacheProduct(cachedProduct);
  }

  Future<void> _refreshSavedState() async {
    final cachedProduct = _buildCachedProduct();
    if (cachedProduct == null) return;

    await _ensureCacheServiceReady();
    if (!mounted) return;
    setState(() {
      _isSaved = _cacheService.isProductManuallySaved(cachedProduct.id);
    });
  }

  Future<void> _toggleFavorite() async {
    final cachedProduct = _buildCachedProduct();
    if (cachedProduct == null) return;

    await _ensureCacheServiceReady();
    if (_isSaved) {
      await _cacheService.removeCachedProduct(cachedProduct.id);
    } else {
      await _cacheService.manualSaveProduct(cachedProduct);
    }

    if (!mounted) return;
    setState(() {
      _isSaved = !_isSaved;
    });
    _showSnack(
      _isSaved
          ? '${cachedProduct.name} saved to favorites.'
          : '${cachedProduct.name} removed from favorites.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : product == null
              ? _buildMissingProduct()
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHero(product)),
                    SliverToBoxAdapter(child: _buildContent(product)),
                  ],
                ),
      bottomNavigationBar: product == null ? null : _buildBottomBar(product),
    );
  }

  // ===========================================================================
  // HERO IMAGE & FLOATING NAVIGATION
  // ===========================================================================
  Widget _buildHero(ProductItem product) {
    final imageUrl = product.imageUrl.trim().isNotEmpty
        ? product.imageUrl.trim()
        : (product.farmerImageUrl ?? '').trim();

    final targetQty = product.targetQuantity ?? 0;
    final reservedQty = product.reservedQuantity ?? 0;
    final isFullyReserved = targetQty > 0 && reservedQty >= targetQty;
    final isHarvested = _isHarvested(product);

    return Stack(
      children: [
        // 1. Image Canvas
        AspectRatio(
          aspectRatio: 1.15,
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl.isEmpty
                  ? _buildImageFallback()
                  : SafeNetworkImage(
                      imageUrl: imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: Container(color: const Color(0xFFF1F5F9)),
                      errorWidget: _buildImageFallback(),
                    ),
              // Gradient Shade
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Top Navigation Bar (Back, Share, Favorite)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _roundIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                Row(
                  children: [
                    _roundIconButton(
                      icon: Icons.share_outlined,
                      onTap: _showComingSoon,
                    ),
                    const SizedBox(width: 10),
                    _roundIconButton(
                      icon: _isSaved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      iconColor:
                          _isSaved ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                      onTap: _toggleFavorite,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 3. Floating Status Badges at Bottom of Image
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Pre-order / Stage Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isFullyReserved
                      ? const Color(0xFFEF4444)
                      : isHarvested
                          ? const Color(0xFFEA580C)
                          : AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFullyReserved
                          ? Icons.block_rounded
                          : isHarvested
                              ? Icons.shopping_basket_rounded
                              : Icons.spa_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isFullyReserved
                          ? '100% RESERVED'
                          : isHarvested
                              ? 'HARVESTED · READY'
                              : 'PRE-ORDER ACTIVE',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Category Badge
              if ((product.categoryName ?? '').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    product.categoryName!.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // CONTENT BODY
  // ===========================================================================
  Widget _buildContent(ProductItem product) {
    final rating = double.tryParse(product.rating ?? '') ?? 0.0;
    final targetQty = product.targetQuantity ?? 0;
    final reservedQty = product.reservedQuantity ?? 0;
    final availableQty = (targetQty - reservedQty).clamp(0.0, targetQty);
    final isFullyReserved = targetQty > 0 && reservedQty >= targetQty;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 100% Reserved Warning Banner (If applicable)
          if (isFullyReserved) ...[
            _buildFullyReservedAlertBanner(product),
            const SizedBox(height: 16),
          ] else ...[
            // Crop Growth Stage / Countdown Banner
            _buildCountdownBanner(product),
            const SizedBox(height: 16),
          ],

          // 2. Farm Name & Farmer Attribution Card
          _buildFarmAndFarmerHeader(product),
          const SizedBox(height: 14),

          // 3. Product Name & Price Header
          Text(
            product.name,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),

          // Price & Rating Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _normalizePrice(product.price),
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 4),
                child: Text(
                  '/ ${_unitLabel(product)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              const Spacer(),
              if (rating > 0) _buildStarRating(rating),
            ],
          ),
          const SizedBox(height: 20),

          // 4. 2x2 Harvest Metrics Grid
          _buildHarvestMetricsGrid(product),
          const SizedBox(height: 18),

          // 5. Reservation Progress Meter
          _buildReservationProgressCard(product),
          const SizedBox(height: 18),

          // 6. Quantity Card (Disabled if 100% Reserved)
          _buildQuantitySelectorCard(product, availableQty.round(), isFullyReserved),
          const SizedBox(height: 16),

          // 7. Payment Option Card
          _buildPaymentOptionCard(),
          const SizedBox(height: 24),

          // 8. Description Section
          Text(
            'About This Harvest',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              (product.description ?? '').trim().isNotEmpty
                  ? product.description!.trim()
                  : 'No detailed harvest description provided by the farmer.',
              style: GoogleFonts.inter(
                color: (product.description ?? '').trim().isNotEmpty
                    ? const Color(0xFF334155)
                    : const Color(0xFF94A3B8),
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 9. Crop Milestones Timeline
          CropMilestonesTimeline(milestones: _milestones),
        ],
      ),
    );
  }

  // ===========================================================================
  // FARM & FARMER HEADER
  // ===========================================================================
  Widget _buildFarmAndFarmerHeader(ProductItem product) {
    final farmName = product.farm.trim();
    final farmerName = (product.farmerName ?? '').trim();
    final displayFarm = farmName.isNotEmpty && farmName != 'Farm'
        ? farmName
        : (farmerName.isNotEmpty ? farmerName : 'Local Farm');
    final hasDistinctFarmer = farmerName.isNotEmpty && farmerName != displayFarm;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE2E8F0),
            backgroundImage: (product.farmerAvatarUrl ?? '').isNotEmpty
                ? NetworkImage(product.farmerAvatarUrl!)
                : null,
            child: (product.farmerAvatarUrl ?? '').isEmpty
                ? const Icon(
                    Icons.storefront_rounded,
                    size: 20,
                    color: AppColors.primary,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayFarm,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                if (hasDistinctFarmer)
                  Text(
                    'Grown by $farmerName',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'DIRECT FARMER',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FULLY RESERVED ALERT BANNER
  // ===========================================================================
  Widget _buildFullyReservedAlertBanner(ProductItem product) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '100% Reserved (Target Capacity Reached)',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All available yield for this harvest batch has been reserved. New pre-orders are closed for this cycle.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFFB91C1C),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // COUNTDOWN & STAGE BANNER
  // ===========================================================================
  Widget _buildCountdownBanner(ProductItem product) {
    final days = int.tryParse(product.harvestDays ?? '0') ?? 0;
    final harvested = _isHarvested(product);

    String stageTitle = 'Growing & Nurturing Stage';
    Color bannerColor = const Color(0xFFECFDF5);
    Color borderColor = const Color(0xFFA7F3D0);
    Color textColor = const Color(0xFF065F46);
    IconData icon = Icons.spa_rounded;
    String description =
        'The crop is progressing smoothly towards harvest. Reserve your share early to secure fresh farm prices.';

    if (harvested) {
      stageTitle = 'Ready for Harvest & Dispatch!';
      bannerColor = const Color(0xFFFFFBEB);
      borderColor = const Color(0xFFFDE68A);
      textColor = const Color(0xFF92400E);
      icon = Icons.shopping_basket_rounded;
      description =
          'This crop has completed its growth cycle and is ready for immediate ordering and delivery.';
    } else if (days <= 3) {
      stageTitle = 'Nearing Harvest Very Soon! ⏰';
      bannerColor = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFECACA);
      textColor = const Color(0xFF991B1B);
      icon = Icons.alarm_rounded;
      description =
          'Harvest is scheduled within the next 3 days. Last chance to secure reservation!';
    } else if (_milestones.isNotEmpty) {
      final latest = _milestones.first;
      stageTitle = 'Latest Update: ${latest.title}';
      description = latest.description;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: textColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stageTitle,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF334155),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2X2 HARVEST METRICS
  // ===========================================================================
  Widget _buildHarvestMetricsGrid(ProductItem product) {
    final targetQty = product.targetQuantity ?? 0;
    final reservedQty = product.reservedQuantity ?? 0;
    final reservedRatio =
        targetQty > 0 ? ((reservedQty / targetQty) * 100).round() : 0;

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _infoTile(
                Icons.calendar_today_rounded,
                'Est. Harvest',
                _harvestLabel(product),
              ),
              const SizedBox(height: 10),
              _infoTile(
                Icons.category_rounded,
                'Category',
                (product.categoryName ?? '').isNotEmpty
                    ? product.categoryName!
                    : 'General',
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              _infoTile(
                Icons.inventory_2_rounded,
                'Target Yield',
                _targetLabel(product),
              ),
              const SizedBox(height: 10),
              _infoTile(
                Icons.people_alt_rounded,
                'Reserved',
                targetQty > 0 ? '$reservedRatio% Capacity' : 'Open',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // RESERVATION PROGRESS CARD
  // ===========================================================================
  Widget _buildReservationProgressCard(ProductItem product) {
    final targetQty = product.targetQuantity ?? 0;
    final reservedQty = product.reservedQuantity ?? 0;
    final reservedPercentage =
        targetQty > 0 ? (reservedQty / targetQty).clamp(0.0, 1.0) : 0.0;
    final reservedPercentText =
        targetQty > 0 ? (reservedPercentage * 100).round() : 0;
    final isFullyReserved = targetQty > 0 && reservedQty >= targetQty;
    final isHot = reservedPercentText >= 75 && !isFullyReserved;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFullyReserved
              ? const Color(0xFFFECACA)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reservation Progress',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (isFullyReserved)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'FULLY RESERVED',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                )
              else if (isHot)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.whatshot_rounded,
                        color: Color(0xFFEA580C),
                        size: 13,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'HIGH DEMAND',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEA580C),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: reservedPercentage,
              minHeight: 10,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                isFullyReserved
                    ? const Color(0xFFEF4444)
                    : isHot
                        ? const Color(0xFFEA580C)
                        : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$reservedPercentText% Reserved',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: isFullyReserved
                      ? const Color(0xFFEF4444)
                      : isHot
                          ? const Color(0xFFEA580C)
                          : const Color(0xFF0F172A),
                ),
              ),
              Text(
                targetQty > 0
                    ? '${reservedQty.toStringAsFixed(0)} / ${targetQty.toStringAsFixed(0)} ${_unitLabel(product)}'
                    : 'Target Flexible',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // QUANTITY & PAYMENT CARDS
  // ===========================================================================
  Widget _buildQuantitySelectorCard(
    ProductItem product,
    int availableQty,
    bool isFullyReserved,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isFullyReserved
                  ? const Color(0xFFF1F5F9)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.scale_rounded,
              color: isFullyReserved
                  ? const Color(0xFF94A3B8)
                  : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Quantity',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  isFullyReserved
                    ? 'Target Reached · 0 available'
                    : availableQty > 0
                        ? '$availableQty ${_unitLabel(product)} remaining'
                        : 'Min order: 1 ${_unitLabel(product)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isFullyReserved
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (isFullyReserved)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'FULL',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            )
          else ...[
            _qtyButton(
              Icons.remove_rounded,
              _quantity > 1 ? () => setState(() => _quantity--) : null,
            ),
            SizedBox(
              width: 38,
              child: Text(
                '$_quantity',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            _qtyButton(
              Icons.add_rounded,
              (availableQty <= 0 || _quantity < availableQty)
                  ? () => setState(() => _quantity++)
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentOptionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Method',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  _paymentMethod == 'COD'
                      ? 'Cash on Delivery upon Harvest'
                      : 'Cash on Pickup at Farm',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _paymentMethod,
              items: const [
                DropdownMenuItem(
                  value: 'COD',
                  child: Text('COD', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                DropdownMenuItem(
                  value: 'COP',
                  child: Text('COP', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _paymentMethod = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BOTTOM ACTION BAR
  // ===========================================================================
  Widget _buildBottomBar(ProductItem product) {
    final isOwnProduct = AuthService().userId.isNotEmpty &&
        product.farmerId == AuthService().userId;

    if (isOwnProduct) {
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            border: Border(
              top: BorderSide(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This is your own harvest. You cannot pre-order it.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF92400E),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final targetQty = product.targetQuantity ?? 0;
    final reservedQty = product.reservedQuantity ?? 0;
    final isFullyReserved = targetQty > 0 && reservedQty >= targetQty;
    final isHarvested = _isHarvested(product);
    final totalPrice = _unitPrice(product) * _quantity;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Price Calculation Column
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFullyReserved ? 'Status' : 'Total Price',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    isFullyReserved
                        ? '100% Reserved'
                        : _formatCurrencyValue(totalPrice),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isFullyReserved
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),

            // Pre-order / Order CTA Button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: isFullyReserved
                    ? null
                    : () {
                        context.push(
                          AppRoutes.checkout,
                          extra: {
                            'product': product,
                            'quantity': _quantity,
                            'isPreOrder': !isHarvested,
                          },
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: const Color(0xFF64748B),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFullyReserved
                          ? Icons.block_rounded
                          : Icons.shopping_bag_outlined,
                      size: 18,
                      color: isFullyReserved
                          ? const Color(0xFF64748B)
                          : Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isFullyReserved
                          ? 'FULLY RESERVED'
                          : isHarvested
                              ? 'ORDER NOW'
                              : 'RESERVE HARVEST',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isFullyReserved
                            ? const Color(0xFF64748B)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HELPERS & UI COMPONENTS
  // ===========================================================================
  Widget _buildStarRating(double rating) {
    final fullStars = rating.floor();
    final hasHalf = (rating - fullStars) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          if (i < fullStars) {
            return const Icon(
              Icons.star_rounded,
              size: 16,
              color: AppColors.accent,
            );
          } else if (i == fullStars && hasHalf) {
            return const Icon(
              Icons.star_half_rounded,
              size: 16,
              color: AppColors.accent,
            );
          }
          return const Icon(
            Icons.star_outline_rounded,
            size: 16,
            color: Color(0xFFCBD5E1),
          );
        }),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.inter(
            color: const Color(0xFF475569),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 18,
          color: iconColor ?? const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback? onTap) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isEnabled
              ? AppColors.primary.withValues(alpha: 0.12)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isEnabled ? AppColors.primary : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(
          Icons.agriculture_rounded,
          color: Color(0xFF94A3B8),
          size: 48,
        ),
      ),
    );
  }

  Widget _buildMissingProduct() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.spa_outlined,
              size: 64,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            Text(
              'No Pre-Order Selected',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please go back to the Pre-Order Hub and choose a harvest.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Back to Hub'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isHarvested(ProductItem product) {
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

  void _showComingSoon() {
    _showSnack('Sharing will be available soon.');
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  String _harvestLabel(ProductItem product) {
    final days = int.tryParse(product.harvestDays ?? '');
    if (days == null) return 'TBD';
    if (days <= 0) return 'Date TBD';
    if (product.createdAt != null) {
      final harvestDate = product.createdAt!.add(Duration(days: days));
      final now = DateTime.now();
      final diff = harvestDate.difference(now);
      if (diff.isNegative) {
        return 'Harvested';
      }
      final remainingDays = diff.inDays;
      if (remainingDays >= 1) {
        return '$remainingDays days left';
      }
      final remainingHours = diff.inHours;
      if (remainingHours >= 1) {
        return '$remainingHours hrs left';
      }
      final remainingMinutes = diff.inMinutes;
      if (remainingMinutes >= 1) {
        return '$remainingMinutes mins left';
      }
      return 'Harvesting now';
    }
    return '$days days';
  }

  String _targetLabel(ProductItem product) {
    final target = product.targetQuantity;
    if (target == null || target <= 0) return 'TBD';
    return '${target.toStringAsFixed(0)} ${_unitLabel(product)}';
  }

  String _unitLabel(ProductItem product) {
    final unit = product.unit.trim();
    return unit.isEmpty ? 'kg' : unit;
  }

  double _unitPrice(ProductItem product) {
    final normalized = product.price.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(normalized) ?? 0;
  }

  String _normalizePrice(String price) {
    final trimmed = price.trim();
    if (trimmed.isEmpty) return '₱0.00';

    final numeric = trimmed.replaceAll(RegExp(r'[^0-9.]'), '');
    if (numeric.isEmpty) return '₱0.00';

    final val = double.tryParse(numeric);
    if (val != null) {
      return '₱${val.toStringAsFixed(2)}';
    }
    return '₱$numeric';
  }

  String _formatCurrencyValue(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }
}
