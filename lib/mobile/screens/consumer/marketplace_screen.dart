import 'package:flutter/material.dart';
import 'product_view_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/widgets/brand_logo.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import '../../../shared/widgets/flying_icon_animation.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../auth/qr_scanner_screen.dart';
import 'search_screen.dart';

import '../../../shared/services/community/notification_service.dart';

/// Marketplace Screen - Professional Digital Marketplace
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  int _selectedFilter = 0;
  List<String> _filters = ['All Products'];
  bool _isOnline = true;
  late OfflineCacheService _cacheService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final GlobalKey _cartKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();
  late Stream<List<ProductItem>> _productsStream;
  final List<OverlayEntry> _flyingOverlayEntries = [];

  double _minPrice = 0.0;
  double _maxPrice = 1000.0;
  double _maxDistance = 50.0;
  bool _distanceFilterEnabled = false; // only filter by distance when user explicitly sets it
  bool _priceFilterEnabled = false; // only filter by price when user explicitly sets it
  Position? _userPosition;

  Widget _buildHeaderNotification(BuildContext context) {
    final userId = AuthService().userId;
    return FutureBuilder<int>(
      future: NotificationService().getUnreadNotificationCount(userId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
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

  Future<void> _toggleFavorite(ProductItem product) async {
    final productId = product.productId ?? 'unknown_${product.name}';
    await _ensureCacheServiceReady();

    final isSaved = _cacheService.isProductManuallySaved(productId);
    if (isSaved) {
      await _cacheService.removeCachedProduct(productId);
    } else {
      await _cacheService.manualSaveProduct(_toCachedProduct(product));
    }

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSaved
              ? '${product.name} removed from favorites.'
              : '${product.name} saved to favorites.',
        ),
        backgroundColor: isSaved ? AppColors.textHeadline : AppColors.success,
      ),
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
      debugPrint('[Marketplace] ðŸ”„ Refreshing cache after reconnect...');
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
          '[Marketplace] ðŸ§¹ Purged $removed stale products from cache',
        );
      }
      debugPrint('[Marketplace] âœ… Cache refresh complete');
    } catch (e) {
      debugPrint('[Marketplace] âš ï¸ Cache refresh failed: $e');
    }
  }

  @override
  void dispose() {
    for (final entry in _flyingOverlayEntries) {
      if (entry.mounted) {
        entry.remove();
      }
    }
    _flyingOverlayEntries.clear();
    _connectivitySubscription?.cancel();
    SupabaseDataService.marketplaceCategoryNotifier.removeListener(
      _onExternalCategoryFilter,
    );
    _searchController.dispose();
    super.dispose();
  }

  void _openProductView(ProductItem product, {String? heroTag}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductViewScreen(product: product, heroTag: heroTag)),
    );
  }

  void _runFlyToCartAnimation(GlobalKey startKey, String imageUrl) {
    final startCtx = startKey.currentContext;
    final cartCtx = _cartKey.currentContext;
    if (startCtx == null || cartCtx == null) return;

    final RenderBox? buttonBox = startCtx.findRenderObject() as RenderBox?;
    final RenderBox? cartBox = cartCtx.findRenderObject() as RenderBox?;

    if (buttonBox == null || cartBox == null) return;
    if (!buttonBox.attached || !cartBox.attached) return;
    if (!buttonBox.hasSize || !cartBox.hasSize) return;

    final startPosition = buttonBox.localToGlobal(Offset.zero);
    final endPosition = cartBox.localToGlobal(Offset.zero);

    if (!startPosition.dx.isFinite ||
        !startPosition.dy.isFinite ||
        !endPosition.dx.isFinite ||
        !endPosition.dy.isFinite) {
      return;
    }

    final screenSize = MediaQuery.of(context).size;
    if (startPosition.dx < 0 ||
        startPosition.dx > screenSize.width ||
        startPosition.dy < 0 ||
        startPosition.dy > screenSize.height) {
      return;
    }
    if (endPosition.dx < 0 ||
        endPosition.dx > screenSize.width ||
        endPosition.dy < 0 ||
        endPosition.dy > screenSize.height) {
      return;
    }

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => FlyingIconAnimation(
        startPosition: startPosition,
        endPosition: endPosition,
        imageUrl: imageUrl,
        onComplete: () {
          _flyingOverlayEntries.remove(overlayEntry);
          if (overlayEntry.mounted) {
            overlayEntry.remove();
          }
        },
      ),
    );

    _flyingOverlayEntries.add(overlayEntry);
    final overlay = Overlay.maybeOf(context);
    if (overlay != null) {
      overlay.insert(overlayEntry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildPremiumHeader(),
          _buildSleekFilterChips(),
          Expanded(child: _buildProductContent()),
        ],
      ),
    );
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

            return matchesCategory &&
                isNotMine &&
                matchesQuery &&
                matchesPrice &&
                matchesDistance;
          })
          .toList();

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
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 250,
                          ),
                          itemCount: cachedProducts.length,
                          itemBuilder: (_, i) =>
                              _buildProductCard(cachedProducts[i]),
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

          return matchesCategory &&
              isNotMine &&
              matchesQuery &&
              matchesPrice &&
              matchesDistance;
        }).toList();

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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 250,
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (_, i) => _buildProductCard(filteredProducts[i]),
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
      price: 'â‚±${product.price.toStringAsFixed(2)}',
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
    if (!_priceFilterEnabled && !_distanceFilterEnabled) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (_priceFilterEnabled) ...[
              _buildInlineFilterChip(
                Icons.sell_rounded,
                'â‚±${_minPrice.toInt()} - â‚±${_maxPrice.toInt()}',
                () => setState(() {
                  _priceFilterEnabled = false;
                  _minPrice = 0.0;
                  _maxPrice = 1000.0;
                }),
              ),
              const SizedBox(width: 8),
            ],
            if (_distanceFilterEnabled)
              _buildInlineFilterChip(
                Icons.near_me_rounded,
                '< ${_maxDistance.toInt()} km',
                () => setState(() {
                  _distanceFilterEnabled = false;
                  _maxDistance = 50.0;
                }),
              ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
              const SizedBox(height: 24),
              Text(
                'Filter Marketplace',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHeadline,
                ),
              ),
              const SizedBox(height: 24),
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
                      });
                      setState(() {
                        _priceFilterEnabled = false;
                        _distanceFilterEnabled = false;
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Price Range',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHeadline,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                            '\u20B1${_minPrice.toInt()} - \u20B1${_maxPrice.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withValues(alpha: 0.2),
                        valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                      ),
                      child: RangeSlider(
                        values: RangeValues(_minPrice, _maxPrice),
                        min: 0.0,
                        max: 1000.0,
                        divisions: 50,
                        labels: RangeLabels(
                          '\u20B1${_minPrice.toInt()}',
                          '\u20B1${_maxPrice.toInt()}',
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Maximum Distance',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHeadline,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withValues(alpha: 0.2),
                        valueIndicatorTextStyle: const TextStyle(color: Colors.white),
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
              const SizedBox(height: 32),
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
    );
  }

  Widget _buildInlineFilterChip(IconData icon, String label, VoidCallback onClear) {
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
            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductItem product) {
    final productId = product.productId ?? 'unknown_${product.name}';
    final isSaved = _cacheService.isProductManuallySaved(productId);

    final String heroTag = 'marketplace_product_$productId';
    return GestureDetector(
      onTap: () => _openProductView(product, heroTag: heroTag),
      child: Container(
        decoration: AppDecorations.cardDecoration.copyWith(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Hero(
                    tag: heroTag,
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (product.categoryName != null && product.categoryName!.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        product.categoryName!,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(product),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSaved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: isSaved
                            ? Colors.redAccent
                            : AppColors.textSubtle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: AppTextStyles.headline3.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.farm,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSubtle,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, size: 12, color: AppColors.warning),
                                  const SizedBox(width: 4),
                                  Text(
                                    product.rating ?? '0.0',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textBody,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${product.price} / ${product.unit}',
                                style: AppTextStyles.headline3.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        _AddToCartButton(
                          onTap: (GlobalKey buttonKey) async {
                            _runFlyToCartAnimation(buttonKey, product.imageUrl);
                            final errorMsg = await CartService().addItem(
                              product,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  errorMsg ?? '${product.name} added to cart',
                                ),
                                duration: const Duration(seconds: 1),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
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

class _AddToCartButton extends StatefulWidget {
  final Function(GlobalKey) onTap;
  const _AddToCartButton({required this.onTap});

  @override
  State<_AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends State<_AddToCartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  final GlobalKey _buttonKey = GlobalKey();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () => widget.onTap(_buttonKey),
      child: ScaleTransition(
        key: _buttonKey,
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_shopping_cart_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
