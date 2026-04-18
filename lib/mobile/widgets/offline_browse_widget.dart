import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../../shared/models/cached_product.dart';
import '../../shared/styles/app_theme.dart';
import '../../shared/services/offline/offline_cache_service.dart';

/// Widget to show "Offline Mode" indicator with cache info
class OfflineModeIndicator extends StatelessWidget {
  final OfflineCacheService cacheService;

  const OfflineModeIndicator({super.key, required this.cacheService});

  @override
  Widget build(BuildContext context) {
    final cacheInfo = cacheService.getCacheInfo();
    final cachedCount = cacheInfo['totalCount'] ?? 0;

    if (cachedCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You\'re Offline. No cached products yet.',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.orange),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.offline_bolt_rounded,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Offline Mode',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                Text(
                  'Browsing $cachedCount cached products',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSubtle,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Button to save a product for offline viewing (use in product tiles)
class SaveForOfflineButton extends StatefulWidget {
  final CachedProduct product;
  final OfflineCacheService cacheService;
  final VoidCallback? onSaved;

  const SaveForOfflineButton({
    super.key,
    required this.product,
    required this.cacheService,
    this.onSaved,
  });

  @override
  State<SaveForOfflineButton> createState() => _SaveForOfflineButtonState();
}

class _SaveForOfflineButtonState extends State<SaveForOfflineButton> {
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.cacheService.isProductManuallySaved(widget.product.id);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _toggleSaveProduct,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _isSaved
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isSaved
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              size: 16,
              color: _isSaved ? AppColors.primary : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              _isSaved ? 'Saved' : 'Save',
              style: AppTextStyles.labelSmall.copyWith(
                color: _isSaved ? AppColors.primary : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSaveProduct() async {
    if (_isSaved) {
      await widget.cacheService.removeCachedProduct(widget.product.id);
    } else {
      await widget.cacheService.manualSaveProduct(widget.product);
    }
    setState(() {
      _isSaved = !_isSaved;
    });
    widget.onSaved?.call();
  }
}

/// Simple cached product card (use in offline mode)
class CachedProductCard extends StatelessWidget {
  final CachedProduct product;
  final VoidCallback? onTap;
  final OfflineCacheService? cacheService;

  const CachedProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.cacheService,
  });

  @override
  Widget build(BuildContext context) {
    final isSaved = cacheService?.isProductManuallySaved(product.id) ?? false;
    final imagePath = (product.imageUrl ?? '').trim();
    final isLocalFile =
        imagePath.startsWith('/') ||
        imagePath.startsWith('file://') ||
        imagePath.contains(':\\');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSaved
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1),
            width: isSaved ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                Container(
                  height: 108,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child:
                      product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? (isLocalFile
                            ? ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                                child: Image.file(
                                  File(
                                    imagePath.startsWith('file://')
                                        ? imagePath.replaceFirst('file://', '')
                                        : imagePath,
                                  ),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Center(
                                    child: Icon(
                                      Icons.image_not_supported_rounded,
                                      color: Colors.grey[400],
                                      size: 40,
                                    ),
                                  ),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: product.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Center(
                                  child: AppShimmerLoader(
                                    strokeWidth: 2,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, _, _) => Center(
                                  child: Icon(
                                    Icons.image_not_supported_rounded,
                                    color: Colors.grey[400],
                                    size: 40,
                                  ),
                                ),
                              ))
                      : Center(
                          child: Icon(
                            Icons.image_rounded,
                            color: Colors.grey[400],
                            size: 40,
                          ),
                        ),
                ),
                if (isSaved)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.bookmark_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.farmName ?? 'Farm',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSubtle,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₱${product.price.toStringAsFixed(2)}',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            fontSize: 14,
                          ),
                        ),
                        if (product.isPreorder)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Pre-order',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.amber[700],
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
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
}

/// List of cached products for offline browsing
class CachedProductsList extends StatelessWidget {
  final List<CachedProduct> products;
  final OfflineCacheService cacheService;
  final bool showEmpty;

  const CachedProductsList({
    super.key,
    required this.products,
    required this.cacheService,
    this.showEmpty = true,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty && showEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Cached Products',
              style: AppTextStyles.headline3.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Products will be cached here when you browse online',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.55,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return CachedProductCard(
          product: products[index],
          cacheService: cacheService,
        );
      },
    );
  }
}

