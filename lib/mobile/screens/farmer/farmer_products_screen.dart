import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'dart:async';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/models/cached_product.dart';
import '../../../shared/services/offline/offline_cache_service.dart';
import '../../../shared/services/offline/offline_queue_service.dart';
import '../../../shared/models/offline_product_queue.dart';
import '../../widgets/offline_browse_widget.dart';
import '../../../shared/services/auth/auth_service.dart';

/// Farmer Products/Inventory Screen - Professional Enterprise UI
class FarmerProductsScreen extends StatefulWidget {
  const FarmerProductsScreen({super.key});

  @override
  State<FarmerProductsScreen> createState() => _FarmerProductsScreenState();
}

class _FarmerProductsScreenState extends State<FarmerProductsScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  final TextEditingController _searchController = TextEditingController();
  bool _isOnline = true;
  late OfflineCacheService _cacheService;
  late OfflineQueueService _queueService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initializeCacheService();
    _initializeQueueService();
    _setupConnectivityListener();
    _loadProducts();
  }

  void _initializeCacheService() {
    _cacheService = OfflineCacheService();
  }

  Future<void> _initializeQueueService() async {
    _queueService = OfflineQueueService();
    await _queueService.init();
  }

  List<OfflineProductQueue> _getFilteredPendingProducts() {
    final farmerId = AuthService().userId;
    return _queueService
        .getPendingProducts()
        .where((p) => p.farmerId == farmerId)
        .toList();
  }

  CachedProduct _pendingToCachedProduct(OfflineProductQueue product) {
    final localPreview = product.localImagePaths.isNotEmpty
        ? product.localImagePaths.first
        : null;
    return CachedProduct(
      id: product.id,
      farmerId: product.farmerId,
      name: product.name,
      price: product.price,
      description: product.description,
      imageUrl: product.imageUrl ?? localPreview,
      availableQuantity: product.availableQuantity,
      isPreorder: product.isPreorder,
      harvestDays: product.harvestDays,
      farmName: product.syncError != null ? 'SYNC FAILED' : 'Pending Sync',
      isManuallySaved: true,
    );
  }

  void _setupConnectivityListener() {
    Connectivity().checkConnectivity().then((result) {
      final isOnline =
          result.isNotEmpty && result.first != ConnectivityResult.none;
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
        if (!isOnline) {
        }
      }
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      final isOnline =
          result.isNotEmpty && result.first != ConnectivityResult.none;
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _loadProducts() {
    if (!mounted) return;
    setState(() {
      _productsFuture = SupabaseDataService().getFarmerProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildPremiumHeader(),
          _buildSearchAndFilter(),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box<OfflineProductQueue>(OfflineQueueService.boxName).listenable(),
              builder: (context, queueBox, _) {
                return ValueListenableBuilder(
                  valueListenable: Hive.box<CachedProduct>('cached_products').listenable(),
                  builder: (context, cacheBox, _) {
                    return _buildProductsList();
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push(AppRoutes.addProduct);
          _loadProducts();
        },
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'LIST PRODUCT',
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textHeadline.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MY INVENTORY',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Product Catalog',
                        style: AppTextStyles.headline2.copyWith(fontSize: 24),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.bar_chart_rounded,
                        color: AppColors.primary,
                      ),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 52,
              decoration: AppDecorations.cardDecoration.copyWith(
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search your inventory...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSubtle,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSubtle,
                    size: 22,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 52,
            width: 52,
            decoration: AppDecorations.cardDecoration.copyWith(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: AppColors.textHeadline,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    if (!_isOnline) {
      final cachedProducts = _cacheService.getAllCachedProducts();
      final farmerCached = cachedProducts
          .where((p) => p.farmerId == AuthService().userId)
          .toList();
      final pendingProducts = _getFilteredPendingProducts();
      final pendingIds = pendingProducts.map((p) => p.id).toSet();
      
      final pendingAsCached = pendingProducts
          .map(_pendingToCachedProduct)
          .toList();
      
      final mergedById = <String, CachedProduct>{};
      for (final p in farmerCached) {
        mergedById[p.id] = p;
      }
      for (final p in pendingAsCached) {
        mergedById[p.id] = p;
      }
      
      final offlineProducts = mergedById.values.toList();

      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        physics: const BouncingScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: OfflineModeIndicator(cacheService: _cacheService),
          ),
          if (offlineProducts.isEmpty)
            _buildEmptyState(
              icon: Icons.offline_bolt_rounded,
              title: 'No Cached Products',
              subtitle: 'Load products while online to view them offline.',
              action: () {},
            )
          else
            ...offlineProducts.map((p) => _buildOfflineProductCard(
              p, 
              isPending: pendingIds.contains(p.id),
            )),
        ],
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppShimmerLoader());
        }

        final onlineProducts = snapshot.data ?? [];
        final List<Widget> listItems = [];
        final pendingProducts = _getFilteredPendingProducts();

        if (pendingProducts.isNotEmpty) {
          for (final pending in pendingProducts) {
            listItems.add(
              _buildOfflineProductCard(_pendingToCachedProduct(pending), isPending: true),
            );
          }
        }

        for (final product in onlineProducts) {
          listItems.add(_buildProductCard(product));
        }

        if (onlineProducts.isNotEmpty) {
          for (final product in onlineProducts) {
            final availableQty = (product['available'] as num?)?.toInt();
            final harvestDays =
                int.tryParse(
                  product['harvest']?.toString().replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      ) ??
                      '',
                ) ??
                0;
            final cachedProduct = CachedProduct(
              id: product['id'] as String? ?? 'unknown',
              farmerId: AuthService().userId,
              name: product['name'] as String? ?? 'Unknown',
              price:
                  double.tryParse(product['price']?.toString() ?? '0') ?? 0.0,
              description: product['description'] as String?,
              imageUrl: product['image'] as String?,
              availableQuantity:
                  (product['available_quantity'] as num?)?.toInt() ??
                  availableQty,
              isPreorder: product['is_preorder'] as bool? ?? false,
              harvestDays: harvestDays,
            );
            _cacheService.autoCacheProduct(cachedProduct);
          }
        }

        if (listItems.isEmpty) {
          return _buildEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Empty Inventory',
            subtitle:
                'Start listing your agricultural products to reach customers.',
            buttonLabel: 'Add Your First Product',
            action: () => context.push(AppRoutes.addProduct),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            _loadProducts();
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            physics: const BouncingScrollPhysics(),
            children: listItems,
          ),
        );
      },
    );
  }

  Widget _buildOfflineProductCard(CachedProduct product, {bool isPending = false}) {
    // Check if there's a sync error for this product
    final queueItem = isPending ? _queueService.getAllProducts().firstWhere((p) => p.id == product.id) : null;
    final syncError = queueItem?.syncError;

    return _buildProductCard({
      'id': product.id,
      'name': product.name,
      'price': product.price,
      'description': product.description,
      'image': product.imageUrl,
      'available': product.availableQuantity,
      'is_preorder': product.isPreorder,
      'harvest': product.harvestDays > 0 
          ? 'In ${product.harvestDays} days' 
          : (product.isPreorder ? 'Pre-order' : 'Ready Now'),
      'status': syncError != null ? 'SYNC ERROR' : (isPending ? 'PENDING SYNC' : 'LIVE (OFFLINE)'),
      'unit': 'kg',
      'is_pending': isPending,
      'is_offline': true,
      'sync_error': syncError,
    });
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final status = product['status']?.toString().toUpperCase() ?? 'IN STOCK';
    Color statusColor;
    switch (status) {
      case 'SOLD OUT':
        statusColor = AppColors.error;
        break;
      case 'LOW STOCK':
        statusColor = AppColors.warning;
        break;
      case 'PENDING SYNC':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = AppColors.success;
    }

    final isOffline = product['is_offline'] == true;
    final imagePath = (product['image']?.toString() ?? '').trim();
    final isLocalFile =
        imagePath.startsWith('/') ||
        imagePath.startsWith('file://') ||
        imagePath.contains(':\\');

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(24),
        border: isOffline
            ? Border.all(
                color: Colors.orange.withValues(alpha: 0.3),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 110,
                    height: 110,
                    color: AppColors.background,
                    child: imagePath.isNotEmpty
                        ? (isLocalFile
                              ? Image.file(
                                  File(
                                    imagePath.startsWith('file://')
                                        ? imagePath.replaceFirst('file://', '')
                                        : imagePath,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  imageUrl: imagePath,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: AppShimmerLoader(strokeWidth: 2),
                                    ),
                                  ),
                                ))
                        : const Icon(
                            Icons.spa_rounded,
                            color: AppColors.textSubtle,
                            size: 40,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.more_horiz_rounded,
                            color: AppColors.textSubtle,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product['name'] ?? 'Product Name',
                        style: AppTextStyles.headline3.copyWith(fontSize: 18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₱${(product['price'] ?? 0).toStringAsFixed(2)} / ${product['unit'] ?? 'kg'}',
                        style: AppTextStyles.headline2.copyWith(
                          color: AppColors.primary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildMiniStat(
                            Icons.inventory_2_outlined,
                            '${product['available'] ?? 0} ${product['unit'] ?? 'kg'}',
                          ),
                          _buildMiniStat(
                            Icons.event_available_outlined,
                            product['harvest'] ?? 'Ready Now',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.textHeadline.withValues(alpha: 0.02),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    Icons.edit_outlined,
                    'Manage Item',
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Management system coming soon'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    Icons.delete_outline_rounded,
                    'Remove',
                    () => _showDeleteConfirmation(context, product),
                    isDestructive: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSubtle),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSubtle,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDestructive
                  ? AppColors.error.withValues(alpha: 0.2)
                  : AppColors.textHeadline.withValues(alpha: 0.05),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isDestructive ? AppColors.error : AppColors.textHeadline,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: isDestructive
                      ? AppColors.error
                      : AppColors.textHeadline,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? buttonLabel,
    required VoidCallback action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTextStyles.headline2.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSubtle,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (buttonLabel != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: action,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    buttonLabel,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              TextButton(onPressed: action, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text('Delete Product', style: AppTextStyles.headline3),
          content: Text(
            'Are you sure you want to remove ${product['name']} from your inventory?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Keep It',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSubtle,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteProduct(product);
              },
              child: Text(
                'Remove',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteProduct(Map<String, dynamic> product) async {
    final productId = product['id']?.toString() ?? '';
    final isOffline = product['is_offline'] == true;

    if (productId.isEmpty) return;

    try {
      if (isOffline) {
        final isPending = product['is_pending'] == true;
        bool success = false;
        
        if (isPending) {
          // Remove from both queue and cache to ensure it disappears
          final queueSuccess = await _queueService.removeProduct(productId);
          await _cacheService.removeCachedProduct(productId);
          success = queueSuccess;
        } else {
          // It's just a cached live product, remove from cache
          await _cacheService.removeCachedProduct(productId);
          success = true;
        }
        
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product removed successfully'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not find product to remove'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        final success = await SupabaseDataService().deleteProduct(productId);
        if (success) {
          _loadProducts();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product deleted from inventory')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete product. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error removing product: $e')));
      }
    }
  }
}
