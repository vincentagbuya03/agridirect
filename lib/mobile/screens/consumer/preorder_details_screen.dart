import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
  bool _isSubmitting = false;
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : product == null
            ? _buildMissingProduct()
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHero(product)),
                  SliverToBoxAdapter(child: _buildContent(product)),
                ],
              ),
      ),
      bottomNavigationBar: product == null ? null : _buildBottomBar(product),
    );
  }

  Widget _buildHero(ProductItem product) {
    final imageUrl = product.imageUrl.trim().isNotEmpty
        ? product.imageUrl.trim()
        : (product.farmerImageUrl ?? '').trim();

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1.08,
          child: imageUrl.isEmpty
              ? _buildImageFallback()
              : SafeNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: Container(color: AppColors.background),
                  errorWidget: _buildImageFallback(),
                ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: _roundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Row(
            children: [
              _roundIconButton(
                icon: Icons.share_rounded,
                onTap: _showComingSoon,
              ),
              const SizedBox(width: 10),
              _roundIconButton(
                icon: _isSaved
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                onTap: _toggleFavorite,
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'PRE-ORDER ACTIVE',
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ProductItem product) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCountdownBanner(product),
          const SizedBox(height: 18),
          _farmChip(product),
          const SizedBox(height: 16),
          Text(
            product.name,
            style: AppTextStyles.headline1.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrencyLabel(product.price),
                style: AppTextStyles.headline1.copyWith(
                  fontSize: 28,
                  color: AppColors.textHeadline,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'per ${_unitLabel(product)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSubtle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  Icons.calendar_today_rounded,
                  'Harvest',
                  _harvestLabel(product),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoTile(
                  Icons.inventory_2_rounded,
                  'Target',
                  _targetLabel(product),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _quantityCard(product),
          const SizedBox(height: 18),
          _paymentCard(),
          if ((product.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              'About this harvest',
              style: AppTextStyles.headline3.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              product.description!.trim(),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textBody,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 28),
          CropMilestonesTimeline(milestones: _milestones),
        ],
      ),
    );
  }

  Widget _buildCountdownBanner(ProductItem product) {
    final days = int.tryParse(product.harvestDays ?? '0') ?? 0;
    final harvested = _isHarvested(product);
    
    String stageTitle = 'Growing Stage';
    Color bannerColor = AppColors.primary.withValues(alpha: 0.1);
    Color textColor = AppColors.primary;
    IconData icon = Icons.spa_outlined;
    String description = 'The crop is growing well. Stay tuned for updates!';

    if (harvested) {
      stageTitle = 'Ready for Harvest!';
      bannerColor = Colors.orange.withValues(alpha: 0.1);
      textColor = Colors.orange[800]!;
      icon = Icons.shopping_basket_rounded;
      description = 'This crop has been harvested and is ready for ordering!';
    } else if (days <= 3) {
      stageTitle = 'Nearing Harvest! 🕒';
      bannerColor = AppColors.error.withValues(alpha: 0.1);
      textColor = AppColors.error;
      icon = Icons.alarm_rounded;
      description = 'Almost ready! The crop will be harvested very soon.';
    } else if (_milestones.isNotEmpty) {
      final latest = _milestones.first;
      stageTitle = 'Latest Status: ${latest.title}';
      description = latest.description;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stageTitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textBody,
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

  Widget _buildBottomBar(ProductItem product) {
    final isOwnProduct = AuthService().userId.isNotEmpty &&
        product.farmerId == AuthService().userId;

    if (isOwnProduct) {
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            border: Border(
              top: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This is your own harvest. You cannot pre-order it.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final harvested = _isHarvested(product);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.textHeadline.withValues(alpha: 0.08),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSubtle,
                    ),
                  ),
                  Text(
                    _formatCurrencyValue(_unitPrice(product) * _quantity),
                    style: AppTextStyles.headline3.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        context.push(
                          AppRoutes.checkout,
                          extra: {
                            'product': product,
                            'quantity': _quantity,
                            'isPreOrder': !harvested,
                          },
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(harvested ? 'Order Now' : 'Pre-order Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityCard(ProductItem product) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          const Icon(Icons.scale_rounded, color: AppColors.textHeadline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quantity',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Min order: 1 ${_unitLabel(product)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
          _qtyButton(Icons.remove_rounded, () {
            if (_quantity > 1) setState(() => _quantity--);
          }),
          SizedBox(
            width: 44,
            child: Text(
              '$_quantity',
              textAlign: TextAlign.center,
              style: AppTextStyles.headline3.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _qtyButton(Icons.add_rounded, () => setState(() => _quantity++)),
        ],
      ),
    );
  }

  Widget _paymentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          const Icon(Icons.local_atm_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _paymentMethod == 'COD'
                      ? 'Cash on Delivery'
                      : 'Cash on Pickup',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _paymentMethod,
              items: const [
                DropdownMenuItem(value: 'COD', child: Text('COD')),
                DropdownMenuItem(value: 'COP', child: Text('COP')),
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

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: 10),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _farmChip(ProductItem product) {
    final farm = product.farm.trim().isEmpty ? 'Farm' : product.farm.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_rounded,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            farm,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppColors.textHeadline),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.textSubtle,
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
              color: AppColors.textSubtle,
            ),
            const SizedBox(height: 16),
            Text(
              'No pre-order selected',
              style: AppTextStyles.headline3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Go back to the Pre-Order Hub and choose a harvest.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSubtle,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Hub'),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.08)),
    );
  }


  void _showComingSoon() {
    _showSnack('This action is coming soon.');
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
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
        return '$remainingDays days';
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
    return unit.isEmpty ? 'unit' : unit;
  }

  double _unitPrice(ProductItem product) {
    final normalized = product.price.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(normalized) ?? 0;
  }

  String _formatCurrencyLabel(String value) {
    return _formatCurrencyValue(_unitPriceFromLabel(value));
  }

  double _unitPriceFromLabel(String value) {
    final normalized = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(normalized) ?? 0;
  }

  String _formatCurrencyValue(double amount) {
    final fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts.first;
    final buffer = StringBuffer();

    for (var i = 0; i < whole.length; i++) {
      final remaining = whole.length - i;
      buffer.write(whole[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    return 'PHP ${buffer.toString()}.${parts.last}';
  }
}
