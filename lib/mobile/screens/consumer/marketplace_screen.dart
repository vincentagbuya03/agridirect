import 'package:flutter/material.dart';
import 'product_view_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/widgets/brand_logo.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'cart_screen.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/models/cached_product.dart';
import '../../../shared/services/offline/offline_cache_service.dart';
import '../../../shared/services/offline/network_status_service.dart';
import '../../widgets/offline_browse_widget.dart';
import '../../widgets/skeleton_loaders.dart';
import '../../../shared/services/commerce/cart_service.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../auth/qr_scanner_screen.dart';
import 'search_screen.dart';

import '../../../shared/services/community/notification_service.dart';
import 'home/widgets/ecom_product_card.dart';

enum MarketplaceSort {
  popular,
  latest,
  topSales,
  priceAsc,
  priceDesc,
}

/// Marketplace Screen - Professional Digital Marketplace
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  int _selectedFilter = 0;
  List<String> _filters = ['All Products'];
  MarketplaceSort _selectedSort = MarketplaceSort.popular;
  bool _inStockOnly = false;
  bool _freeShippingOnly = false;
  bool _wholesaleOnly = false;
  bool _isOnline = true;
  late OfflineCacheService _cacheService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final GlobalKey _cartKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();
  late Stream<List<ProductItem>> _productsStream;

  double _minPrice = 0.0;
  double _maxPrice = 1000.0;
  double _maxDistance = 50.0;
  bool _distanceFilterEnabled = false; // only filter by distance when user explicitly sets it
  bool _priceFilterEnabled = false; // only filter by price when user explicitly sets it
  Position? _userPosition;

  Widget _buildHeaderNotification(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService().unreadCountNotifier,
      builder: (context, count, _) {
        return GestureDetector(
          onTap: () => context.push(AppRoutes.notifications),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.textHeadline.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textHeadline.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.textHeadline,
                  size: 24,
                ),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _ensureCacheServiceReady() async {
    if (!_cacheService.isInitialized) {
      await _cacheService.init();
    }
  }

  @override
  void initState() {
    super.initState();
    _productsStream = SupabaseDataService().watchNearbyProducts();
    _initializeCacheService();
    _setupConnectivityListener();
    _loadMarketplaceCategories();
    _fetchUserPosition();
    SupabaseDataService.marketplaceCategoryNotifier.addListener(
      _onExternalCategoryFilter,
    );
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _fetchUserPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (mounted) {
          setState(() {
            _userPosition = pos;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to get user position: $e');
    }
  }

  Future<void> _openQRScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(
          title: 'Scan Product QR',
          instruction: 'Scan a product QR code to view details',
        ),
      ),
    );

    if (result != null && result is String) {
      String? productId;
      try {
        final uri = Uri.parse(result);
        if (uri.queryParameters.containsKey('id')) {
          productId = uri.queryParameters['id'];
        } else {
          productId = result; 
        }
      } catch (e) {
        productId = result;
      }
      
      if (productId != null && productId.isNotEmpty) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductViewScreen(
              product: ProductItem(
                productId: productId,
                name: '',
                farm: '',
                price: '',
                unit: '',
                imageUrl: '',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openSearchScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(initialQuery: _searchController.text),
      ),
    );

    if (result != null) {
      if (result is Map && result.containsKey('qr')) {
        _handleScannedQRResult(result['qr']);
      } else if (result is String) {
        setState(() {
          _searchController.text = result;
        });
      }
    }
  }

  void _handleScannedQRResult(String result) {
    String? productId;
    try {
      final uri = Uri.parse(result);
      if (uri.queryParameters.containsKey('id')) {
        productId = uri.queryParameters['id'];
      } else {
        productId = result; 
      }
    } catch (e) {
      productId = result;
    }
    
    if (productId != null && productId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductViewScreen(
            product: ProductItem(
              productId: productId,
              name: '',
              farm: '',
              price: '',
              unit: '',
              imageUrl: '',
            ),
          ),
        ),
      );
    }
  }

  void _onExternalCategoryFilter() {
    final cat = SupabaseDataService.marketplaceCategoryNotifier.value;
    if (cat != null && mounted) {
      _applyExternalFilter();
    }
  }

  void _applyExternalFilter() {
    final cat = SupabaseDataService.marketplaceCategoryNotifier.value;
    if (cat == null) return;

    final index = _filters.indexWhere(
      (f) => f.toLowerCase() == cat.toLowerCase(),
    );
    if (index != -1) {
      setState(() {
        _selectedFilter = index;
      });
    }
  }

  Future<void> _loadMarketplaceCategories() async {
    try {
      final dbCategories = await SupabaseDataService()
          .getMarketplaceCategories();
      if (!mounted) return;

      setState(() {
        _filters = ['All Products', ...dbCategories];
        if (_selectedFilter >= _filters.length) {
          _selectedFilter = 0;
        }
        _applyExternalFilter();
      });
    } catch (e) {
      debugPrint('[Marketplace] âš ï¸ Failed to load categories: $e');
    }
  }

  bool _matchesSelectedCategory(ProductItem product) {
    if (_selectedFilter == 0 || _selectedFilter >= _filters.length) {
      return true;
    }

    final selectedCategory = _filters[_selectedFilter].trim().toLowerCase();
    final productCategory = (product.categoryName ?? '').trim().toLowerCase();
    return productCategory.isNotEmpty && productCategory == selectedCategory;
  }

  void _initializeCacheService() {
    _cacheService = OfflineCacheService();
    _ensureCacheServiceReady();
  }

  CachedProduct _toCachedProduct(ProductItem product) {
    return CachedProduct(
      id: product.productId ?? 'unknown_${product.name}',
      farmerId: product.farmerId ?? '',
      name: product.name,
      price: _parsePrice(product.price),
      description: product.description,
      imageUrl: product.imageUrl,
      category: product.categoryName,
      unit: product.unit,
      isPreorder: false,
      harvestDays: int.tryParse(product.harvestDays ?? '0') ?? 0,
      farmName: product.farm,
      rating: double.tryParse(product.rating ?? '0') ?? 0.0,
      farmerAvatarUrl: product.farmerAvatarUrl,
      farmerImageUrl: product.farmerImageUrl,
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
          _refreshMarketplaceCacheFromServer();
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

  Future<void> _refreshMarketplaceCacheFromServer() async {
    try {
      debugPrint('[Marketplace] 🔄 Refreshing cache after reconnect...');
      final liveProducts = await SupabaseDataService().getNearbyProducts();
      final liveIds = liveProducts
          .map((p) => p.productId)
          .whereType<String>()
          .toSet();

      final cachedProducts = _cacheService.getAllCachedProducts();
      int removed = 0;

      for (final cached in cachedProducts) {
        if (cached.isManuallySaved) continue;
        if (!liveIds.contains(cached.id)) {
          await _cacheService.removeCachedProduct(cached.id);
          removed++;
        }
      }

      if (removed > 0) {
        debugPrint(
          '[Marketplace] 🧹 Purged $removed stale products from cache',
        );
      }
      debugPrint('[Marketplace] ✅ Cache refresh complete');
    } catch (e) {
      debugPrint('[Marketplace] ⚠️ Cache refresh failed: $e');
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    SupabaseDataService.marketplaceCategoryNotifier.removeListener(
      _onExternalCategoryFilter,
    );
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
          _buildShopeeSortBar(),
          Expanded(child: _buildProductContent()),
        ],
      ),
    );
  }

  Widget _buildShopeeSortBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textHeadline.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildSortTabItem(
            title: 'Popular',
            isSelected: _selectedSort == MarketplaceSort.popular,
            onTap: () => setState(() => _selectedSort = MarketplaceSort.popular),
          ),
          _buildSortDivider(),
          _buildSortTabItem(
            title: 'Latest',
            isSelected: _selectedSort == MarketplaceSort.latest,
            onTap: () => setState(() => _selectedSort = MarketplaceSort.latest),
          ),
          _buildSortDivider(),
          _buildSortTabItem(
            title: 'Top Sales',
            isSelected: _selectedSort == MarketplaceSort.topSales,
            onTap: () => setState(() => _selectedSort = MarketplaceSort.topSales),
          ),
          _buildSortDivider(),
          _buildSortTabItem(
            title: 'Price',
            isSelected: _selectedSort == MarketplaceSort.priceAsc ||
                _selectedSort == MarketplaceSort.priceDesc,
            icon: _selectedSort == MarketplaceSort.priceAsc
                ? Icons.arrow_upward_rounded
                : _selectedSort == MarketplaceSort.priceDesc
                    ? Icons.arrow_downward_rounded
                    : Icons.unfold_more_rounded,
            onTap: () {
              setState(() {
                if (_selectedSort == MarketplaceSort.priceAsc) {
                  _selectedSort = MarketplaceSort.priceDesc;
                } else {
                  _selectedSort = MarketplaceSort.priceAsc;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSortTabItem({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textSubtle,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 2),
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? AppColors.primary : AppColors.textSubtle,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortDivider() {
    return Container(
      width: 1,
      height: 16,
      color: AppColors.textHeadline.withValues(alpha: 0.08),
    );
  }

  void _applySorting(List<ProductItem> list) {
    switch (_selectedSort) {
      case MarketplaceSort.popular:
        list.sort((a, b) {
          final rA = double.tryParse(a.rating ?? '0') ?? 0;
          final rB = double.tryParse(b.rating ?? '0') ?? 0;
          return rB.compareTo(rA);
        });
        break;
      case MarketplaceSort.latest:
        list.sort((a, b) {
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        });
        break;
      case MarketplaceSort.topSales:
        list.sort((a, b) => (b.soldCount ?? 0).compareTo(a.soldCount ?? 0));
        break;
      case MarketplaceSort.priceAsc:
        list.sort((a, b) => _parsePrice(a.price).compareTo(_parsePrice(b.price)));
        break;
      case MarketplaceSort.priceDesc:
        list.sort((a, b) => _parsePrice(b.price).compareTo(_parsePrice(a.price)));
        break;
    }
  }

  Widget _buildPremiumHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const BrandLogo(),
                  Row(
                    children: [
                      _buildHeaderNotification(context),
                      const SizedBox(width: 12),
                      _buildHeaderCart(context),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _openSearchScreen,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: _openQRScanner,
                              child: const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _searchController.text.isNotEmpty ? _searchController.text : 'Search products...',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: _searchController.text.isNotEmpty ? AppColors.textHeadline : AppColors.textSubtle,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _searchController.clear();
                                  });
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    Icons.clear_rounded,
                                    color: AppColors.textSubtle,
                                    size: 18,
                                  ),
                                ),
                              ),
                            Container(
                              margin: const EdgeInsets.all(4),
                              width: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.search_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _showFilterDialog,
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
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

  Widget _buildHeaderCart(BuildContext context) {
    return ListenableBuilder(
      listenable: CartService(),
      builder: (context, _) {
        final count = CartService().itemCount;
        return GestureDetector(
          key: _cartKey,
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CartScreen()));
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.textHeadline.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textHeadline.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.shopping_cart_outlined,
                  color: AppColors.textHeadline,
                  size: 24,
                ),
                if (count > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSleekFilterChips() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final isSelected = _selectedFilter == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: AppColors.textHeadline.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textHeadline.withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: Text(
                  _filters[i],
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppColors.textSubtle,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductContent() {
    final query = _searchController.text.trim().toLowerCase();

    if (!_isOnline) {
      final currentUserId = AuthService().userId;
      final cachedProducts = _cacheService
          .getAllCachedProducts()
          .where((p) => !p.isPreorder)
          .map(_cachedToProductItem)
          .where((p) {
            final isNotMine =
                currentUserId.isEmpty || p.farmerId != currentUserId;
            final matchesCategory = _matchesSelectedCategory(p);
            final matchesQuery =
                query.isEmpty ||
                p.name.toLowerCase().contains(query) ||
                (p.description ?? '').toLowerCase().contains(query) ||
                p.farm.toLowerCase().contains(query);

            final productPrice = _parsePrice(p.price);
            final matchesPrice = !_priceFilterEnabled ||
                (productPrice >= _minPrice && productPrice <= _maxPrice);

            bool matchesDistance = true;
            if (_distanceFilterEnabled &&
                _userPosition != null &&
                p.latitude != null &&
                p.longitude != null) {
              final distInMeters = Geolocator.distanceBetween(
                _userPosition!.latitude,
                _userPosition!.longitude,
                p.latitude!,
                p.longitude!,
              );
              final distInKm = distInMeters / 1000.0;
              matchesDistance = distInKm <= _maxDistance;
            }

            if (_inStockOnly && p.stockQuantity != null && p.stockQuantity! <= 0) {
              return false;
            }
            if (_freeShippingOnly && !p.isFreeShipping) {
              return false;
            }
            if (_wholesaleOnly && !p.isWholesale) {
              return false;
            }

            return matchesCategory &&
                isNotMine &&
                matchesQuery &&
                matchesPrice &&
                matchesDistance;
          })
          .toList();

      _applySorting(cachedProducts);

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: OfflineModeIndicator(cacheService: _cacheService),
          ),
          Expanded(
            child: cachedProducts.isEmpty
                ? _buildNoCategoryMatchState(isOffline: true)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildActiveFiltersRow(),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: cachedProducts.length,
                          itemBuilder: (_, i) =>
                              EcomProductCard(
                                product: cachedProducts[i],
                                userPosition: _userPosition,
                              ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      );
    }

    return StreamBuilder<List<ProductItem>>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            child: ProductGridSkeleton(itemCount: 6, enabled: true),
          );
        }

        final products = snapshot.data ?? [];
        final currentUserId = AuthService().userId;
        final filteredProducts = products.where((p) {
          final isNotMine =
              currentUserId.isEmpty || p.farmerId != currentUserId;
          final matchesCategory = _matchesSelectedCategory(p);
          final matchesQuery =
              query.isEmpty ||
              p.name.toLowerCase().contains(query) ||
              (p.description ?? '').toLowerCase().contains(query) ||
              p.farm.toLowerCase().contains(query);

          final productPrice = _parsePrice(p.price);
          final matchesPrice = !_priceFilterEnabled ||
              (productPrice >= _minPrice && productPrice <= _maxPrice);

          bool matchesDistance = true;
          if (_distanceFilterEnabled &&
              _userPosition != null &&
              p.latitude != null &&
              p.longitude != null) {
            final distInMeters = Geolocator.distanceBetween(
              _userPosition!.latitude,
              _userPosition!.longitude,
              p.latitude!,
              p.longitude!,
            );
            final distInKm = distInMeters / 1000.0;
            matchesDistance = distInKm <= _maxDistance;
          }

          if (_inStockOnly && p.stockQuantity != null && p.stockQuantity! <= 0) {
            return false;
          }
          if (_freeShippingOnly && !p.isFreeShipping) {
            return false;
          }
          if (_wholesaleOnly && !p.isWholesale) {
            return false;
          }

          return matchesCategory &&
              isNotMine &&
              matchesQuery &&
              matchesPrice &&
              matchesDistance;
        }).toList();

        _applySorting(filteredProducts);

        if (filteredProducts.isEmpty) {
          return _buildNoCategoryMatchState();
        }

        if (products.isNotEmpty) {
          for (final product in products) {
            final cachedProduct = _toCachedProduct(product);
            _cacheService.autoCacheProduct(cachedProduct);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActiveFiltersRow(),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (_, i) => EcomProductCard(
                  product: filteredProducts[i],
                  userPosition: _userPosition,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoProductsFoundState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Products Found',
              style: AppTextStyles.headline3.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t find any products matching your filters. Try adjusting your search query, price range, or distance.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSubtle,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _minPrice = 0.0;
                  _maxPrice = 1000.0;
                  _maxDistance = 50.0;
                  _distanceFilterEnabled = false;
                  _priceFilterEnabled = false;
                  _searchController.clear();
                  _selectedFilter = 0;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Reset All Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCategoryMatchState({bool isOffline = false}) {
    if (!isOffline) {
      return _buildNoProductsFoundState();
    }

    final hasCategoryFilter =
        _selectedFilter > 0 && _selectedFilter < _filters.length;
    final selectedCategory = hasCategoryFilter
        ? _filters[_selectedFilter]
        : null;

    if (!hasCategoryFilter) {
      return _buildNoCachedProductsState();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 56,
              color: AppColors.textSubtle.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 14),
            Text(
              'No products in $selectedCategory yet.',
              style: AppTextStyles.headline3.copyWith(
                color: AppColors.textHeadline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try reconnecting or switch back to All Products.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSubtle,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => setState(() => _selectedFilter = 0),
              child: const Text('Show All Products'),
            ),
          ],
        ),
      ),
    );
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
      name: product.name,
      farm: product.farmName ?? 'Farm',
      price: '₱${product.price.toStringAsFixed(2)}',
      unit: normalizedUnit.isEmpty ? 'kg' : normalizedUnit,
      imageUrl: product.imageUrl ?? '',
      categoryName: product.category,
      rating: (product.rating ?? 0).toStringAsFixed(1),
      reviews: '0',
      harvestDays: product.harvestDays.toString(),
      farmerAvatarUrl: product.farmerAvatarUrl,
      farmerImageUrl: product.farmerImageUrl,
      description: product.description,
    );
  }

  Widget _buildNoCachedProductsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.offline_bolt_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Cached Products',
            style: AppTextStyles.headline3.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse products while online to keep this layout available offline.',
            style: AppTextStyles.bodySmall.copyWith(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersRow() {
    final hasActive = _priceFilterEnabled ||
        _distanceFilterEnabled ||
        _inStockOnly ||
        _freeShippingOnly ||
        _wholesaleOnly;
    if (!hasActive) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (_priceFilterEnabled) ...[
              _buildInlineFilterChip(
                Icons.sell_rounded,
                '₱${_minPrice.toInt()} - ₱${_maxPrice.toInt()}',
                () => setState(() {
                  _priceFilterEnabled = false;
                  _minPrice = 0.0;
                  _maxPrice = 1000.0;
                }),
              ),
              const SizedBox(width: 8),
            ],
            if (_distanceFilterEnabled) ...[
              _buildInlineFilterChip(
                Icons.near_me_rounded,
                '< ${_maxDistance.toInt()} km',
                () => setState(() {
                  _distanceFilterEnabled = false;
                  _maxDistance = 50.0;
                }),
              ),
              const SizedBox(width: 8),
            ],
            if (_inStockOnly) ...[
              _buildInlineFilterChip(
                Icons.inventory_2_outlined,
                'In Stock',
                () => setState(() => _inStockOnly = false),
              ),
              const SizedBox(width: 8),
            ],
            if (_freeShippingOnly) ...[
              _buildInlineFilterChip(
                Icons.local_shipping_outlined,
                'Free Shipping',
                () => setState(() => _freeShippingOnly = false),
              ),
              const SizedBox(width: 8),
            ],
            if (_wholesaleOnly) ...[
              _buildInlineFilterChip(
                Icons.storefront_outlined,
                'Wholesale',
                () => setState(() => _wholesaleOnly = false),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(ctx).padding.bottom + 24,
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
                      color: AppColors.textSubtle.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Marketplace',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textHeadline,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          _minPrice = 0.0;
                          _maxPrice = 1000.0;
                          _maxDistance = 50.0;
                          _inStockOnly = false;
                          _freeShippingOnly = false;
                          _wholesaleOnly = false;
                        });
                        setState(() {
                          _priceFilterEnabled = false;
                          _distanceFilterEnabled = false;
                          _inStockOnly = false;
                          _freeShippingOnly = false;
                          _wholesaleOnly = false;
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Reset',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.payments_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Price Range',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHeadline,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '₱${_minPrice.toInt()} - ₱${_maxPrice.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 5,
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          thumbColor: AppColors.primary,
                          overlayColor:
                              AppColors.primary.withValues(alpha: 0.2),
                          valueIndicatorTextStyle:
                              const TextStyle(color: Colors.white),
                        ),
                        child: RangeSlider(
                          values: RangeValues(_minPrice, _maxPrice),
                          min: 0.0,
                          max: 1000.0,
                          divisions: 50,
                          labels: RangeLabels(
                            '₱${_minPrice.toInt()}',
                            '₱${_maxPrice.toInt()}',
                          ),
                          onChanged: (values) {
                            setSheetState(() {
                              _minPrice = values.start;
                              _maxPrice = values.end;
                            });
                            setState(() {
                              _priceFilterEnabled = true;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Max Radius',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHeadline,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '${_maxDistance.toInt()} km',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 5,
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          thumbColor: AppColors.primary,
                          overlayColor:
                              AppColors.primary.withValues(alpha: 0.2),
                          valueIndicatorTextStyle:
                              const TextStyle(color: Colors.white),
                        ),
                        child: Slider(
                          value: _maxDistance,
                          min: 1.0,
                          max: 50.0,
                          divisions: 49,
                          label: '${_maxDistance.toInt()} km',
                          onChanged: (val) {
                            setSheetState(() {
                              _maxDistance = val;
                            });
                            setState(() {
                              _distanceFilterEnabled = true;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.textHeadline.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeTrackColor: AppColors.primary,
                        title: Text(
                          'In Stock Only',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHeadline,
                          ),
                        ),
                        subtitle: Text(
                          'Hide out-of-stock items',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSubtle,
                          ),
                        ),
                        value: _inStockOnly,
                        onChanged: (val) {
                          setSheetState(() => _inStockOnly = val);
                          setState(() => _inStockOnly = val);
                        },
                      ),
                      Divider(
                        height: 1,
                        color: AppColors.textHeadline.withValues(alpha: 0.06),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeTrackColor: AppColors.primary,
                        title: Text(
                          'Free Shipping Available',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHeadline,
                          ),
                        ),
                        subtitle: Text(
                          'Items eligible for zero-fee delivery',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSubtle,
                          ),
                        ),
                        value: _freeShippingOnly,
                        onChanged: (val) {
                          setSheetState(() => _freeShippingOnly = val);
                          setState(() => _freeShippingOnly = val);
                        },
                      ),
                      Divider(
                        height: 1,
                        color: AppColors.textHeadline.withValues(alpha: 0.06),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeTrackColor: AppColors.primary,
                        title: Text(
                          'Wholesale / Bulk Only',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHeadline,
                          ),
                        ),
                        subtitle: Text(
                          'Direct crate or bulk farmer pricing',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSubtle,
                          ),
                        ),
                        value: _wholesaleOnly,
                        onChanged: (val) {
                          setSheetState(() => _wholesaleOnly = val);
                          setState(() => _wholesaleOnly = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Apply Filters',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineFilterChip(
    IconData icon,
    String label,
    VoidCallback onClear,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
