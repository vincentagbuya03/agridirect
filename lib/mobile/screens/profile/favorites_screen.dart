import 'package:flutter/material.dart';
import '../consumer/marketplace_screen.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/models/cached_product.dart';
import '../../../shared/services/offline/offline_cache_service.dart';
import '../../../shared/styles/app_theme.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final OfflineCacheService _cacheService = OfflineCacheService();
  List<CachedProduct> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (!_cacheService.isInitialized) {
      await _cacheService.init();
    }

    if (!mounted) return;
    setState(() {
      _favorites = _cacheService.getManuallySavedProducts();
      _isLoading = false;
    });
  }

  Future<void> _removeFavorite(CachedProduct product) async {
    await _cacheService.removeCachedProduct(product.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} removed from favorites.'),
        backgroundColor: AppColors.success,
      ),
    );
    await _loadFavorites();
  }

  ProductItem _toProductItem(CachedProduct product) {
    return ProductItem(
      productId: product.id,
      farmerId: product.farmerId,
      farmerAvatarUrl: product.farmerAvatarUrl,
      farmerImageUrl: product.farmerImageUrl,
      name: product.name,
      farm: product.farmName ?? 'Farm',
      price: '₱${product.price.toStringAsFixed(2)}',
      unit: (product.unit ?? '').trim().isEmpty ? 'kg' : product.unit!.trim(),
      imageUrl: product.imageUrl ?? '',
      categoryName: product.category,
      rating: (product.rating ?? 0).toStringAsFixed(1),
      harvestDays: product.harvestDays.toString(),
      description: product.description,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Favorites'),
        backgroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 56,
                      color: AppColors.textSubtle.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No saved favorites yet',
                      style: AppTextStyles.headline3,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Products you save for offline viewing will appear here.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSubtle,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _favorites.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final product = _favorites[index];
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ProductViewScreen(product: _toProductItem(product)),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: AppDecorations.cardDecoration.copyWith(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 86,
                            height: 86,
                            child: product.imageUrl != null &&
                                    product.imageUrl!.isNotEmpty
                                ? Image.network(
                                    product.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      color: AppColors.primaryLight,
                                      child: const Icon(
                                        Icons.image_outlined,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: AppColors.primaryLight,
                                    child: const Icon(
                                      Icons.image_outlined,
                                      color: AppColors.primary,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: AppTextStyles.headline3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                product.farmName ?? 'Farm',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSubtle,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '₱${product.price.toStringAsFixed(2)}',
                                style: AppTextStyles.headline3.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _removeFavorite(product),
                          icon: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
