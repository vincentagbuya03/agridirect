import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'orders_screen.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/models/cached_product.dart';
import '../../../shared/services/offline/offline_cache_service.dart';
import '../../widgets/offline_browse_widget.dart';
import '../../widgets/skeleton_loaders.dart';
import '../../../shared/services/commerce/order_service.dart';
import 'package:agridirect/shared/widgets/image_widgets.dart';
import '../../../shared/services/user/user_service.dart';
import '../../../shared/models/auth/user_address_model.dart';
import '../../../shared/services/integration/reverse_geocoding_service.dart';

/// Marketplace Screen - Professional Digital Marketplace
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  int _selectedFilter = 0;
  final _filters = ['All Products', 'Vegetables', 'Fruits', 'Dairy', 'Grains'];
  bool _isOnline = true;
  late OfflineCacheService _cacheService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initializeCacheService();
    _setupConnectivityListener();
  }

  void _initializeCacheService() {
    _cacheService = OfflineCacheService();
  }

  void _setupConnectivityListener() {
    Connectivity().checkConnectivity().then((result) {
      final isOnline =
          result.isNotEmpty && result.first != ConnectivityResult.none;
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
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
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _openOrders() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OrdersScreen()));
  }

  void _openProductView(ProductItem product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductViewScreen(product: product)),
    );
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
                        Icons.eco_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AgriDirect',
                        style: AppTextStyles.headline1.copyWith(fontSize: 22),
                      ),
                    ],
                  ),
                  _buildHeaderCart(),
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
                          color: AppColors.primary.withValues(alpha: 0.2),
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

  Widget _buildHeaderCart() {
    return GestureDetector(
      onTap: _openOrders,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.textHeadline.withValues(alpha: 0.05),
          ),
        ),
        child: Stack(
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              color: AppColors.textHeadline,
              size: 24,
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
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
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: AppColors.textHeadline.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
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

  Widget _buildProductContent() {
    if (!_isOnline) {
      final cachedProducts = _cacheService
          .getAllCachedProducts()
          .where((p) => !p.isPreorder)
          .map(_cachedToProductItem)
          .toList();

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: OfflineModeIndicator(cacheService: _cacheService),
          ),
          Expanded(
            child: cachedProducts.isEmpty
                ? _buildNoCachedProductsState()
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

    // Online mode - fetch products and cache them
    return FutureBuilder<List<ProductItem>>(
      future: SupabaseDataService().getNearbyProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            child: ProductGridSkeleton(itemCount: 6, enabled: true),
          );
        }

        final products = snapshot.data ?? [];

        // Auto-cache products when loaded
        if (products.isNotEmpty) {
          for (final product in products) {
            final cachedProduct = CachedProduct(
              id: product.productId ?? 'unknown_${product.name}',
              farmerId: product.farmerId ?? '',
              name: product.name,
              price: _parsePrice(product.price),
              description: product.description,
              imageUrl: product.imageUrl,
              category: 'All',
              unit: product.unit,
              isPreorder: false,
              harvestDays: int.tryParse(product.harvestDays ?? '0') ?? 0,
              farmName: product.farm,
              rating: double.tryParse(product.rating ?? '0') ?? 0.0,
              farmerAvatarUrl: product.farmerAvatarUrl,
            );
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
              itemCount: products.length,
              itemBuilder: (_, i) => _buildProductCard(products[i]),
            ),
            _buildFloatingFilters(),
          ],
        );
      },
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
      rating: (product.rating ?? 0).toStringAsFixed(1),
      reviews: '0',
      harvestDays: product.harvestDays.toString(),
      farmerAvatarUrl: product.farmerAvatarUrl,
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
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border_rounded,
                      size: 16,
                      color: AppColors.textSubtle,
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
                      product.farm.split(',').first.toUpperCase(),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 18,
                            color: Colors.white,
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

  Future<UserAddress?> _openAddressEditor([UserAddress? initialAddress]) async {
    final streetController = TextEditingController(text: initialAddress?.street ?? '');
    final barangayController = TextEditingController(text: initialAddress?.barangay ?? '');
    final cityController = TextEditingController(text: initialAddress?.city ?? '');
    final provinceController = TextEditingController(text: initialAddress?.province ?? '');
    final zipCodeController = TextEditingController(text: initialAddress?.zipCode ?? '');
    final labelController = TextEditingController(text: initialAddress?.label ?? 'Home');
    final recipientNameController = TextEditingController(text: initialAddress?.recipientName ?? '');
    final recipientPhoneController = TextEditingController(text: initialAddress?.recipientPhone ?? '');

    bool isPinningLocation = false;
    bool isSavingAddress = false;
    bool isDefault = initialAddress?.isDefault ?? false;
    String? pinError;
    String? saveError;
    double? latitude = initialAddress?.latitude;
    double? longitude = initialAddress?.longitude;

    final savedAddress = await showModalBottomSheet<UserAddress>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setAddressState) => Container(
          height: MediaQuery.of(dialogContext).size.height * 0.9,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Handle and Close
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textHeadline.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 20, color: AppColors.textHeadline),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        initialAddress == null ? 'Add New Address' : 'Edit Address',
                        style: AppTextStyles.headline1.copyWith(fontSize: 24),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Where should we deliver your orders?',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSubtle),
                      ),
                      const SizedBox(height: 28),

                      // Section: Recipient
                      _buildSectionHeader('Recipient Information'),
                      const SizedBox(height: 16),
                      _buildAddressInputField(
                        controller: labelController,
                        label: 'Address Label',
                        hint: 'e.g. Home, Office, Farm',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAddressInputField(
                              controller: recipientNameController,
                              label: 'Full Name',
                              hint: 'Enter name',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildAddressInputField(
                              controller: recipientPhoneController,
                              label: 'Mobile Number',
                              hint: '09xx xxx xxxx',
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Section: Address
                      _buildSectionHeader('Delivery Address'),
                      const SizedBox(height: 16),
                      _buildAddressInputField(
                        controller: streetController,
                        label: 'Street / Building',
                        hint: 'House no., street name',
                      ),
                      const SizedBox(height: 16),
                      _buildAddressInputField(
                        controller: barangayController,
                        label: 'Barangay',
                        hint: 'Search barangay',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAddressInputField(
                              controller: cityController,
                              label: 'City / Town',
                              hint: 'Enter city',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildAddressInputField(
                              controller: provinceController,
                              label: 'Province',
                              hint: 'Enter province',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 140,
                        child: _buildAddressInputField(
                          controller: zipCodeController,
                          label: 'ZIP Code',
                          hint: 'Optional',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Settings
                      _buildSectionHeader('Settings'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Default Address', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text('Use this for future checkouts', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle, fontSize: 11)),
                                  ],
                                ),
                                Switch.adaptive(
                                  value: isDefault,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) => setAddressState(() => isDefault = val),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),
                            InkWell(
                              onTap: isPinningLocation
                                  ? null
                                  : () async {
                                      setAddressState(() {
                                        isPinningLocation = true;
                                        pinError = null;
                                      });

                                      try {
                                        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
                                        if (!serviceEnabled) {
                                          setAddressState(() {
                                            pinError = 'GPS is disabled.';
                                            isPinningLocation = false;
                                          });
                                          return;
                                        }

                                        var permission = await Geolocator.checkPermission();
                                        if (permission == LocationPermission.denied) {
                                          permission = await Geolocator.requestPermission();
                                        }

                                        if (permission == LocationPermission.denied ||
                                            permission == LocationPermission.deniedForever) {
                                          setAddressState(() {
                                            pinError = 'Location access denied.';
                                            isPinningLocation = false;
                                          });
                                          return;
                                        }

                                        final position = await Geolocator.getCurrentPosition(
                                          desiredAccuracy: LocationAccuracy.high,
                                        );

                                        final resolved = await ReverseGeocodingService.resolveFromCoordinates(
                                          latitude: position.latitude,
                                          longitude: position.longitude,
                                        );

                                        setAddressState(() {
                                          if (resolved.street.isNotEmpty) streetController.text = resolved.street;
                                          if (resolved.barangay.isNotEmpty) barangayController.text = resolved.barangay;
                                          if (resolved.city.isNotEmpty) cityController.text = resolved.city;
                                          if (resolved.province.isNotEmpty) provinceController.text = resolved.province;
                                          latitude = position.latitude;
                                          longitude = position.longitude;
                                          isPinningLocation = false;
                                        });
                                      } catch (_) {
                                        setAddressState(() {
                                          pinError = 'Failed to locate you.';
                                          isPinningLocation = false;
                                        });
                                      }
                                    },
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.my_location_rounded, size: 18, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isPinningLocation ? 'Locating...' : 'Auto-fill from GPS',
                                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary),
                                        ),
                                        Text(
                                          'Use current location to fill form',
                                          style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.textSubtle),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isPinningLocation)
                                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  else
                                    const Icon(Icons.chevron_right_rounded, color: AppColors.textSubtle),
                                ],
                              ),
                            ),
                            if (pinError != null) ...[
                              const SizedBox(height: 8),
                              Text(pinError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontSize: 11)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              // Footer Button
              Container(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + MediaQuery.of(dialogContext).viewInsets.bottom),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (saveError != null) ...[
                      Text(saveError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isSavingAddress
                            ? null
                            : () async {
                                final street = streetController.text.trim();
                                final barangay = barangayController.text.trim();
                                final city = cityController.text.trim();
                                final province = provinceController.text.trim();
                                final zipCode = zipCodeController.text.trim();
                                final label = labelController.text.trim();
                                final recipientName = recipientNameController.text.trim();
                                final recipientPhone = recipientPhoneController.text.trim();

                                if (street.isEmpty || barangay.isEmpty || city.isEmpty || province.isEmpty) {
                                  setAddressState(() => saveError = 'Please fill all required fields');
                                  return;
                                }

                                setAddressState(() {
                                  isSavingAddress = true;
                                  saveError = null;
                                });
                                
                                final savedAddress = await UserService().upsertAddress(
                                  addressId: initialAddress?.addressId,
                                  street: street,
                                  barangay: barangay,
                                  city: city,
                                  province: province,
                                  zipCode: zipCode,
                                  label: label,
                                  recipientName: recipientName,
                                  recipientPhone: recipientPhone,
                                  isDefault: isDefault,
                                  latitude: latitude,
                                  longitude: longitude,
                                );

                                if (!mounted) return;
                                if (savedAddress == null) {
                                  setAddressState(() {
                                    isSavingAddress = false;
                                    saveError = 'Service error. Try again.';
                                  });
                                  return;
                                }
                                Navigator.pop(dialogContext, savedAddress);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: isSavingAddress
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                initialAddress == null ? 'Save Address' : 'Update Details',
                                style: AppTextStyles.headline3.copyWith(color: Colors.white, fontSize: 16),
                              ),
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

    labelController.dispose();
    recipientNameController.dispose();
    recipientPhoneController.dispose();
    streetController.dispose();
    barangayController.dispose();
    cityController.dispose();
    provinceController.dispose();
    zipCodeController.dispose();

    return savedAddress;
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: AppTextStyles.labelSmall.copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: AppColors.textHeadline.withValues(alpha: 0.4),
      ),
    );
  }

  Future<UserAddress?> _openAddressSelector() async {
    final addresses = await UserService().getAllUserAddresses();

    if (!mounted) return null;

    return await showModalBottomSheet<UserAddress>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Address',
                  style: AppTextStyles.headline1.copyWith(fontSize: 22),
                ),
                IconButton(
                  onPressed: () async {
                    final newAddress = await _openAddressEditor();
                    if (newAddress != null && context.mounted) {
                      Navigator.pop(context, newAddress);
                    }
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: addresses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off_outlined, size: 64, color: AppColors.textSubtle.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text('No addresses found', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSubtle)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: addresses.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final addr = addresses[index];
                        final isSelected = _address?.addressId == addr.addressId;
                        return InkWell(
                          onTap: () => Navigator.pop(context, addr),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.textHeadline.withValues(alpha: 0.05),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            addr.label,
                                            style: AppTextStyles.headline3.copyWith(fontSize: 16),
                                          ),
                                          if (addr.isDefault) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'DEFAULT',
                                                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        addr.recipientName,
                                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        addr.fullAddress,
                                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      onPressed: () async {
                                        final updated = await _openAddressEditor(addr);
                                        if (updated != null && context.mounted) {
                                          Navigator.pop(context, updated);
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                                      onPressed: () async {
                                        final deleted = await _deleteAddress(addr.addressId);
                                        if (deleted && context.mounted) {
                                          Navigator.pop(context); 
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _deleteAddress(String addressId) async {
    try {
      final success = await UserService().deleteAddressById(addressId);
      if (!mounted) return false;
      if (success && _address?.addressId == addressId) {
        setState(() => _address = null);
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  void _showCheckoutSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Container(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Text(
                'Checkout Confirmation',
                style: AppTextStyles.headline1.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 20),

              // Product Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.textHeadline.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: widget.product.imageUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product.name,
                            style: AppTextStyles.headline3.copyWith(
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Quantity: $_quantity ${widget.product.unit}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSubtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Address Section
              Text(
                'Shipping Address',
                style: AppTextStyles.headline3.copyWith(
                  fontSize: 14,
                  color: AppColors.textHeadline,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.textHeadline.withValues(alpha: 0.05),
                  ),
                ),
                child: _isLoadingAddress
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _address == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No address set yet.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final updatedAddress = await _openAddressEditor();
                              if (!mounted) return;
                              if (updatedAddress != null) {
                                setState(() => _address = updatedAddress);
                                setSheetState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Shipping address updated.'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.add_location_alt_rounded),
                            label: const Text('Add Address'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _address!.label,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _address!.recipientName,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _address!.street,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${_address!.barangay}, ${_address!.city}, ${_address!.province}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSubtle,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final selected = await _openAddressSelector();
                                    if (selected != null && mounted) {
                                      setState(() => _address = selected);
                                      setSheetState(() {});
                                    }
                                  },
                                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                                  label: const Text('Change'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final updated = await _openAddressEditor(_address);
                                    if (updated != null && mounted) {
                                      setState(() => _address = updated);
                                      setSheetState(() {});
                                    }
                                  },
                                  icon: const Icon(Icons.edit_rounded, size: 18),
                                  label: const Text('Edit'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),

              // Payment Method
              Text(
                'Payment Method',
                style: AppTextStyles.headline3.copyWith(
                  fontSize: 14,
                  color: AppColors.textHeadline,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentOption(
                      title: 'COD',
                      subtitle: 'Cash on Delivery',
                      isSelected: _paymentMethod == 'COD',
                      onTap: () {
                        setSheetState(() => _paymentMethod = 'COD');
                        setState(() => _paymentMethod = 'COD');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPaymentOption(
                      title: 'COP',
                      subtitle: 'Cash on Pickup',
                      isSelected: _paymentMethod == 'COP',
                      onTap: () {
                        setSheetState(() => _paymentMethod = 'COP');
                        setState(() => _paymentMethod = 'COP');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Order Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Amount', style: AppTextStyles.bodyLarge),
                  Text(
                    '₱${(double.tryParse(widget.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0) * _quantity}',
                    style: AppTextStyles.headline1.copyWith(
                      color: AppColors.primary,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_address == null || _isOrdering)
                      ? null
                      : () {
                          Navigator.pop(sheetContext);
                          _handleOrderNow();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Confirm Order',
                    style: AppTextStyles.headline3.copyWith(
                      color: Colors.white,
                      fontSize: 18,
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

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textHeadline.withValues(alpha: 0.05),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: AppTextStyles.headline3.copyWith(
                fontSize: 16,
                color: isSelected ? AppColors.primary : AppColors.textHeadline,
              ),
            ),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 9,
                color: AppColors.textSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHeadline.withValues(alpha: 0.6),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSubtle.withValues(alpha: 0.3),
            ),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.textHeadline.withValues(alpha: 0.05),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleOrderNow() async {
    if (widget.product.productId == null || widget.product.farmerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product details are incomplete. Cannot place order.'),
        ),
      );
      return;
    }

    setState(() => _isOrdering = true);

    try {
      final orderService = OrderService();
      final normalizedPrice = widget.product.price.replaceAll(
        RegExp(r'[^0-9.]'),
        '',
      );
      final unitPrice = double.tryParse(normalizedPrice) ?? 0.0;

      await orderService.createOrder(
        farmerId: widget.product.farmerId!,
        items: [
          OrderItemInput(
            productId: widget.product.productId!,
            quantity: _quantity.toDouble(),
            unitPrice: unitPrice,
          ),
        ],
        paymentMethod: _paymentMethod,
        deliveryAddressId: _address?.addressId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order placed for $_quantity ${widget.product.unit} successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      // Navigate to orders screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OrdersScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      final rawMessage = e.toString().replaceFirst('Exception: ', '');
      final message = rawMessage.contains('Customer profile not found')
          ? 'Customer profile not found. Please complete your consumer profile first.'
          : rawMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order: $message'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isOrdering = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAddress();
    final imageUrl = widget.product.imageUrl.trim();
    if (imageUrl.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        precacheImage(CachedNetworkImageProvider(imageUrl), context);
      });
    }
  }

  double? _getRating() {
    if (widget.product.rating == null) return null;
    return double.tryParse(widget.product.rating!);
  }

  int _getReviewCount() {
    if (widget.product.reviews == null) return 0;
    return int.tryParse(widget.product.reviews!) ?? 0;
  }

  String _getDescription() {
    if (widget.product.description != null &&
        widget.product.description!.isNotEmpty) {
      return widget.product.description!;
    }
    return 'No product description available.';
  }

  Widget _buildStarRating(double rating) {
    return Row(
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final isFilled = rating >= starValue;
        final isHalf = rating > index && rating < starValue;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            isHalf
                ? Icons.star_half_rounded
                : isFilled
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            color: AppColors.primary,
            size: 18,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rating = _getRating();
    final reviewCount = _getReviewCount();
    final displayFarmName = (widget.product.farm).trim().isNotEmpty
        ? widget.product.farm.trim()
        : 'Unnamed Farm';
    final farmerAvatarUrl = (widget.product.farmerAvatarUrl ?? '').trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Added to favorites')),
              );
            },
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 20,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          // Product Image Gallery with Swipe
          Stack(
            children: [
              SizedBox(
                height: 320,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                  child: widget.product.imageUrls.isNotEmpty
                      ? PageView.builder(
                          itemCount: widget.product.imageUrls.length,
                          onPageChanged: (index) {
                            setState(() => _currentPage = index);
                          },
                          itemBuilder: (context, index) {
                            return CachedNetworkImage(
                              imageUrl: widget.product.imageUrls[index],
                              width: double.infinity,
                              height: 320,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[100],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            );
                          },
                        )
                      : CachedNetworkImage(
                          imageUrl: widget.product.imageUrl,
                          width: double.infinity,
                          height: 320,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              // Dot Indicators
              if (widget.product.imageUrls.length > 1)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: widget.product.imageUrls.asMap().entries.map((
                      entry,
                    ) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _currentPage == entry.key ? 20.0 : 8.0,
                        height: 8.0,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _currentPage == entry.key
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name and Rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product.name,
                            style: AppTextStyles.headline1.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (rating != null) ...[
                            const SizedBox(height: 8),
                            _buildStarRating(rating),
                            const SizedBox(height: 4),
                            Text(
                              '$rating ($reviewCount reviews)',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSubtle,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          widget.product.price,
                          style: AppTextStyles.headline1.copyWith(
                            color: AppColors.primary,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'per ${widget.product.unit}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSubtle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Harvest Days Badge
                if (widget.product.harvestDays != null)
                  Builder(
                    builder: (context) {
                      final days =
                          int.tryParse(widget.product.harvestDays!) ?? 0;
                      final isPreOrder = widget.product.targetQuantity != null;
                      final label = days > 0
                          ? 'Harvest in $days days'
                          : (isPreOrder ? 'Pre-order' : 'Ready Now');

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 28),

                // Product Description
                Text(
                  'About this product',
                  style: AppTextStyles.headline3.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.textHeadline.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Text(
                    _getDescription(),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textBody,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Farmer Details Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.textHeadline.withValues(alpha: 0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: SafeCircleAvatar(
                          imageUrl: farmerAvatarUrl,
                          radius: 32,
                          backgroundColor: Colors.transparent,
                          child: Icon(
                            Icons.agriculture_rounded,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Farm',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSubtle,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayFarmName,
                              style: AppTextStyles.headline3.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Contacting farmer...'),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.message_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Quantity Selector
                Text(
                  'Quantity',
                  style: AppTextStyles.headline3.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.textHeadline.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.remove_rounded,
                            color: _quantity > 1
                                ? AppColors.primary
                                : AppColors.textSubtle.withValues(alpha: 0.3),
                            size: 20,
                          ),
                        ),
                      ),
                      Text(
                        '$_quantity ${widget.product.unit}',
                        style: AppTextStyles.headline3.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _quantity++),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.add_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Add to Cart and Order Now Buttons
                Row(
                  children: [
                    // Add to Cart Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added $_quantity ${widget.product.unit} to cart',
                              ),
                              duration: const Duration(seconds: 2),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                        icon: const Icon(Icons.shopping_bag_rounded, size: 22),
                        label: Text(
                          'Add to Cart',
                          style: AppTextStyles.headline3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Order Now Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isOrdering ? null : _showCheckoutSheet,
                        icon: _isOrdering
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.flash_on_rounded, size: 22),
                        label: Text(
                          _isOrdering ? 'Ordering...' : 'Order Now',
                          style: AppTextStyles.headline3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
