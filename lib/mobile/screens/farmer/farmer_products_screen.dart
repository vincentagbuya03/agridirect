import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/models/cached_product.dart';
import '../../../shared/models/offline_product_queue.dart';
import '../../../shared/models/product/crop_milestone_model.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/commerce/product_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/offline/network_status_service.dart';
import '../../../shared/services/offline/offline_cache_service.dart';
import '../../../shared/services/offline/offline_product_service.dart';
import '../../../shared/services/offline/offline_queue_service.dart';
import '../../../shared/styles/app_theme.dart';
import '../../widgets/offline_browse_widget.dart';
import '../../widgets/offline_sync_widget.dart';

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
      backgroundColor: const Color(0xFFF8FAFC),
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
                  _buildCompactHeader(totalSales, activeItemsCount),
                  _buildStatusBanner(),
                  _buildSearchAndFilters(),
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
        backgroundColor: const Color(0xFF059669),
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'LIST PRODUCT',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ─── Compact Slim Header (Replaces the 25% screen space header) ───
  Widget _buildCompactHeader(double totalSales, int activeItemsCount) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'MY INVENTORY',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF059669),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Product Catalog',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Compact Metric Pills
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 12,
                      color: Color(0xFF4F46E5),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '₱${totalSales.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 12,
                      color: Color(0xFF059669),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$activeItemsCount Items',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF059669),
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
  }

  // ─── Search & Quick Filter Chips ───
  Widget _buildSearchAndFilters() {
    final activeFilterCount =
        (_selectedTypeFilter != 'All' ? 1 : 0) +
        (_selectedStockFilter != 'All' ? 1 : 0);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search products or crop name...',
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF94A3B8),
                                size: 18,
                              ),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _showFilterBottomSheet,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: activeFilterCount > 0
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: activeFilterCount > 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        color: activeFilterCount > 0
                            ? const Color(0xFF059669)
                            : const Color(0xFF64748B),
                        size: 20,
                      ),
                      if (activeFilterCount > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF059669),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Quick filter chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildQuickFilterChip(
                  label: 'All Produce',
                  isSelected:
                      _selectedTypeFilter == 'All' &&
                      _selectedStockFilter == 'All',
                  onTap: () {
                    setState(() {
                      _selectedTypeFilter = 'All';
                      _selectedStockFilter = 'All';
                    });
                  },
                ),
                const SizedBox(width: 6),
                _buildQuickFilterChip(
                  label: '🌱 Pre-orders',
                  isSelected: _selectedTypeFilter == 'Pre-order',
                  onTap: () {
                    setState(() {
                      _selectedTypeFilter =
                          _selectedTypeFilter == 'Pre-order'
                              ? 'All'
                              : 'Pre-order';
                    });
                  },
                ),
                const SizedBox(width: 6),
                _buildQuickFilterChip(
                  label: '📦 Standard Stock',
                  isSelected: _selectedTypeFilter == 'Standard',
                  onTap: () {
                    setState(() {
                      _selectedTypeFilter =
                          _selectedTypeFilter == 'Standard'
                              ? 'All'
                              : 'Standard';
                    });
                  },
                ),
                const SizedBox(width: 6),
                _buildQuickFilterChip(
                  label: '✅ In Stock',
                  isSelected: _selectedStockFilter == 'In Stock',
                  onTap: () {
                    setState(() {
                      _selectedStockFilter =
                          _selectedStockFilter == 'In Stock'
                              ? 'All'
                              : 'In Stock';
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFECFDF5)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF059669)
                : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Catalog',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
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
                          style: GoogleFonts.inter(
                            color: const Color(0xFF059669),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Listing Type',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
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
                          selectedColor: const Color(0xFFECFDF5),
                          labelStyle: GoogleFonts.inter(
                            color: isSelected
                                ? const Color(0xFF059669)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
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
                  const SizedBox(height: 14),
                  Text(
                    'Stock Status',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
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
                          selectedColor: const Color(0xFFECFDF5),
                          labelStyle: GoogleFonts.inter(
                            color: isSelected
                                ? const Color(0xFF059669)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Apply Filters',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
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

      if (_selectedTypeFilter == 'Standard') {
        offlineProducts = offlineProducts.where((p) => !p.isPreorder).toList();
      } else if (_selectedTypeFilter == 'Pre-order') {
        offlineProducts = offlineProducts.where((p) => p.isPreorder).toList();
      }

      if (_selectedStockFilter == 'In Stock') {
        offlineProducts = offlineProducts
            .where((p) => (p.availableQuantity ?? 0) > 0)
            .toList();
      } else if (_selectedStockFilter == 'Out of Stock') {
        offlineProducts = offlineProducts
            .where((p) => (p.availableQuantity ?? 0) <= 0)
            .toList();
      }

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        physics: const BouncingScrollPhysics(),
        children: [
          OfflineSyncStatusWidget(
            pendingProductCount: pendingProducts.length,
            isSyncing: _offlineProductService.isSyncing.value,
            isOnline: _effectiveOnline,
            onRetry: _retryAllPendingProducts,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
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

    if (_selectedTypeFilter == 'Standard') {
      filteredOnline =
          filteredOnline.where((p) => p['is_preorder'] != true).toList();
    } else if (_selectedTypeFilter == 'Pre-order') {
      filteredOnline =
          filteredOnline.where((p) => p['is_preorder'] == true).toList();
    }

    if (_selectedStockFilter == 'In Stock') {
      filteredOnline =
          filteredOnline
              .where((p) => (p['available'] as num? ?? 0) > 0)
              .toList();
    } else if (_selectedStockFilter == 'Out of Stock') {
      filteredOnline =
          filteredOnline
              .where((p) => (p['available'] as num? ?? 0) <= 0)
              .toList();
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

      if (_selectedTypeFilter == 'Standard') {
        filteredPending =
            filteredPending.where((p) => !p.isPreorder).toList();
      } else if (_selectedTypeFilter == 'Pre-order') {
        filteredPending =
            filteredPending.where((p) => p.isPreorder).toList();
      }

      if (_selectedStockFilter == 'In Stock') {
        filteredPending =
            filteredPending.where((p) => p.availableQuantity > 0).toList();
      } else if (_selectedStockFilter == 'Out of Stock') {
        filteredPending =
            filteredPending.where((p) => p.availableQuantity <= 0).toList();
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
        title: query.isNotEmpty ? 'No Results Found' : 'Empty Inventory',
        subtitle: query.isNotEmpty
            ? 'No products match your search "$query".'
            : 'Start listing your agricultural products to reach buyers.',
        buttonLabel: query.isNotEmpty ? null : 'Add Your First Product',
        action: query.isNotEmpty
            ? null
            : () async {
                await context.push(AppRoutes.addProduct);
                _initializeStreams();
              },
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF059669),
      onRefresh: () async {
        setState(() {
          _initializeStreams();
        });
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
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

  // ─── Compact & Modern Product Card ───
  Widget _buildProductCard(Map<String, dynamic> product) {
    final isPreorder = product['is_preorder'] == true;
    final status = product['status']?.toString().toUpperCase() ??
        (isPreorder ? 'PRE-ORDER' : 'IN STOCK');

    Color statusColor;
    Color statusBg;
    switch (status) {
      case 'SOLD OUT':
        statusColor = const Color(0xFFEF4444);
        statusBg = const Color(0xFFFEF2F2);
        break;
      case 'LOW STOCK':
        statusColor = const Color(0xFFF59E0B);
        statusBg = const Color(0xFFFFFBEB);
        break;
      case 'PENDING SYNC':
        statusColor = const Color(0xFFF97316);
        statusBg = const Color(0xFFFFF7ED);
        break;
      case 'PRE-ORDER':
        statusColor = const Color(0xFF0284C7);
        statusBg = const Color(0xFFF0F9FF);
        break;
      default:
        statusColor = const Color(0xFF059669);
        statusBg = const Color(0xFFECFDF5);
    }

    final isOffline = product['is_offline'] == true;
    final imagePath = (product['image']?.toString() ?? '').trim();
    final isLocalFile =
        imagePath.startsWith('/') ||
        imagePath.startsWith('file://') ||
        imagePath.contains(':\\');
    final productId = (product['id'] ?? product['product_id'] ?? '').toString();
    final name = product['name']?.toString() ?? 'Product';
    final price = product['price']?.toString() ?? '0';
    final unit = product['unit']?.toString() ?? 'kg';
    final desc = product['description']?.toString() ?? '';
    final available = product['available'] ?? 0;
    final harvest = product['harvest']?.toString() ??
        (isPreorder ? 'Pre-order' : 'Ready Now');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await context.push(AppRoutes.editProduct, extra: product);
            _initializeStreams();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Thumbnail (84x84)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 84,
                        height: 84,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            isLocalFile
                                ? Image.file(File(imagePath), fit: BoxFit.cover)
                                : imagePath.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: imagePath,
                                        fit: BoxFit.cover,
                                        placeholder: (_, _) => Container(
                                          color: const Color(0xFFF1F5F9),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFF059669),
                                              ),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (_, _, _) => Container(
                                          color: const Color(0xFFF1F5F9),
                                          child: const Icon(
                                            Icons.agriculture_rounded,
                                            color: Color(0xFF94A3B8),
                                            size: 30,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: const Color(0xFFF1F5F9),
                                        child: const Icon(
                                          Icons.agriculture_rounded,
                                          color: Color(0xFF94A3B8),
                                          size: 30,
                                        ),
                                      ),
                            if (isOffline)
                              Positioned(
                                bottom: 4,
                                left: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'OFFLINE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Product Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  status,
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₱$price/$unit',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669),
                            ),
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 6),
                          // Compact Chips Row
                          Row(
                            children: [
                              _buildMiniChip(
                                Icons.inventory_2_outlined,
                                '$available $unit',
                              ),
                              const SizedBox(width: 6),
                              _buildMiniChip(
                                isPreorder
                                    ? Icons.grass_rounded
                                    : Icons.calendar_today_rounded,
                                harvest,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Pre-order Milestone Badges & Under-reserved Warning
                if (isPreorder && productId.isNotEmpty) ...[
                  _buildPreorderUnderreservedWarning(product),
                  const SizedBox(height: 8),
                  FutureBuilder<List<CropMilestone>>(
                    future: ProductService().getCropMilestones(productId),
                    builder: (context, snapshot) {
                      final milestones = snapshot.data ?? [];
                      if (milestones.isEmpty) return const SizedBox.shrink();

                      return InkWell(
                        onTap: () => _showMilestonesBottomSheet(name, milestones),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 13,
                                color: Color(0xFF059669),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${milestones.length} Growth Updates Posted',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 14,
                                color: Color(0xFF059669),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),

                // Bottom Action Buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (isPreorder)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.grass_rounded,
                              size: 12,
                              color: Color(0xFF0284C7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Pre-order Item',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPreorder && productId.isNotEmpty) ...[
                          InkWell(
                            onTap: () => _showPostUpdateBottomSheet(productId, name),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 12,
                                    color: Color(0xFF059669),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Post Update',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        InkWell(
                          onTap: () async {
                            await context.push(
                              AppRoutes.editProduct,
                              extra: product,
                            );
                            _initializeStreams();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.edit_outlined,
                                  size: 12,
                                  color: Color(0xFF475569),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Manage',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }

  Widget _buildMiniChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF475569),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreorderUnderreservedWarning(Map<String, dynamic> product) {
    final targetQty =
        (product['target_quantity'] as num?)?.toDouble() ?? 0.0;
    final reservedQty =
        (product['reserved_quantity'] as num?)?.toDouble() ?? 0.0;
    int daysLeft = 999;
    final days =
        int.tryParse(product['harvest_days']?.toString() ?? '') ?? 0;
    final createdAtStr = product['created_at']?.toString() ?? '';
    if (createdAtStr.isNotEmpty) {
      final createdAt = DateTime.tryParse(createdAtStr);
      if (createdAt != null) {
        final harvestDate = createdAt.add(Duration(days: days));
        daysLeft = harvestDate.difference(DateTime.now()).inDays;
      }
    }

    final showUnderreservedAlert =
        daysLeft <= 5 &&
        daysLeft >= 0 &&
        targetQty > 0 &&
        (reservedQty / targetQty) < 0.5;

    if (!showUnderreservedAlert) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFDC2626),
            size: 15,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Under-reserved: Only ${((reservedQty / targetQty) * 100).toStringAsFixed(0)}% reserved with $daysLeft days left!',
              style: GoogleFonts.inter(
                color: const Color(0xFFDC2626),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Beautiful Pre-order Post Update Bottom Sheet ───
  Future<void> _showPostUpdateBottomSheet(
    String productId,
    String cropName,
  ) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    XFile? pickedImage;
    bool isPosting = false;
    bool notifyBuyers = true;

    final presetStages = [
      {'emoji': '🌱', 'title': 'Sprouting', 'desc': 'Seeds have sprouted healthy green shoots!'},
      {'emoji': '🌿', 'title': 'Vegetative Growth', 'desc': 'Plants are growing vigorously with abundant leaves.'},
      {'emoji': '🌸', 'title': 'Flowering & Fruiting', 'desc': 'Flowers are blooming and produce is developing nicely.'},
      {'emoji': '🌾', 'title': 'Almost Ready', 'desc': 'Produce is reaching full maturity and ripening soon.'},
      {'emoji': '🚜', 'title': 'Ready to Harvest', 'desc': 'Harvest has started! Produce is fresh and ready for pickup/delivery.'},
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Color(0xFF059669),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Post Growth Update',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              cropName,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: const Color(0xFF059669),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                        onPressed: () => Navigator.pop(modalContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Quick Stage Presets
                  Text(
                    'QUICK STAGE PRESET',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: presetStages.map((stage) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            avatar: Text(stage['emoji']!),
                            label: Text(stage['title']!),
                            backgroundColor: const Color(0xFFF1F5F9),
                            labelStyle: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334155),
                            ),
                            onPressed: () {
                              setModalState(() {
                                titleController.text = '${stage['emoji']} ${stage['title']}';
                                descController.text = stage['desc']!;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title Field
                  Text(
                    'Milestone Title',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'e.g. 🌱 Week 2 Sprouting or Flowering',
                      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description Field
                  Text(
                    'Update Description',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Describe crop health, expected harvest dates, or weather conditions...',
                      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Photo Upload Section
                  Text(
                    'Progress Photo',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (pickedImage != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            File(pickedImage!.path),
                            height: 130,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() {
                                pickedImage = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
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
                            onPressed: () async {
                              final image = await ImagePicker().pickImage(
                                source: ImageSource.camera,
                                imageQuality: 85,
                              );
                              if (image != null) {
                                setModalState(() => pickedImage = image);
                              }
                            },
                            icon: const Icon(Icons.camera_alt_outlined, size: 18),
                            label: const Text('Camera'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF059669),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final image = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 85,
                              );
                              if (image != null) {
                                setModalState(() => pickedImage = image);
                              }
                            },
                            icon: const Icon(Icons.photo_library_outlined, size: 18),
                            label: const Text('Gallery'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),
                  // Notify Buyers Switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          color: Color(0xFF059669),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notify Pre-order Buyers',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Send push & in-app alerts with this update',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: notifyBuyers,
                          activeThumbColor: const Color(0xFF059669),
                          onChanged: (val) => setModalState(() => notifyBuyers = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  // Post Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isPosting
                          ? null
                          : () async {
                              final title = titleController.text.trim();
                              final desc = descController.text.trim();
                              if (title.isEmpty || desc.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter a title and description'),
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isPosting = true);
                              try {
                                String? uploadedUrl;
                                if (pickedImage != null) {
                                  final bytes = await pickedImage!.readAsBytes();
                                  final fileName =
                                      'milestone_${DateTime.now().millisecondsSinceEpoch}_${pickedImage!.name}';
                                  final path = 'milestones/$fileName';
                                  final client = SupabaseConfig.client;
                                  await client.storage
                                      .from('uploads')
                                      .uploadBinary(path, bytes);
                                  uploadedUrl = client.storage
                                      .from('uploads')
                                      .getPublicUrl(path);
                                }

                                await ProductService().addCropMilestone(
                                  productId: productId,
                                  title: title,
                                  description: desc,
                                  imageUrl: uploadedUrl,
                                );

                                if (!modalContext.mounted) return;
                                Navigator.pop(modalContext);
                                _initializeStreams();

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Color(0xFF059669),
                                      content: Text('🌱 Growth update posted successfully!'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (modalContext.mounted) {
                                  ScaffoldMessenger.of(modalContext).showSnackBar(
                                    SnackBar(content: Text('Failed to post update: $e')),
                                  );
                                }
                              } finally {
                                if (modalContext.mounted) {
                                  setModalState(() => isPosting = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: isPosting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Post Growth Update',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
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

  // ─── Milestones Timeline BottomSheet ───
  void _showMilestonesBottomSheet(
    String cropName,
    List<CropMilestone> milestones,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.grass_rounded,
                          color: Color(0xFF059669),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Growth Updates History',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              cropName,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: const Color(0xFF059669),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: milestones.length,
                      separatorBuilder: (c, idx) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final m = milestones[idx];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (m.imageUrl != null && m.imageUrl!.isNotEmpty) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: m.imageUrl!,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => Container(
                                      width: 64,
                                      height: 64,
                                      color: const Color(0xFFE2E8F0),
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 20,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      m.description,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                        height: 1.4,
                                      ),
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
              ),
            );
          },
        );
      },
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
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: const Color(0xFF059669)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (buttonLabel != null && action != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: action,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  elevation: 0,
                ),
                child: Text(
                  buttonLabel,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
