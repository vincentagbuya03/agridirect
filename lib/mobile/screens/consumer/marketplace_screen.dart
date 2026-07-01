import 'package:flutter/material.dart';
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
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/services/commerce/cart_service.dart';
import 'package:agridirect/shared/widgets/image_widgets.dart';
import '../../../shared/services/user/user_service.dart';
import '../../../shared/models/auth/user_address_model.dart';
import '../../../shared/models/farmer/farmer_profile_model.dart';
import '../../../shared/services/farmer/farmer_service.dart';
import '../../../shared/services/integration/reverse_geocoding_service.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/widgets/report_content_dialog.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/services/auth/auth_service.dart';

import '../../../shared/services/community/notification_service.dart';
import '../../widgets/mobile_notifications_sheet.dart';

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

  Widget _buildHeaderNotification(BuildContext context) {
    final userId = AuthService().userId;
    return FutureBuilder<int>(
      future: NotificationService().getUnreadNotificationCount(userId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return GestureDetector(
          onTap: () => showMobileNotificationsSheet(context),
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
    _initializeCacheService();
    _setupConnectivityListener();
    _loadMarketplaceCategories();
    SupabaseDataService.marketplaceCategoryNotifier.addListener(_onExternalCategoryFilter);
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
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

    final index = _filters.indexWhere((f) => f.toLowerCase() == cat.toLowerCase());
    if (index != -1) {
      setState(() {
        _selectedFilter = index;
      });
    }
  }

  Future<void> _loadMarketplaceCategories() async {
    try {
      final dbCategories = await SupabaseDataService().getMarketplaceCategories();
      if (!mounted) return;

      setState(() {
        _filters = ['All Products', ...dbCategories];
        if (_selectedFilter >= _filters.length) {
          _selectedFilter = 0;
        }
        _applyExternalFilter();
      });
    } catch (e) {
      debugPrint('[Marketplace] ⚠️ Failed to load categories: $e');
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
        debugPrint('[Marketplace] 🧹 Purged $removed stale products from cache');
      }
      debugPrint('[Marketplace] ✅ Cache refresh complete');
    } catch (e) {
      debugPrint('[Marketplace] ⚠️ Cache refresh failed: $e');
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    SupabaseDataService.marketplaceCategoryNotifier.removeListener(_onExternalCategoryFilter);
    _searchController.dispose();
    super.dispose();
  }

  void _openProductView(ProductItem product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductViewScreen(product: product)),
    );
  }

  void _runFlyToCartAnimation(GlobalKey startKey, String imageUrl) {
    final RenderBox? buttonBox = startKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? cartBox = _cartKey.currentContext?.findRenderObject() as RenderBox?;

    if (buttonBox == null || cartBox == null) return;

    final startPosition = buttonBox.localToGlobal(Offset.zero);
    final endPosition = cartBox.localToGlobal(Offset.zero);

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _FlyingIconAnimation(
        startPosition: startPosition,
        endPosition: endPosition,
        imageUrl: imageUrl,
        onComplete: () => overlayEntry.remove(),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                          color: AppColors.textHeadline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search fresh harvest...',
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
                                  icon: const Icon(Icons.clear_rounded, color: AppColors.textSubtle, size: 20),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
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

  Widget _buildHeaderCart(BuildContext context) {
    return ListenableBuilder(
      listenable: CartService(),
      builder: (context, _) {
        final count = CartService().itemCount;
        return GestureDetector(
          key: _cartKey,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );
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
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
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
                          color: AppColors.textHeadline.withValues(alpha: 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textHeadline.withValues(alpha: 0.1),
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

  Widget _buildProductContent() {
    final query = _searchController.text.trim().toLowerCase();

    if (!_isOnline) {
      final currentUserId = AuthService().userId;
      final cachedProducts = _cacheService
          .getAllCachedProducts()
          .where((p) => !p.isPreorder)
          .map(_cachedToProductItem)
          .where((p) {
            final isNotMine = currentUserId.isEmpty || p.farmerId != currentUserId;
            final matchesCategory = _matchesSelectedCategory(p);
            final matchesQuery = query.isEmpty ||
                p.name.toLowerCase().contains(query) ||
                (p.description ?? '').toLowerCase().contains(query) ||
                p.farm.toLowerCase().contains(query);
            return matchesCategory && isNotMine && matchesQuery;
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
                : Stack(
                    children: [
                      GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio:
                              MediaQuery.of(context).size.width /
                              (MediaQuery.of(context).size.height * 0.75),
                        ),
                        itemCount: cachedProducts.length,
                        itemBuilder: (_, i) =>
                            _buildProductCard(cachedProducts[i]),
                      ),
                      _buildFloatingFilters(),
                    ],
                  ),
          ),
        ],
      );
    }

    return StreamBuilder<List<ProductItem>>(
      stream: SupabaseDataService().watchNearbyProducts(),
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
          final isNotMine = currentUserId.isEmpty || p.farmerId != currentUserId;
          final matchesCategory = _matchesSelectedCategory(p);
          final matchesQuery = query.isEmpty ||
              p.name.toLowerCase().contains(query) ||
              (p.description ?? '').toLowerCase().contains(query) ||
              p.farm.toLowerCase().contains(query);
          return matchesCategory && isNotMine && matchesQuery;
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

        return Stack(
          children: [
            GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              physics: const BouncingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio:
                    MediaQuery.of(context).size.width /
                    (MediaQuery.of(context).size.height * 0.75),
              ),
              itemCount: filteredProducts.length,
              itemBuilder: (_, i) => _buildProductCard(filteredProducts[i]),
            ),
            _buildFloatingFilters(),
          ],
        );
      },
    );
  }

  Widget _buildNoCategoryMatchState({bool isOffline = false}) {
    final hasCategoryFilter = _selectedFilter > 0 && _selectedFilter < _filters.length;
    final selectedCategory = hasCategoryFilter ? _filters[_selectedFilter] : null;

    if (!hasCategoryFilter) {
      return _buildNoCachedProductsState();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 56, color: AppColors.textSubtle.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Text(
              'No products in $selectedCategory yet.',
              style: AppTextStyles.headline3.copyWith(color: AppColors.textHeadline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isOffline
                  ? 'Try reconnecting or switch back to All Products.'
                  : 'Try another category or switch back to All Products.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle),
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

  Widget _buildFloatingFilters() {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildFilterPill(Icons.sell_rounded, '₱2 - ₱500', AppColors.primary),
          const SizedBox(width: 12),
          _buildFilterPill(
            Icons.near_me_rounded,
            '< 5 km',
            const Color(0xFF1E293B),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductItem product) {
    final productId = product.productId ?? 'unknown_${product.name}';
    final isSaved = _cacheService.isProductManuallySaved(productId);

    return GestureDetector(
      onTap: () => _openProductView(product),
      child: Container(
        decoration: AppDecorations.cardDecoration.copyWith(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Hero(
                    tag: 'product_image_${product.productId}',
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(product),
                    child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      isSaved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 16,
                      color: isSaved ? Colors.redAccent : AppColors.textSubtle,
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
                      style: AppTextStyles.headline3.copyWith(fontSize: 15),
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
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.price,
                              style: AppTextStyles.headline3.copyWith(
                                color: AppColors.primary,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              product.unit,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSubtle,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        _AddToCartButton(
                          onTap: (GlobalKey buttonKey) {
                            _runFlyToCartAnimation(buttonKey, product.imageUrl);
                            CartService().addItem(product);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.name} added to cart'),
                                duration: const Duration(seconds: 1),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

class _AddToCartButtonState extends State<_AddToCartButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
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
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class ProductViewScreen extends StatefulWidget {
  final ProductItem product;
  const ProductViewScreen({super.key, required this.product});

  @override
  State<ProductViewScreen> createState() => _ProductViewScreenState();
}

class _ProductViewScreenState extends State<ProductViewScreen> {
  int _quantity = 1;
  bool _isOrdering = false;
  int _currentPage = 0;
  UserAddress? _address;
  String _paymentMethod = 'COD';
  bool _isLoadingAddress = true;
  final OfflineCacheService _cacheService = OfflineCacheService();
  final _instructionsController = TextEditingController();
  final GlobalKey _cartKey = GlobalKey();
  final GlobalKey _addToCartBtnKey = GlobalKey();
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _ensureCacheServiceReady();
    _loadAddress();
    _cacheProductForOffline();
    _refreshSavedState();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadAddress() async {
    try {
      final addresses = await UserService().getAllUserAddresses();
      if (mounted) {
        setState(() {
          if (addresses.isNotEmpty) {
            _address = addresses.firstWhere(
              (a) => a.isDefault,
              orElse: () => addresses.first,
            );
          }
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  Future<void> _ensureCacheServiceReady() async {
    if (!_cacheService.isInitialized) {
      await _cacheService.init();
    }
  }

  void _cacheProductForOffline() {
    try {
      _ensureCacheServiceReady().then((_) {
        _cacheService.autoCacheProduct(_buildCachedProduct());
      });
    } catch (e) {
      debugPrint('⚠️ Failed to auto-cache product: $e');
    }
  }

  CachedProduct _buildCachedProduct() {
    final price = double.tryParse(widget.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    return CachedProduct(
      id: widget.product.productId ?? 'unknown',
      farmerId: widget.product.farmerId ?? 'unknown',
      name: widget.product.name,
      price: price,
      description: widget.product.description,
      imageUrl: widget.product.imageUrl,
      availableQuantity: widget.product.targetQuantity?.toInt(),
      isPreorder: widget.product.targetQuantity != null,
      harvestDays: int.tryParse(widget.product.harvestDays ?? '0') ?? 0,
      farmName: widget.product.farm,
      unit: widget.product.unit,
      rating: double.tryParse(widget.product.rating ?? '0'),
      farmerAvatarUrl: widget.product.farmerAvatarUrl,
    );
  }

  Future<void> _refreshSavedState() async {
    await _ensureCacheServiceReady();
    if (!mounted) return;
    setState(() {
      _isSaved = _cacheService.isProductManuallySaved(_buildCachedProduct().id);
    });
  }

  Future<void> _toggleFavorite() async {
    final cachedProduct = _buildCachedProduct();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSaved
              ? '${widget.product.name} saved to favorites.'
              : '${widget.product.name} removed from favorites.',
        ),
        backgroundColor: _isSaved ? AppColors.success : AppColors.textHeadline,
      ),
    );
  }

  double? _getRating() => widget.product.rating != null ? double.tryParse(widget.product.rating!) : null;
  int _getReviewCount() => widget.product.reviews != null ? int.tryParse(widget.product.reviews!) ?? 0 : 0;
  String _getDescription() => (widget.product.description != null && widget.product.description!.isNotEmpty) ? widget.product.description! : 'No product description available.';

  void _showCheckoutSheet() async {
    final farmerId = widget.product.farmerId;
    FarmerProfile? farmerProfile;
    if (farmerId != null && farmerId.isNotEmpty) {
      try {
        farmerProfile = await FarmerService().getFarmerProfileByFarmerId(farmerId);
      } catch (e) {
        debugPrint('Error loading farmer profile: $e');
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final price = double.tryParse(widget.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
          final subtotal = price * _quantity;

          double deliveryFee = 0.0;
          if (_paymentMethod == 'COD') {
            final minAmount = farmerProfile?.freeDeliveryMinAmount ?? 0.0;
            if (minAmount > 0 && subtotal >= minAmount) {
              deliveryFee = 0.0;
            } else {
              deliveryFee = 50.0;
            }
          }

          final grandTotal = subtotal + deliveryFee;

          return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHeadline.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Checkout Confirmation', style: AppTextStyles.headline1.copyWith(fontSize: 22)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(imageUrl: widget.product.imageUrl, width: 64, height: 64, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.product.name, style: AppTextStyles.headline3.copyWith(fontSize: 16)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Quantity:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
                                Row(
                                  children: [
                                    _buildQtyBtn(icon: Icons.remove_rounded, onTap: () { if (_quantity > 1) { setState(() => _quantity--); setSheetState(() {}); } }),
                                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('$_quantity', style: AppTextStyles.headline3.copyWith(fontSize: 16))),
                                    _buildQtyBtn(icon: Icons.add_rounded, onTap: () { setState(() => _quantity++); setSheetState(() {}); }),
                                    const SizedBox(width: 4),
                                    Text(widget.product.unit, style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
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
                const SizedBox(height: 20),
                Text(_paymentMethod == 'COP' ? 'Pickup Location (at Farm)' : 'Shipping Address', style: AppTextStyles.headline3.copyWith(fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.1)),
                  ),
                  child: _isLoadingAddress
                      ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                      : _paymentMethod == 'COP'
                          ? _buildFarmPickupSection()
                          : _buildShippingAddressSection(setSheetState),
                ),
                const SizedBox(height: 20),
                Text('Payment Method', style: AppTextStyles.headline3.copyWith(fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildPaymentOption(title: 'COD', subtitle: 'Cash on Delivery', isSelected: _paymentMethod == 'COD', onTap: () { setSheetState(() => _paymentMethod = 'COD'); setState(() => _paymentMethod = 'COD'); })),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPaymentOption(title: 'COP', subtitle: 'Cash on Pickup', isSelected: _paymentMethod == 'COP', onTap: () { setSheetState(() => _paymentMethod = 'COP'); setState(() => _paymentMethod = 'COP'); })),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _instructionsController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Special Instructions (Optional)',
                    hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 32),
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal', style: AppTextStyles.bodyMedium),
                        Text(
                          '₱${subtotal.toStringAsFixed(2)}',
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Delivery Fee', style: AppTextStyles.bodyMedium),
                        Text(
                          deliveryFee > 0
                              ? '₱${deliveryFee.toStringAsFixed(2)}'
                              : 'Free',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: deliveryFee > 0 ? AppColors.textHeadline : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Amount', style: AppTextStyles.bodyLarge),
                        Text(
                          '₱${grandTotal.toStringAsFixed(2)}',
                          style: AppTextStyles.headline1.copyWith(
                            color: AppColors.primary,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_paymentMethod == 'COD' && _address == null || _isOrdering) ? null : () { Navigator.pop(sheetContext); _handleOrderNow(deliveryFee); },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: Text(_isOrdering ? 'Ordering...' : 'Confirm Order', style: AppTextStyles.headline3.copyWith(color: Colors.white, fontSize: 18)),
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

  Widget _buildFarmPickupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Farmer Location', style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary)),
              Text(widget.product.farmerName ?? 'AgriDirect Farmer', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
            ])),
            _buildMapButton(),
          ],
        ),
        const Divider(height: 24),
        Row(children: [
          const Icon(Icons.storefront_rounded, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.product.farm, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600))),
        ]),
      ],
    );
  }

  Widget _buildShippingAddressSection(StateSetter setSheetState) {
    if (_address == null) {
      return OutlinedButton.icon(
        onPressed: () async {
          final updated = await _openAddressEditor();
          if (updated != null && mounted) { setState(() => _address = updated); setSheetState(() {}); }
        },
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Address'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(_address!.label, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary)),
          const Spacer(),
          Text(_address!.recipientName, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        Text(_address!.street, style: AppTextStyles.bodyMedium),
        Text('${_address!.barangay}, ${_address!.city}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () async { final sel = await _openAddressSelector(); if (sel != null) { setState(() => _address = sel); setSheetState(() {}); } }, child: const Text('Change'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: () async { final upd = await _openAddressEditor(_address); if (upd != null) { setState(() => _address = upd); setSheetState(() {}); } }, child: const Text('Edit'))),
        ]),
      ],
    );
  }

  Future<void> _handleOrderNow(double deliveryFee) async {
    if (widget.product.productId == null || widget.product.farmerId == null) return;
    setState(() => _isOrdering = true);
    try {
      final unitPrice = double.tryParse(widget.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      await OrderService().createOfflineOrder(
        farmerId: widget.product.farmerId!,
        items: [OrderItemInput(productId: widget.product.productId!, quantity: _quantity.toDouble(), unitPrice: unitPrice)],
        paymentMethod: _paymentMethod,
        deliveryAddressId: _paymentMethod == 'COP' ? null : _address?.addressId,
        notes: _instructionsController.text.trim(),
        deliveryFee: deliveryFee,
      );
      if (!mounted) return;
      context.pushReplacement(AppRoutes.customerOrders);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isOrdering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rating = _getRating();
    final reviewCount = _getReviewCount();
    final farmerAvatarUrl = (widget.product.farmerImageUrl ?? widget.product.farmerAvatarUrl ?? '').trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _buildAppBarBtn(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
        actions: [
          _buildAppBarBtn(Icons.flag_outlined, _openProductReportDialog),
          _buildAppBarBtn(
            _isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            _toggleFavorite,
            iconColor: _isSaved ? Colors.redAccent : AppColors.textHeadline,
          ),
          _buildHeaderCart(),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          _buildImageGallery(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNamePriceSection(rating, reviewCount),
                const SizedBox(height: 24),
                _buildHarvestBadge(),
                const SizedBox(height: 28),
                _buildAboutSection(),
                const SizedBox(height: 28),
                _buildFarmerCard(farmerAvatarUrl),
                const SizedBox(height: 28),
                _buildQuantitySelector(),
                const SizedBox(height: 32),
                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarBtn(
    IconData icon,
    VoidCallback onTap, {
    Color iconColor = AppColors.textHeadline,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }

  Widget _buildHeaderCart() {
    return ListenableBuilder(
      listenable: CartService(),
      builder: (context, _) {
        final count = CartService().itemCount;
        return GestureDetector(
          key: _cartKey,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_outlined, size: 20, color: AppColors.textHeadline),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                      child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageGallery() {
    return Stack(
      children: [
        SizedBox(
          height: 320,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            child: widget.product.imageUrls.isNotEmpty
                ? PageView.builder(
                    itemCount: widget.product.imageUrls.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, i) => CachedNetworkImage(imageUrl: widget.product.imageUrls[i], fit: BoxFit.cover),
                  )
                : Hero(tag: 'product_image_${widget.product.productId}', child: CachedNetworkImage(imageUrl: widget.product.imageUrl, fit: BoxFit.cover)),
          ),
        ),
        if (widget.product.imageUrls.length > 1)
          Positioned(bottom: 20, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: widget.product.imageUrls.asMap().entries.map((e) => AnimatedContainer(duration: const Duration(milliseconds: 300), width: _currentPage == e.key ? 20 : 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: _currentPage == e.key ? Colors.white : Colors.white.withValues(alpha: 0.4)))).toList())),
      ],
    );
  }

  Widget _buildNamePriceSection(double? rating, int reviewCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.product.name, style: AppTextStyles.headline1.copyWith(fontSize: 28), overflow: TextOverflow.ellipsis),
          if (rating != null) ...[const SizedBox(height: 8), _buildStarRating(rating), Text('$rating ($reviewCount reviews)', style: AppTextStyles.bodySmall.copyWith(fontSize: 12))],
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(widget.product.price, style: AppTextStyles.headline1.copyWith(color: AppColors.primary, fontSize: 32)),
          Text('per ${widget.product.unit}', style: AppTextStyles.bodySmall),
        ]),
      ],
    );
  }

  Widget _buildHarvestBadge() {
    final days = int.tryParse(widget.product.harvestDays ?? '0') ?? 0;
    final label = days > 0 ? 'Harvest in $days days' : (widget.product.targetQuantity != null ? 'Pre-order' : 'Ready Now');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
      child: Row(children: [const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 18), const SizedBox(width: 8), Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600))]),
    );
  }

  Widget _buildAboutSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('About this product', style: AppTextStyles.headline3),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.1))), child: Text(_getDescription(), style: AppTextStyles.bodyMedium.copyWith(height: 1.6))),
    ]);
  }

  Widget _buildFarmerCard(String avatarUrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.1))),
      child: Row(children: [
        SafeCircleAvatar(imageUrl: avatarUrl, radius: 32, child: const Icon(Icons.agriculture_rounded, color: AppColors.primary)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Farm', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSubtle)),
          Text(widget.product.farm, style: AppTextStyles.headline3),
        ])),
        _buildMessageBtn(),
      ]),
    );
  }

  Widget _buildMessageBtn() {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.customerMessages, extra: {'farmerId': widget.product.farmerId, 'product': widget.product}),
      child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.message_rounded, color: Colors.white, size: 20)),
    );
  }

  Widget _buildQuantitySelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quantity', style: AppTextStyles.headline3),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.1))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _buildQtySelectorBtn(Icons.remove_rounded, _quantity > 1 ? () => setState(() => _quantity--) : null),
          Text('$_quantity ${widget.product.unit}', style: AppTextStyles.headline3),
          _buildQtySelectorBtn(Icons.add_rounded, () => setState(() => _quantity++)),
        ]),
      ),
    ]);
  }

  Widget _buildQtySelectorBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(14), child: Icon(icon, color: onTap != null ? AppColors.primary : AppColors.textSubtle.withValues(alpha: 0.3))));
  }

  Widget _buildActionButtons() {
    final isOwnProduct = AuthService().userId.isNotEmpty &&
        widget.product.farmerId == AuthService().userId;

    if (isOwnProduct) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This is your own product. You cannot order or add it to your cart.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          key: _addToCartBtnKey,
          onPressed: () {
            _runFlyToCartAnimation(_addToCartBtnKey, widget.product.imageUrl);
            CartService().addItem(widget.product, _quantity);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Added to cart'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          icon: const Icon(Icons.shopping_bag_rounded),
          label: const Text('Add to Cart'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: _isOrdering ? null : _showCheckoutSheet,
          icon: const Icon(Icons.flash_on_rounded),
          label: const Text('Order Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ]);
  }

  void _runFlyToCartAnimation(GlobalKey startKey, String imageUrl) {
    final RenderBox? buttonBox = startKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? cartBox = _cartKey.currentContext?.findRenderObject() as RenderBox?;

    if (buttonBox == null || cartBox == null) return;

    final startPosition = buttonBox.localToGlobal(Offset.zero);
    final endPosition = cartBox.localToGlobal(Offset.zero);

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _FlyingIconAnimation(
        startPosition: startPosition,
        endPosition: endPosition,
        imageUrl: imageUrl,
        onComplete: () => overlayEntry.remove(),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }

  Widget _buildStarRating(double rating) {
    return Row(children: List.generate(5, (i) => Icon(i + 1 <= rating ? Icons.star_rounded : (rating > i ? Icons.star_half_rounded : Icons.star_outline_rounded), color: AppColors.primary, size: 18)));
  }

  Widget _buildMapButton() { return _buildSmallBtn(Icons.map_outlined, 'View Map', _showFarmerMapSheet); }
  Widget _buildQtyBtn({required IconData icon, required VoidCallback onTap}) { return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.1))), child: Icon(icon, size: 16, color: AppColors.primary))); }

  Widget _buildSmallBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))), child: Row(children: [Icon(icon, size: 14, color: AppColors.primary), const SizedBox(width: 4), Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, fontSize: 10))])));
  }

  Widget _buildPaymentOption({required String title, required String subtitle, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? AppColors.primary : AppColors.textHeadline.withValues(alpha: 0.1), width: 2)), child: Column(children: [Text(title, style: AppTextStyles.headline3.copyWith(color: isSelected ? AppColors.primary : AppColors.textHeadline)), Text(subtitle, style: AppTextStyles.bodySmall.copyWith(fontSize: 9))])));
  }

  void _showFarmerMapSheet() {
    final lat = widget.product.latitude; final lng = widget.product.longitude;
    if (lat == null || lng == null) { _viewFarmOnMap(); return; }
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => Container(height: MediaQuery.of(context).size.height * 0.7, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))), child: Column(children: [Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))), Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}', style: AppTextStyles.headline1.copyWith(fontSize: 20)), Text('GPS Coordinates (Pickup)', style: AppTextStyles.bodySmall)])), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))])), Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Stack(children: [FlutterMap(options: MapOptions(initialCenter: LatLng(lat, lng), initialZoom: 15.5), children: [TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', subdomains: const ['a', 'b', 'c', 'd']), MarkerLayer(markers: [Marker(point: LatLng(lat, lng), width: 120, height: 80, child: Column(children: [Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)), child: Text('${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}', style: const TextStyle(color: Colors.white, fontSize: 10))), const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 36)]))])]), Positioned(bottom: 20, left: 20, right: 20, child: ElevatedButton.icon(onPressed: _viewFarmOnMap, icon: const Icon(Icons.navigation_rounded), label: const Text('Navigate to Farm'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))))]))))])));
  }

  void _viewFarmOnMap() async {
    final query = (widget.product.latitude != null && widget.product.longitude != null) ? '${widget.product.latitude},${widget.product.longitude}' : Uri.encodeComponent(widget.product.farm);
    final url = 'https://www.google.com/maps/search/?api=1&query=$query';
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<UserAddress?> _openAddressEditor([UserAddress? initial]) => showModalBottomSheet<UserAddress>(context: context, isScrollControlled: true, useRootNavigator: true, backgroundColor: Colors.transparent, builder: (context) => AddressEditorSheet(initialAddress: initial));
  Future<UserAddress?> _openAddressSelector() => showModalBottomSheet<UserAddress>(context: context, isScrollControlled: true, useRootNavigator: true, backgroundColor: Colors.transparent, builder: (context) => AddressSelectorSheet(currentAddressId: _address?.addressId));

  Future<void> _openProductReportDialog() async {
    final pid = widget.product.productId; if (pid == null) return;
    final sub = await showDialog<bool>(context: context, builder: (context) => ReportContentDialog(contentLabel: 'product', contentTitle: widget.product.name, onSubmit: (r, d) => SupabaseDataService().reportProduct(productId: pid, reason: r, description: d)));
    if (sub == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product reported.')));
  }
}

class AddressSelectorSheet extends StatefulWidget {
  final String? currentAddressId;
  const AddressSelectorSheet({super.key, this.currentAddressId});
  @override State<AddressSelectorSheet> createState() => _AddressSelectorSheetState();
}
class _AddressSelectorSheetState extends State<AddressSelectorSheet> {
  final UserService _userService = UserService(); List<UserAddress> _addresses = []; bool _isLoading = true;
  @override void initState() { super.initState(); _loadAddresses(); }
  Future<void> _loadAddresses() async { try { final list = await _userService.getAllUserAddresses(); if (mounted) setState(() => _addresses = list); } finally { if (mounted) setState(() => _isLoading = false); } }
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Text('Select Address', style: AppTextStyles.headline1.copyWith(fontSize: 22)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final nw = await showModalBottomSheet<UserAddress>(
                      context: context,
                      isScrollControlled: true,
                      useRootNavigator: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const AddressEditorSheet(),
                    );
                    if (nw != null && context.mounted) Navigator.pop(context, nw);
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add New'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_addresses.isEmpty
                    ? const Center(child: Text('No addresses found'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _addresses.length,
                        itemBuilder: (context, i) {
                          final addr = _addresses[i];
                          final sel = addr.addressId == widget.currentAddressId;
                          return GestureDetector(
                            onTap: () => Navigator.pop(context, addr),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: sel ? AppColors.primary.withValues(alpha: 0.1) : AppColors.background,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: sel ? AppColors.primary : Colors.transparent, width: 2),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: sel ? AppColors.primary : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      addr.label.toLowerCase() == 'home'
                                          ? Icons.home_rounded
                                          : (addr.label.toLowerCase() == 'office' ? Icons.work_rounded : Icons.location_on_rounded),
                                      color: sel ? Colors.white : AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(addr.label, style: AppTextStyles.headline3.copyWith(fontSize: 16)),
                                            if (addr.isDefault) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text('DEFAULT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(addr.street, style: AppTextStyles.bodySmall),
                                        Text('${addr.barangay}, ${addr.city}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
                                      ],
                                    ),
                                  ),
                                  if (sel) const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                                ],
                              ),
                            ),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }
}

