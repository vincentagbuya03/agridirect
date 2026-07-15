import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'dart:async';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/commerce/product_service.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/models/cached_product.dart';
import '../../../shared/services/offline/offline_cache_service.dart';
import '../../../shared/services/offline/offline_queue_service.dart';
import '../../../shared/models/offline_product_queue.dart';
import '../../../shared/models/product/crop_milestone_model.dart';
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
  final TextEditingController _searchController = TextEditingController();
  bool _isOnline = true;
  String _selectedTypeFilter = 'All'; // 'All', 'Standard', 'Pre-order'
  String _selectedStockFilter = 'All'; // 'All', 'In Stock', 'Out of Stock'

  bool get _effectiveOnline => _isOnline;
  late OfflineCacheService _cacheService;
  late OfflineQueueService _queueService;
  late OfflineProductService _offlineProductService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Real-time data streams
  late Stream<List<Map<String, dynamic>>> _productsStream;
  late Stream<List<Map<String, dynamic>>> _ordersStream;

  @override
  void initState() {
    super.initState();
    _initializeCacheService();
    _initializeQueueService();
    _initializeOfflineProductService();
    _setupConnectivityListener();
    _initializeStreams();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _initializeStreams() {
    _productsStream = SupabaseDataService().watchFarmerProducts();
    _ordersStream = SupabaseDataService().watchFarmerOrders();
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

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      _,
    ) async {
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
  }

  Future<void> _retryPendingProduct(String productId) async {
    try {
      await _offlineProductService.retryFailedProduct(productId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Queued product synced successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Retry failed: $e')));
      }
    }
  }

  /// Refresh the offline cache by comparing with live server data.
  Future<void> _refreshCacheFromServer() async {
    try {
      final liveProducts = await SupabaseDataService().getFarmerProducts();
      final farmerId = AuthService().userId;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _ordersStream,
        builder: (context, orderSnapshot) {
          final orders = orderSnapshot.data ?? [];
          double totalSales = 0.0;
          for (final order in orders) {
            if (order['status'] == 'DELIVERED') {
              totalSales += (order['rawTotal'] as num?)?.toDouble() ?? 0.0;
            }
          }

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _productsStream,
            builder: (context, productSnapshot) {
              final onlineProducts = productSnapshot.data ?? [];
              final pendingProducts = _getFilteredPendingProducts();
              final activeItemsCount =
                  onlineProducts.length + pendingProducts.length;

              return Column(
                children: [
                  _buildPremiumHeader(totalSales, activeItemsCount),
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
                            return _buildProductsList(
                              onlineProducts,
                              productSnapshot.connectionState ==
                                  ConnectionState.waiting,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push(AppRoutes.addProduct);
          _initializeStreams();
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

  Widget _buildPremiumHeader(double totalSales, int activeItemsCount) {
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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Product Catalog',
                            style: AppTextStyles.headline2.copyWith(
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
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
            ),
            _buildQuickStats(totalSales, activeItemsCount),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(double totalSales, int activeItemsCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildStatCard(
            'Total Sales',
            '₱${totalSales.toStringAsFixed(0)}',
            Icons.payments_outlined,
            const Color(0xFF6366F1),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Active Items',
            '$activeItemsCount Items',
            Icons.inventory_2_outlined,
            AppColors.primary,
          ),
          const SizedBox(width: 12),
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
      width: 165,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: AppTextStyles.headline3.copyWith(
                    color: AppColors.textHeadline,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSubtle,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    final activeFilters = (_selectedTypeFilter != 'All' ? 1 : 0) + (_selectedStockFilter != 'All' ? 1 : 0);
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
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: AppColors.textSubtle,
                            size: 20,
                          ),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showFilterBottomSheet,
            child: Badge(
              isLabelVisible: activeFilters > 0,
              label: Text('$activeFilters'),
              backgroundColor: AppColors.primary,
              child: Container(
                height: 52,
                width: 52,
                decoration: AppDecorations.cardDecoration.copyWith(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: activeFilters > 0 ? AppColors.primary : AppColors.textHeadline,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Inventory',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHeadline,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedTypeFilter = 'All';
                            _selectedStockFilter = 'All';
                          });
                          setState(() {});
                        },
                        child: Text(
                          'Reset',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Product Type',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHeadline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['All', 'Standard', 'Pre-order'].map((type) {
                      final isSelected = _selectedTypeFilter == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(type),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            color: isSelected ? AppColors.primary : AppColors.textSubtle,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _selectedTypeFilter = type);
                              setState(() {});
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Stock Status',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHeadline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['All', 'In Stock', 'Out of Stock'].map((stock) {
                      final isSelected = _selectedStockFilter == stock;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(stock),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            color: isSelected ? AppColors.primary : AppColors.textSubtle,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => _selectedStockFilter = stock);
                              setState(() {});
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Apply Filters',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
      color: _effectiveOnline
          ? Colors.green.withValues(alpha: 0.1)
          : Colors.orange.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(
            _effectiveOnline
                ? Icons.check_circle_outline
                : Icons.cloud_off_rounded,
            size: 16,
            color: _effectiveOnline ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _effectiveOnline
                  ? '${_offlineProductService.pendingProductsCount.value} products waiting to sync'
                  : 'You are currently offline',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _effectiveOnline
                    ? Colors.green[800]
                    : Colors.orange[800],
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

  Widget _buildProductsList(
    List<Map<String, dynamic>> onlineProducts,
    bool isLoading,
  ) {
    final query = _searchController.text.trim().toLowerCase();

    if (!_effectiveOnline) {
      final cachedProducts = _cacheService
          .getAllCachedProducts()
          .where((p) => p.farmerId == AuthService().userId)
          .toList();
      final pendingProducts = _getFilteredPendingProducts();
      final pendingIds = pendingProducts.map((p) => p.id).toSet();
      final pendingAsCached = pendingProducts
          .map(_pendingToCachedProduct)
          .toList();
      final mergedById = <String, CachedProduct>{};
      for (final p in cachedProducts) {
        mergedById[p.id] = p;
      }
      for (final p in pendingAsCached) {
        mergedById[p.id] = p;
      }
      var offlineProducts = mergedById.values.toList();

      if (query.isNotEmpty) {
        offlineProducts = offlineProducts
            .where(
              (p) =>
                  p.name.toLowerCase().contains(query) ||
                  (p.description ?? '').toLowerCase().contains(query),
            )
            .toList();
      }

      // Apply Type Filter
      if (_selectedTypeFilter == 'Standard') {
        offlineProducts = offlineProducts.where((p) => !p.isPreorder).toList();
      } else if (_selectedTypeFilter == 'Pre-order') {
        offlineProducts = offlineProducts.where((p) => p.isPreorder).toList();
      }

      // Apply Stock Filter
      if (_selectedStockFilter == 'In Stock') {
        offlineProducts = offlineProducts.where((p) => (p.availableQuantity ?? 0) > 0).toList();
      } else if (_selectedStockFilter == 'Out of Stock') {
        offlineProducts = offlineProducts.where((p) => (p.availableQuantity ?? 0) <= 0).toList();
      }

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
            products: pendingProducts
                .where((p) => p.syncError != null)
                .toList(),
            onRetryProduct: _retryPendingProduct,
          ),
          if (offlineProducts.isEmpty)
            _buildEmptyState(
              icon: Icons.offline_bolt_rounded,
              title: 'No Cached Products',
              subtitle: query.isNotEmpty
                  ? 'No products match "$query"'
                  : 'Load products while online to view them offline.',
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

    if (isLoading && onlineProducts.isEmpty) {
      return const Center(child: AppShimmerLoader());
    }

    final List<Widget> listItems = [];
    final pendingProducts = _getFilteredPendingProducts();

    var filteredOnline = onlineProducts;
    if (query.isNotEmpty) {
      filteredOnline = onlineProducts.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final desc = (p['description'] ?? '').toString().toLowerCase();
        return name.contains(query) || desc.contains(query);
      }).toList();
    }

    // Apply Type Filter
    if (_selectedTypeFilter == 'Standard') {
      filteredOnline = filteredOnline.where((p) => p['is_preorder'] != true).toList();
    } else if (_selectedTypeFilter == 'Pre-order') {
      filteredOnline = filteredOnline.where((p) => p['is_preorder'] == true).toList();
    }

    // Apply Stock Filter
    if (_selectedStockFilter == 'In Stock') {
      filteredOnline = filteredOnline.where((p) => (p['available'] as num? ?? 0) > 0).toList();
    } else if (_selectedStockFilter == 'Out of Stock') {
      filteredOnline = filteredOnline.where((p) => (p['available'] as num? ?? 0) <= 0).toList();
    }

    if (pendingProducts.isNotEmpty) {
      var filteredPending = pendingProducts;
      if (query.isNotEmpty) {
        filteredPending = filteredPending
            .where(
              (p) =>
                  p.name.toLowerCase().contains(query) ||
                  p.description.toLowerCase().contains(query),
            )
            .toList();
      }

      // Apply Type Filter to pending
      if (_selectedTypeFilter == 'Standard') {
        filteredPending = filteredPending.where((p) => !p.isPreorder).toList();
      } else if (_selectedTypeFilter == 'Pre-order') {
        filteredPending = filteredPending.where((p) => p.isPreorder).toList();
      }

      // Apply Stock Filter to pending
      if (_selectedStockFilter == 'In Stock') {
        filteredPending = filteredPending.where((p) => p.availableQuantity > 0).toList();
      } else if (_selectedStockFilter == 'Out of Stock') {
        filteredPending = filteredPending.where((p) => p.availableQuantity <= 0).toList();
      }

      for (final pending in filteredPending) {
        listItems.add(
          _buildOfflineProductCard(
            _pendingToCachedProduct(pending),
            isPending: true,
          ),
        );
      }
    }

    for (final product in filteredOnline) {
      listItems.add(_buildProductCard(product));
    }

    if (listItems.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        title: query.isNotEmpty ? 'No Results' : 'Empty Inventory',
        subtitle: query.isNotEmpty
            ? 'No products match your search "$query".'
            : 'Start listing your agricultural products to reach customers.',
        buttonLabel: query.isNotEmpty ? null : 'Add Your First Product',
        action: query.isNotEmpty
            ? () {}
            : () async {
                await context.push(AppRoutes.addProduct);
                _initializeStreams();
              },
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _initializeStreams();
        });
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
            products: pendingProducts
                .where((p) => p.syncError != null)
                .toList(),
            onRetryProduct: _retryPendingProduct,
          ),
          ...listItems,
        ],
      ),
    );
  }

  Widget _buildOfflineProductCard(
    CachedProduct product, {
    bool isPending = false,
  }) {
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
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await context.push(AppRoutes.editProduct, extra: product);
              _initializeStreams();
            },
            child: Column(
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: isLocalFile
                          ? Image.file(File(imagePath), fit: BoxFit.cover)
                          : imagePath.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imagePath,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: AppColors.background,
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      color: AppColors.textSubtle,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: AppColors.background,
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: AppColors.textSubtle,
                                      size: 40,
                                    ),
                                  ),
                                ),

                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 3,
                              backgroundColor: statusColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              status,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isOffline)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.cloud_off_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'OFFLINE',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              product['name'] ?? '',
                              style: AppTextStyles.headline3,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '₱${product['price']}/${product['unit'] ?? 'kg'}',
                            style: AppTextStyles.headline3.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product['description'] ?? '',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSubtle,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product['is_preorder'] == true) ...[
                        Builder(
                          builder: (context) {
                            final targetQty = (product['target_quantity'] as num?)?.toDouble() ?? 0.0;
                            final reservedQty = (product['reserved_quantity'] as num?)?.toDouble() ?? 0.0;
                            int daysLeft = 999;
                            final days = int.tryParse(product['harvest_days']?.toString() ?? '') ?? 0;
                            final createdAtStr = product['created_at']?.toString() ?? '';
                            if (createdAtStr.isNotEmpty) {
                              final createdAt = DateTime.tryParse(createdAtStr);
                              if (createdAt != null) {
                                final harvestDate = createdAt.add(Duration(days: days));
                                daysLeft = harvestDate.difference(DateTime.now()).inDays;
                              }
                            }

                            final showUnderreservedAlert = daysLeft <= 5 &&
                                 daysLeft >= 0 &&
                                 targetQty > 0 &&
                                 (reservedQty / targetQty) < 0.5;

                            if (!showUnderreservedAlert) return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Under-reserved Alert: Only ${((reservedQty / targetQty) * 100).toStringAsFixed(0)}% reserved with $daysLeft days remaining!',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.error,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<List<CropMilestone>>(
                          future: ProductService().getCropMilestones(product['id'] ?? product['product_id'] ?? ''),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final milestones = snapshot.data!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                Text(
                                  'Posted Milestones (${milestones.length})',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSubtle,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 80,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: milestones.length,
                                    separatorBuilder: (c, idx) => const SizedBox(width: 10),
                                    itemBuilder: (c, mIdx) {
                                      final milestone = milestones[mIdx];
                                      return Container(
                                        width: 200,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          children: [
                                            if (milestone.imageUrl != null && milestone.imageUrl!.isNotEmpty) ...[
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(6),
                                                child: Image.network(
                                                  milestone.imageUrl!,
                                                  width: 40,
                                                  height: 40,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (c, o, s) => Container(
                                                    width: 40,
                                                    height: 40,
                                                    color: const Color(0xFFE2E8F0),
                                                    child: const Icon(Icons.broken_image, size: 16, color: AppColors.textSubtle),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    milestone.title,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    milestone.description,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.textSubtle),
                                                  ),
                                                ],
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
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildDetailChip(
                                Icons.inventory_2_outlined,
                                '${product['available'] ?? 0} ${product['unit'] ?? 'kg'}',
                              ),
                              const SizedBox(width: 12),
                              _buildDetailChip(
                                Icons.calendar_month_outlined,
                                product['harvest'] ?? 'Ready Now',
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (product['is_preorder'] == true) ...[
                                TextButton(
                                  onPressed: () {
                                    _showPostUpdateDialog(
                                      product['id'] ?? '',
                                      product['name'] ?? 'Product',
                                    );
                                  },
                                  child: Text(
                                    'Post Update',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              TextButton(
                                onPressed: () async {
                                  await context.push(AppRoutes.editProduct, extra: product);
                                  _initializeStreams();
                                },
                                child: Text(
                                  'Manage',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPostUpdateDialog(String productId, String cropName) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final imgController = TextEditingController();
    bool isPosting = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Post Growth Update for $cropName',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Milestone Title (e.g., Sprouting 🌱)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Update Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: imgController,
                decoration: const InputDecoration(
                  labelText: 'Progress Photo URL (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isPosting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isPosting
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty ||
                          descController.text.trim().isEmpty) {
                        return;
                      }
                      setDialogState(() => isPosting = true);
                      try {
                        await ProductService().addCropMilestone(
                          productId: productId,
                          title: titleController.text.trim(),
                          description: descController.text.trim(),
                          imageUrl: imgController.text.trim().isNotEmpty
                              ? imgController.text.trim()
                              : null,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _initializeStreams();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Growth milestone posted successfully!')),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      } finally {
                        setDialogState(() => isPosting = false);
                      }
                    },
              child: Text(isPosting ? 'Posting...' : 'Post Update'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSubtle),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSubtle,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? buttonLabel,
    VoidCallback? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(title, style: AppTextStyles.headline2),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSubtle,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (buttonLabel != null && action != null)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: action,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    buttonLabel,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
