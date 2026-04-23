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
import '../../widgets/offline_sync_widget.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/offline/offline_product_service.dart';
import '../../../shared/services/offline/network_status_service.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool _isManualOffline = false;

  bool get _effectiveOnline => _isOnline && !_isManualOffline;
  late OfflineCacheService _cacheService;
  late OfflineQueueService _queueService;
  late OfflineProductService _offlineProductService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initializeCacheService();
    _initializeQueueService();
    _initializeOfflineProductService();
    _setupConnectivityListener();
    _loadProducts();
  }

  void _initializeOfflineProductService() {
    _offlineProductService = OfflineProductService(
      queueService: _queueService,
      connectivity: Connectivity(),
    );
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
    _refreshConnectivityStatus();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((_) async {
      final wasOffline = !_isOnline;
      final isOnline = await NetworkStatusService().isOnline();
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
        // When transitioning from offline → online, refresh cache to purge deleted products
        if (wasOffline && isOnline) {
          _refreshCacheFromServer();
        }
      }
    });
  }

  Future<void> _refreshConnectivityStatus() async {
    final isOnline = await NetworkStatusService().isOnline();
    if (mounted) {
      setState(() => _isOnline = isOnline);
    }
  }

  Future<void> _retryAllPendingProducts() async {
    await _offlineProductService.syncPendingProducts();
    if (mounted) {
      _loadProducts();
    }
  }

  Future<void> _retryPendingProduct(String productId) async {
    try {
      await _offlineProductService.retryFailedProduct(productId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Queued product synced successfully')),
        );
        _loadProducts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Retry failed: $e')),
        );
      }
    }
  }

  /// Refresh the offline cache by comparing with live server data.
  /// Removes any cached products that no longer exist on the server.
  Future<void> _refreshCacheFromServer() async {
    try {
      debugPrint('[FarmerProducts] 🔄 Refreshing cache after reconnect...');
      final liveProducts = await SupabaseDataService().getFarmerProducts();
      final liveIds = liveProducts
          .map((p) => p['id']?.toString())
          .whereType<String>()
          .toSet();

      // Get all cached products belonging to this farmer
      final farmerId = AuthService().userId;
      final cachedProducts = _cacheService.getAllCachedProducts();
      final farmerCached = cachedProducts
          .where((p) => p.farmerId == farmerId)
          .toList();

      int removed = 0;
      for (final cached in farmerCached) {
        // Skip pending-sync products (they don't exist on server yet)
        final isPendingInQueue = _queueService.getPendingProducts().any(
          (q) => q.id == cached.id,
        );
        if (isPendingInQueue) continue;

        if (!liveIds.contains(cached.id)) {
          await _cacheService.removeCachedProduct(cached.id);
          removed++;
        }
      }

      if (removed > 0) {
        debugPrint(
          '[FarmerProducts] 🧹 Purged $removed stale products from cache',
        );
      }

      // Re-cache the fresh live products
      for (final product in liveProducts) {
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
          farmerId: farmerId,
          name: product['name'] as String? ?? 'Unknown',
          price: double.tryParse(product['price']?.toString() ?? '0') ?? 0.0,
          description: product['description'] as String?,
          imageUrl: product['image'] as String?,
          availableQuantity:
              (product['available_quantity'] as num?)?.toInt() ?? availableQty,
          isPreorder: product['is_preorder'] as bool? ?? false,
          harvestDays: harvestDays,
        );
        _cacheService.autoCacheProduct(cachedProduct);
      }

      // Reload the UI
      _loadProducts();
      debugPrint('[FarmerProducts] ✅ Cache refresh complete');
    } catch (e) {
      debugPrint('[FarmerProducts] ⚠️ Cache refresh failed: $e');
    }
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
          _buildStatusBanner(),
          _buildSearchAndFilter(),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box<OfflineProductQueue>(
                OfflineQueueService.boxName,
              ).listenable(),
              builder: (context, queueBox, _) {
                return ValueListenableBuilder(
                  valueListenable: Hive.box<CachedProduct>(
                    'cached_products',
                  ).listenable(),
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
            color: AppColors.textHeadline.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
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
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.headline2.copyWith(fontSize: 24),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Manual sync button removed for auto-sync experience

                      if (_offlineProductService.pendingProductsCount.value >
                              0 &&
                          _effectiveOnline)
                        const SizedBox(width: 8),
                      _buildConnectivityToggle(),
                      const SizedBox(width: 8),
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
            _buildQuickStats(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildStatCard(
            'Total Sales',
            '₱24,500',
            Icons.payments_outlined,
            const Color(0xFF6366F1),
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Active',
            '12 Items',
            Icons.inventory_2_outlined,
            AppColors.primary,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Sync Status',
            _offlineProductService.pendingProductsCount.value == 0
                ? 'All Synced'
                : '${_offlineProductService.pendingProductsCount.value} Pending',
            Icons.cloud_sync_outlined,
            _offlineProductService.pendingProductsCount.value == 0
                ? AppColors.success
                : Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: AppTextStyles.headline3.copyWith(
              color: AppColors.textHeadline,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSubtle,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildConnectivityToggle() {
    final statusColor = _effectiveOnline ? Colors.green : Colors.orange;
    final statusLabel = _isManualOffline
        ? 'OFFLINE'
        : (_isOnline ? 'ONLINE' : 'OFFLINE');

    return GestureDetector(
      onTap: () {
        setState(() {
          _isManualOffline = !_isManualOffline;
          if (!_isManualOffline && _isOnline) {
            _refreshCacheFromServer();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isManualOffline
                  ? 'Switched to Offline Mode'
                  : 'Back to Online Mode',
            ),
            backgroundColor: statusColor,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 4, backgroundColor: statusColor),
            const SizedBox(width: 8),
            Text(
              statusLabel,
              style: AppTextStyles.labelSmall.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
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

  Widget _buildStatusBanner() {
    if (_effectiveOnline &&
        _offlineProductService.pendingProductsCount.value == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _isManualOffline
          ? Colors.orange.withValues(alpha: 0.1)
          : (_effectiveOnline
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1)),
      child: Row(
        children: [
          Icon(
            _isManualOffline
                ? Icons.wifi_off_rounded
                : (_effectiveOnline
                      ? Icons.check_circle_outline
                      : Icons.cloud_off_rounded),
            size: 16,
            color: _isManualOffline
                ? Colors.orange
                : (_effectiveOnline ? Colors.green : Colors.orange),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isManualOffline
                  ? 'Manual Offline Mode active'
                  : (_effectiveOnline
                        ? '${_offlineProductService.pendingProductsCount.value} products waiting to sync'
                        : 'You are currently offline'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _isManualOffline
                    ? Colors.orange[800]
                    : (_effectiveOnline
                          ? Colors.green[800]
                          : Colors.orange[800]),
              ),
            ),
          ),
          if (_effectiveOnline &&
              _offlineProductService.pendingProductsCount.value > 0)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),

        ],
      ),
    );
  }


  Widget _buildProductsList() {
    if (!_effectiveOnline) {
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
          OfflineSyncStatusWidget(
            pendingProductCount: pendingProducts.length,
            isSyncing: _offlineProductService.isSyncing.value,
            isOnline: _effectiveOnline,
            onRetry: _retryAllPendingProducts,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: OfflineModeIndicator(cacheService: _cacheService),
          ),
          PendingProductsListWidget(
            products: pendingProducts.where((p) => p.syncError != null).toList(),
            onRetryProduct: _retryPendingProduct,
          ),
          if (offlineProducts.isEmpty)
            _buildEmptyState(
              icon: Icons.offline_bolt_rounded,
              title: 'No Cached Products',
              subtitle: 'Load products while online to view them offline.',
              action: () {},
            )
          else
            ...offlineProducts.map(
              (p) => _buildOfflineProductCard(
                p,
                isPending: pendingIds.contains(p.id),
              ),
            ),
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
              _buildOfflineProductCard(
                _pendingToCachedProduct(pending),
                isPending: true,
              ),
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
            children: [
              OfflineSyncStatusWidget(
                pendingProductCount: pendingProducts.length,
                isSyncing: _offlineProductService.isSyncing.value,
                isOnline: _effectiveOnline,
                onRetry: _retryAllPendingProducts,
              ),
              PendingProductsListWidget(
                products: pendingProducts.where((p) => p.syncError != null).toList(),
                onRetryProduct: _retryPendingProduct,
              ),
              ...listItems,
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfflineProductCard(
    CachedProduct product, {
    bool isPending = false,
  }) {
    // Check if there's a sync error for this product
    final queueItem = isPending
        ? _queueService.getAllProducts().firstWhere((p) => p.id == product.id)
        : null;
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
      'status': syncError != null
          ? 'SYNC ERROR'
          : (isPending ? 'PENDING SYNC' : 'LIVE (OFFLINE)'),
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
                color: Colors.orange.withValues(alpha: 0.1),
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              status,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (!isOffline)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.verified_user_rounded,
                                    size: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'PROVENANCE VERIFIED',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        product['name'] ?? 'Product Name',
                        style: AppTextStyles.headline3.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₱${(product['price'] ?? 0).toStringAsFixed(0)}',
                            style: AppTextStyles.headline2.copyWith(
                              color: AppColors.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            ' / ${product['unit'] ?? 'kg'}',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSubtle,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Stock Level',
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSubtle,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${product['available'] ?? 0} left',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value:
                                  ((product['available'] as num?)?.toDouble() ??
                                      0) /
                                  100,
                              backgroundColor: AppColors.background,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                statusColor,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
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
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.textHeadline.withValues(alpha: 0.1),
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
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isDestructive
                        ? AppColors.error
                        : AppColors.textHeadline,
                    fontWeight: FontWeight.w700,
                  ),
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
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.3),
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
          // Also remove from the offline cache so it doesn't reappear offline
          await _cacheService.removeCachedProduct(productId);
          debugPrint(
            '🧹 Removed deleted product $productId from offline cache',
          );
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