class AddressEditorSheet extends StatefulWidget {
  final UserAddress? initialAddress;
  final bool? isDialog;
  const AddressEditorSheet({super.key, this.initialAddress, this.isDialog});

  @override
  State<AddressEditorSheet> createState() => _AddressEditorSheetState();
}

class _AddressEditorSheetState extends State<AddressEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labels = ['Home', 'Office', 'Farm', 'Warehouse', 'Other'];
  String _selectedLabel = 'Home';

  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _barangayController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();

  bool _isDefault = false;
  bool _isSaving = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _selectedLabel = _labels.contains(widget.initialAddress!.label)
          ? widget.initialAddress!.label
          : 'Other';
      _recipientController.text = widget.initialAddress!.recipientName;
      _phoneController.text = widget.initialAddress!.recipientPhone;
      _streetController.text = widget.initialAddress!.street;
      _barangayController.text = widget.initialAddress!.barangay;
      _cityController.text = widget.initialAddress!.city;
      _provinceController.text = widget.initialAddress!.province;
      _isDefault = widget.initialAddress!.isDefault;
      _latitude = widget.initialAddress!.latitude;
      _longitude = widget.initialAddress!.longitude;
    }
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _barangayController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your exact delivery location on the map'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final res = await UserService().upsertAddress(
        addressId: widget.initialAddress?.addressId,
        label: _selectedLabel,
        recipientName: _recipientController.text.trim(),
        recipientPhone: _phoneController.text.trim(),
        street: _streetController.text.trim(),
        barangay: _barangayController.text.trim(),
        city: _cityController.text.trim(),
        province: _provinceController.text.trim(),
        zipCode: '0000',
        isDefault: _isDefault,
        latitude: _latitude,
        longitude: _longitude,
      );
      if (mounted && res != null) Navigator.pop(context, res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openLocationPicker() async {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    Map<String, dynamic>? res;
    if (isMobile) {
      res = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const LocationPickerSheet(),
      );
    } else {
      res = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750, maxHeight: 600),
            child: const LocationPickerSheet(isDialog: true),
          ),
        ),
      );
    }

    final actualRes = res;
    if (actualRes != null && mounted) {
      setState(() {
        _latitude = actualRes['lat'];
        _longitude = actualRes['lng'];
        if (actualRes['address'] != null) {
          final ResolvedFarmLocation a = actualRes['address'];
          _streetController.text = a.street;
          _barangayController.text = a.barangay;
          _cityController.text = a.city;
          _provinceController.text = a.province;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    final useDialog = widget.isDialog ?? isWeb;

    // ─── Form content ────────────────────────────────────────────────────────
    Widget formContent = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.initialAddress == null
                          ? 'Add New Address'
                          : 'Edit Address',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHeadline,
                      ),
                    ),
                    Text(
                      'Fill in your delivery details below',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              if (useDialog)
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: AppColors.textSubtle,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Address Tag ──────────────────────────────────────────────────
          _buildSectionLabel('Address Tag'),
          const SizedBox(height: 8),
          _buildLabelSelector(),
          const SizedBox(height: 20),

          // ── Recipient details ────────────────────────────────────────────
          _buildSectionLabel('Recipient Details'),
          const SizedBox(height: 8),
          if (useDialog) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _buildField(
                  _recipientController,
                  'Recipient Name',
                  'Juan Dela Cruz',
                  icon: Icons.person_outline_rounded,
                )),
                const SizedBox(width: 14),
                Expanded(
                    child: _buildField(
                  _phoneController,
                  'Phone Number',
                  '09123456789',
                  keyboard: TextInputType.phone,
                  icon: Icons.phone_outlined,
                )),
              ],
            ),
          ] else ...[
            _buildField(
              _recipientController,
              'Recipient Name',
              'Juan Dela Cruz',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 14),
            _buildField(
              _phoneController,
              'Phone Number',
              '09123456789',
              keyboard: TextInputType.phone,
              icon: Icons.phone_outlined,
            ),
          ],
          const SizedBox(height: 20),

          // ── Address fields ───────────────────────────────────────────────
          _buildSectionLabel('Address Details'),
          const SizedBox(height: 8),
          if (useDialog) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _buildField(
                  _streetController,
                  'Street / House No.',
                  '123 Agri St.',
                  icon: Icons.home_outlined,
                )),
                const SizedBox(width: 14),
                Expanded(
                    child: _buildField(
                  _barangayController,
                  'Barangay',
                  'Brgy. San Jose',
                  icon: Icons.location_city_outlined,
                )),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _buildField(
                  _cityController,
                  'City',
                  'Cabanatuan',
                  icon: Icons.apartment_outlined,
                )),
                const SizedBox(width: 14),
                Expanded(
                    child: _buildField(
                  _provinceController,
                  'Province',
                  'Nueva Ecija',
                  icon: Icons.map_outlined,
                )),
              ],
            ),
          ] else ...[
            _buildField(
              _streetController,
              'Street / House No.',
              '123 Agri St.',
              icon: Icons.home_outlined,
            ),
            const SizedBox(height: 14),
            _buildField(
              _barangayController,
              'Barangay',
              'Brgy. San Jose',
              icon: Icons.location_city_outlined,
            ),
            const SizedBox(height: 14),
            _buildField(
              _cityController,
              'City',
              'Cabanatuan',
              icon: Icons.apartment_outlined,
            ),
            const SizedBox(height: 14),
            _buildField(
              _provinceController,
              'Province',
              'Nueva Ecija',
              icon: Icons.map_outlined,
            ),
          ],
          const SizedBox(height: 20),

          // ── Location pin ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (_latitude != null)
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : AppColors.error.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (_latitude != null)
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.error.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (_latitude != null)
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: (_latitude != null)
                        ? AppColors.primary
                        : AppColors.error,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Pin Location',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHeadline,
                        ),
                      ),
                      Text(
                        (_latitude != null)
                            ? '📍 ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                            : 'Tap "Select" to pin your location on the map',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: (_latitude != null)
                              ? AppColors.primary
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _openLocationPicker,
                  icon: Icon(
                    (_latitude != null)
                        ? Icons.edit_location_alt_rounded
                        : Icons.map_rounded,
                    size: 15,
                  ),
                  label: Text((_latitude != null) ? 'Change' : 'Select'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    textStyle: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Default toggle ───────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Set as default address',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHeadline,
                ),
              ),
              subtitle: Text(
                'Used automatically at checkout',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSubtle),
              ),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
              activeTrackColor: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),

          // ── Save button ──────────────────────────────────────────────────
          Row(
            children: [
              if (!useDialog) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: _isSaving
                    ? Container(
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primaryDark,
                              AppColors.primary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
                      )
                    : InkWell(
                        onTap: _save,
                        borderRadius: BorderRadius.circular(16),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primaryDark,
                                AppColors.primary,
                                Color(0xFF10B981),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            height: 54,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.save_alt_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Save Address',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );

    if (useDialog) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SingleChildScrollView(child: formContent),
      );
    }

    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: formContent,
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeadline,
          ),
        ),
      ],
    );
  }

  Widget _buildLabelSelector() {
    final icons = {
      'Home': Icons.home_rounded,
      'Office': Icons.business_rounded,
      'Farm': Icons.agriculture_rounded,
      'Warehouse': Icons.warehouse_rounded,
      'Other': Icons.location_on_rounded,
    };

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _labels.map((label) {
        final isSelected = _selectedLabel == label;
        return GestureDetector(
          onTap: () => setState(() => _selectedLabel = label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : const Color(0xFFE2E8F0),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icons[label] ?? Icons.location_on_rounded,
                  size: 15,
                  color: isSelected ? Colors.white : AppColors.textSubtle,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textHeadline,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType? keyboard,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSubtle,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textBody,
              fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(icon, size: 18, color: AppColors.textSubtle),
                  )
                : null,
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            hintStyle: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSubtle.withValues(alpha: 0.5)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.error, width: 2),
            ),
          ),
          validator: (v) =>
              (v == null || v.isEmpty) ? '$label is required' : null,
        ),
      ],
    );
  }
}

