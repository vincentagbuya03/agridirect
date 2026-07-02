import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/models/cached_product.dart';
import '../../../shared/services/offline/offline_cache_service.dart';
import '../../../shared/services/offline/network_status_service.dart';
import '../../widgets/offline_browse_widget.dart';
import '../../widgets/skeleton_loaders.dart';
import '../../../shared/services/auth/auth_service.dart';

/// Pre-Order Hub - Premium Reservation Interface
class PreOrderHubScreen extends StatefulWidget {
  const PreOrderHubScreen({super.key});

  @override
  State<PreOrderHubScreen> createState() => _PreOrderHubScreenState();
}

class _PreOrderHubScreenState extends State<PreOrderHubScreen> {
  int _selectedFilter = 0;
  List<String> _filters = ['All Crops'];
  final _searchController = TextEditingController();
  late Future<List<ProductItem>> _preOrdersFuture;
  bool _isOnline = true;
  late OfflineCacheService _cacheService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initializeCacheService();
    _setupConnectivityListener();
    _preOrdersFuture = _loadPreOrders();
  }

  void _initializeCacheService() {
    _cacheService = OfflineCacheService();
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
          if (wasOffline && isOnline) {
            _preOrdersFuture = _loadPreOrders();
          }
        });
      }
    });
  }

  Future<void> _refreshConnectivityStatus() async {
    final isOnline = await NetworkStatusService().isOnline();
    if (mounted) {
      setState(() => _isOnline = isOnline);
    }
  }

  Future<List<ProductItem>> _loadPreOrders() async {
    final products = await SupabaseDataService().getPreOrderProducts();
    final categories =
        products
            .map((p) => p.categoryName?.trim())
            .where((category) => category != null && category.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (mounted) {
      setState(() {
        _filters = ['All Crops', ...categories];
        if (_selectedFilter >= _filters.length) {
          _selectedFilter = 0;
        }
      });
    }

    return _sortPreOrders(products);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildPremiumHeader(),
          _buildSleekFilterChips(),
          Expanded(child: _buildPreOrderList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSavedSeedsInfo,
        backgroundColor: AppColors.textHeadline,
        elevation: 12,
        icon: const Icon(
          Icons.bookmark_outline_rounded,
          color: Colors.white,
          size: 20,
        ),
        label: Text(
          'SAVED SEEDS',
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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.hub_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Pre-Order Hub',
                        style: AppTextStyles.headline1.copyWith(fontSize: 22),
                      ),
                    ],
                  ),
                  _buildLocationBadge(),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.textHeadline.withValues(alpha: 0.05),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search upcoming harvests...',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSubtle,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSubtle,
                            size: 22,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.textHeadline.withValues(alpha: 0.05),
                      ),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.textHeadline,
                      size: 22,
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

  Widget _buildLocationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_rounded,
            color: AppColors.primary,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            'San Carlos',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleekFilterChips() {
    return Container(
      height: 64,
      padding: const EdgeInsets.only(top: 16),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final isSelected = _selectedFilter == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.textHeadline : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.textHeadline
                      : AppColors.textHeadline.withValues(alpha: 0.05),
                ),
              ),
              child: Text(
                _filters[i],
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppColors.textSubtle,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreOrderList() {
    if (!_isOnline) {
      // Offline mode with cached preorder products
      final currentUserId = AuthService().userId;
      final cachedPreorders = _cacheService
          .getAllCachedProducts()
          .where((p) => p.isPreorder)
          .map(_cachedToProductItem)
          .where((p) {
            final isNotMine = currentUserId.isEmpty || p.farmerId != currentUserId;
            return _matchesCurrentFilters(p) && isNotMine;
          })
          .toList();

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: OfflineModeIndicator(cacheService: _cacheService),
          ),
          Expanded(
            child: cachedPreorders.isEmpty
                ? _buildEmptyState(isOffline: true)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                    physics: const BouncingScrollPhysics(),
                    itemCount: cachedPreorders.length + 1,
                    separatorBuilder: (_, i) => const SizedBox(height: 24),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return _buildPreOrderSectionHeader(
                          cachedPreorders.length,
                        );
                      }
                      return _buildPremiumPreOrderCard(cachedPreorders[i - 1]);
                    },
                  ),
          ),
        ],
      );
    }

    return FutureBuilder<List<ProductItem>>(
      future: _preOrdersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            child: PreOrderListSkeleton(itemCount: 5, enabled: true),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final currentUserId = AuthService().userId;
        final preOrders = (snapshot.data ?? [])
            .where((p) {
              final isNotMine = currentUserId.isEmpty || p.farmerId != currentUserId;
              return _matchesCurrentFilters(p) && isNotMine;
            })
            .toList();

        // Auto-cache preorder products
        final allPreOrders = snapshot.data ?? [];
        if (allPreOrders.isNotEmpty) {
          for (final product in allPreOrders) {
            final cachedProduct = CachedProduct(
              id: product.productId ?? 'unknown_${product.name}',
              farmerId: product.farmerId ?? '',
              name: product.name,
              price: _parsePrice(product.price),
              description: product.description,
              imageUrl: product.imageUrl,
              category: product.categoryName,
              unit: product.unit,
              isPreorder: true,
              harvestDays: int.tryParse(product.harvestDays ?? '0') ?? 0,
              farmName: product.farm,
              rating: double.tryParse(product.rating ?? '0') ?? 0.0,
              farmerAvatarUrl: product.farmerAvatarUrl,
            );
            _cacheService.autoCacheProduct(cachedProduct);
          }
        }

        if (preOrders.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: _refreshPreOrders,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: preOrders.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 24),
            itemBuilder: (_, i) {
              if (i == 0) return _buildPreOrderSectionHeader(preOrders.length);
              return _buildPremiumPreOrderCard(preOrders[i - 1]);
            },
          ),
        );
      },
    );
  }

  Future<void> _refreshPreOrders() async {
    setState(() {
      _preOrdersFuture = _loadPreOrders();
    });
    await _preOrdersFuture;
  }

  List<ProductItem> _sortPreOrders(List<ProductItem> products) {
    final sorted = [...products];
    sorted.sort((a, b) {
      final aDays = int.tryParse(a.harvestDays ?? '') ?? 9999;
      final bDays = int.tryParse(b.harvestDays ?? '') ?? 9999;
      return aDays.compareTo(bDays);
    });
    return sorted;
  }

  bool _matchesCurrentFilters(ProductItem product) {
    final query = _searchController.text.trim().toLowerCase();
    final matchesSearch =
        query.isEmpty ||
        product.name.toLowerCase().contains(query) ||
        product.farm.toLowerCase().contains(query) ||
        (product.categoryName ?? '').toLowerCase().contains(query);

    if (!matchesSearch) return false;

    if (_selectedFilter == 0 || _selectedFilter >= _filters.length) {
      return true;
    }

    final selectedCategory = _filters[_selectedFilter].trim().toLowerCase();
    final productCategory = (product.categoryName ?? '').trim().toLowerCase();
    return productCategory.isNotEmpty && productCategory == selectedCategory;
  }

  double _parsePrice(String rawPrice) {
    final normalized = rawPrice.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(normalized) ?? 0.0;
  }

  ProductItem _cachedToProductItem(CachedProduct product) {
    final normalizedUnit = (product.unit ?? '').trim();

    return ProductItem(
      productId: product.id,
      farmerId: product.farmerId,
      farmerName: product.farmName,
      farmerAvatarUrl: product.farmerAvatarUrl,
      name: product.name,
      farm: product.farmName ?? 'Farm',
      price: '₱${product.price.toStringAsFixed(2)}',
      unit: normalizedUnit.isEmpty ? 'kg' : normalizedUnit,
      imageUrl: product.imageUrl ?? '',
      categoryName: product.category,
      rating: (product.rating ?? 0).toStringAsFixed(1),
      reviews: '0',
      harvestDays: product.harvestDays.toString(),
      description: product.description,
      reservedQuantity: 0,
      targetQuantity: 0,
    );
  }

  Widget _buildPreOrderSectionHeader(int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: AppColors.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Ending Soon',
            style: AppTextStyles.headline2.copyWith(fontSize: 22),
          ),
          const Spacer(),
          Text(
            '$count LIVE',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumPreOrderCard(ProductItem product) {
    int daysLeft = 7;
    String timeUnitLabel = 'DAYS LEFT';
    if (product.harvestDays != null) {
      final days = int.tryParse(product.harvestDays!) ?? 7;
      if (product.createdAt != null) {
        final harvestDate = product.createdAt!.add(Duration(days: days));
        final diff = harvestDate.difference(DateTime.now());
        if (diff.isNegative) {
          daysLeft = 0;
          timeUnitLabel = 'HARVESTED';
        } else {
          final remainingDays = diff.inDays;
          if (remainingDays >= 1) {
            daysLeft = remainingDays;
            timeUnitLabel = remainingDays == 1 ? 'DAY LEFT' : 'DAYS LEFT';
          } else {
            final remainingHours = diff.inHours;
            if (remainingHours >= 1) {
              daysLeft = remainingHours;
              timeUnitLabel = remainingHours == 1 ? 'HOUR LEFT' : 'HOURS LEFT';
            } else {
              final remainingMinutes = diff.inMinutes;
              daysLeft = remainingMinutes > 0 ? remainingMinutes : 0;
              timeUnitLabel = remainingMinutes == 1 ? 'MIN LEFT' : 'MINS LEFT';
            }
          }
        }
      } else {
        daysLeft = days;
      }
    }

    final reservedQty = product.reservedQuantity ?? 0;
    final targetQty = product.targetQuantity ?? 0;
    final reservedCount = targetQty > 0
        ? ((reservedQty / targetQty) * 100).clamp(0, 100).round()
        : 0;
    final isHot = reservedCount > 75;

    return Container(
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: AppColors.background),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.background,
                    child: const Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: AppColors.textSubtle,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bookmark_border_rounded,
                    size: 20,
                    color: AppColors.textHeadline,
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$daysLeft',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        timeUnitLabel,
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildPriceOverlay(product.price),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: AppTextStyles.headline2.copyWith(
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.eco_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                product.farm,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSubtle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildHotTag(isHot),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$reservedCount% Reserved',
                      style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isHot ? AppColors.error : AppColors.textHeadline,
                      ),
                    ),
                    Text(
                      targetQty > 0
                          ? '${targetQty.toStringAsFixed(0)} ${product.unit.isNotEmpty ? product.unit : 'kg'} Target'
                          : 'Target TBD',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSubtle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: reservedCount / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.background,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isHot ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => _openPreOrderDetails(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'RESERVE HARVEST',
                      style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceOverlay(String price) {
    final normalizedPrice = _normalizePrice(price);

    return Positioned(
      bottom: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.textHeadline.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(
              normalizedPrice,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'PRE-ORDER',
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _normalizePrice(String price) {
    final trimmed = price.trim();
    if (trimmed.isEmpty) return '₱0';

    final numeric = trimmed.replaceAll(RegExp(r'[^0-9.]'), '');
    if (numeric.isEmpty) return '₱0';
    return '₱$numeric';
  }

  void _openPreOrderDetails(ProductItem product) {
    final productId = product.productId;
    if (productId == null || productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This pre-order is missing product details.'),
        ),
      );
      return;
    }

    context.push(AppRoutes.preorderDetails, extra: product);
  }

  Widget _buildEmptyState({bool isOffline = false}) {
    final hasSearch = _searchController.text.trim().isNotEmpty;
    final hasCategory =
        _selectedFilter > 0 && _selectedFilter < _filters.length;

    final title = isOffline
        ? 'No Cached Pre-orders'
        : hasSearch || hasCategory
        ? 'No Matching Pre-orders'
        : 'No Pre-orders Yet';

    final message = isOffline
        ? 'Load pre-orders while online to view them offline.'
        : hasSearch || hasCategory
        ? 'Try another search or switch back to All Crops.'
        : 'Upcoming harvests from farmers will appear here.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOffline ? Icons.offline_bolt_rounded : Icons.spa_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.headline3.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            if (hasSearch || hasCategory) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _selectedFilter = 0);
                },
                child: const Text('Show All Crops'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Could not load pre-orders',
              style: AppTextStyles.headline3.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.replaceFirst('Exception: ', ''),
              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshPreOrders,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSavedSeedsInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved pre-orders are available offline after browsing.'),
      ),
    );
  }

  Widget _buildHotTag(bool isHot) {
    if (!isHot) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.whatshot_rounded, color: AppColors.error, size: 14),
          const SizedBox(width: 4),
          Text(
            'HOT Reservation',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