class LocationPickerSheet extends StatefulWidget {
  final bool isDialog;
  const LocationPickerSheet({super.key, this.isDialog = false});

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final MapController _mapController = MapController();
  LatLng _currentCenter = const LatLng(15.4828, 120.9714);
  bool _isLoading = true;
  bool _isResolving = false;
  ResolvedFarmLocation? _resolvedLocation;

  @override
  void initState() {
    super.initState();
    _moveToCurrentLocation();
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final nw = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _currentCenter = nw;
          _isLoading = false;
        });
        _mapController.move(nw, 16);
        _resolveAddress(nw);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveAddress(LatLng p) async {
    setState(() => _isResolving = true);
    try {
      final res = await ReverseGeocodingService.resolveFromCoordinates(
        latitude: p.latitude,
        longitude: p.longitude,
      );
      if (mounted) {
        setState(() {
          _resolvedLocation = res;
          _isResolving = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    final useDialog = widget.isDialog || isWeb;

    Widget body = Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(useDialog ? 24 : 32),
            bottom: Radius.circular(useDialog ? 24 : 0),
          ),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 16,
              onTap: (tp, p) {
                setState(() => _currentCenter = p);
                _mapController.move(p, _mapController.camera.zoom);
                _resolveAddress(p);
              },
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) setState(() => _currentCenter = pos.center);
              },
              onMapEvent: (ev) {
                if (ev is MapEventMoveEnd) _resolveAddress(_currentCenter);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.agridirect.app',
              )
            ],
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 35),
            child: Icon(
              Icons.location_on_rounded,
              color: AppColors.primary,
              size: 44,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ],
            ),
          ),
        ),
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  'Pin Delivery Location',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeadline,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton(
                onPressed: _moveToCurrentLocation,
                backgroundColor: Colors.white,
                mini: true,
                child: const Icon(Icons.my_location_rounded, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isResolving
                                ? 'Resolving Address...'
                                : (_resolvedLocation?.fullAddress.isNotEmpty == true
                                    ? _resolvedLocation!.fullAddress
                                    : 'Location: ${_currentCenter.latitude.toStringAsFixed(4)}, ${_currentCenter.longitude.toStringAsFixed(4)}'),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHeadline,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isResolving
                            ? null
                            : () => Navigator.pop(context, {
                                  'lat': _currentCenter.latitude,
                                  'lng': _currentCenter.longitude,
                                  'address': _resolvedLocation
                                }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Confirm Location',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: AppColors.primary))
      ],
    );

    if (useDialog) {
      return Container(
        height: 600,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: body,
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: body,
    );
  }
}
class _FlyingIconAnimation extends StatefulWidget {
  final Offset startPosition;
  final Offset endPosition;
  final String imageUrl;
  final VoidCallback onComplete;

  const _FlyingIconAnimation({
    required this.startPosition,
    required this.endPosition,
    required this.imageUrl,
    required this.onComplete,
  });

  @override
  State<_FlyingIconAnimation> createState() => _FlyingIconAnimationState();
}

class _FlyingIconAnimationState extends State<_FlyingIconAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _positionAnimation = Tween<Offset>(
      begin: widget.startPosition,
      end: widget.endPosition,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInQuint));

    _scaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.5), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.5, end: 0.3), weight: 70),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 80),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 20),
                    errorWidget: (context, url, error) => const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
