import 'package:flutter/material.dart';
import '../../widgets/address_management_sheets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'cart_screen.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/data/app_data.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/models/cached_product.dart';
import '../../../shared/services/offline/offline_cache_service.dart';
import '../../../shared/services/commerce/order_service.dart';
import '../../../shared/services/commerce/cart_service.dart';
import 'package:agridirect/shared/widgets/image_widgets.dart';
import '../../../shared/widgets/flying_icon_animation.dart';
import '../../../shared/services/user/user_service.dart';
import '../../../shared/models/auth/user_address_model.dart';
import '../../../shared/models/farmer/farmer_profile_model.dart';
import '../../../shared/services/farmer/farmer_service.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/utils/share_util.dart';
import '../../../shared/widgets/report_content_dialog.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/widgets/share_bottom_sheet.dart';


/// Marketplace Screen - Professional Digital Marketplace
class ProductViewScreen extends StatefulWidget {
  final ProductItem product;
  final String? heroTag;
  const ProductViewScreen({super.key, required this.product, this.heroTag});

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
  final List<OverlayEntry> _flyingOverlayEntries = [];

  late ProductItem _product;
  bool _isLoadingProduct = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    if (_product.name.isEmpty && _product.productId != null && _product.productId!.isNotEmpty) {
      _loadProductDetails();
    }
    _ensureCacheServiceReady();
    _loadAddress();
    _cacheProductForOffline();
    _refreshSavedState();
  }

  Future<void> _loadProductDetails() async {
    setState(() => _isLoadingProduct = true);
    try {
      final fetched = await SupabaseDataService().getProductById(_product.productId!);
      if (mounted) {
        if (fetched != null) {
          setState(() {
            _product = fetched;
            _isLoadingProduct = false;
          });
        } else {
          setState(() => _isLoadingProduct = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product not found or is no longer available.'),
              backgroundColor: AppColors.error,
            ),
          );
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go(AppRoutes.home);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading deep linked product: $e');
      if (mounted) setState(() => _isLoadingProduct = false);
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
      debugPrint('âš ï¸ Failed to auto-cache product: $e');
    }
  }

  CachedProduct _buildCachedProduct() {
    final price =
        double.tryParse(
          _product.price.replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        0.0;
    return CachedProduct(
      id: _product.productId ?? 'unknown',
      farmerId: _product.farmerId ?? 'unknown',
      name: _product.name,
      price: price,
      description: _product.description,
      imageUrl: _product.imageUrl,
      availableQuantity: _product.targetQuantity?.toInt(),
      isPreorder: _product.targetQuantity != null,
      harvestDays: int.tryParse(_product.harvestDays ?? '0') ?? 0,
      farmName: _product.farm,
      unit: _product.unit,
      rating: double.tryParse(_product.rating ?? '0'),
      farmerAvatarUrl: _product.farmerAvatarUrl,
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

  double? _getRating() => _product.rating != null
      ? double.tryParse(_product.rating!)
      : null;
  int _getReviewCount() => _product.reviews != null
      ? int.tryParse(_product.reviews!) ?? 0
      : 0;
  String _getDescription() =>
      (_product.description != null &&
          _product.description!.isNotEmpty)
      ? _product.description!
      : 'No product description available.';

  void _showCheckoutSheet() async {
    final farmerId = widget.product.farmerId;
    FarmerProfile? farmerProfile;
    if (farmerId != null && farmerId.isNotEmpty) {
      try {
        farmerProfile = await FarmerService().getFarmerProfileByFarmerId(
          farmerId,
        );
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
          final price =
              double.tryParse(
                widget.product.price.replaceAll(RegExp(r'[^0-9.]'), ''),
              ) ??
              0.0;
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
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Checkout Confirmation',
                        style: AppTextStyles.headline1.copyWith(fontSize: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.textHeadline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: widget.product.imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: widget.product.imageUrl,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 64,
                                  height: 64,
                                  color: AppColors.background,
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: AppColors.textSubtle,
                                  ),
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
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Quantity:',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSubtle,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      _buildQtyBtn(
                                        icon: Icons.remove_rounded,
                                        onTap: () {
                                          if (_quantity > 1) {
                                            setState(() => _quantity--);
                                            setSheetState(() {});
                                          }
                                        },
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Text(
                                          '$_quantity',
                                          style: AppTextStyles.headline3
                                              .copyWith(fontSize: 16),
                                        ),
                                      ),
                                      _buildQtyBtn(
                                        icon: Icons.add_rounded,
                                        onTap: () {
                                          setState(() => _quantity++);
                                          setSheetState(() {});
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.product.unit,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          fontSize: 10,
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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(
                        _paymentMethod == 'COP' ? Icons.storefront_rounded : Icons.local_shipping_outlined,
                        size: 18,
                        color: AppColors.textHeadline,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _paymentMethod == 'COP'
                            ? 'Pickup Location (at Farm)'
                            : 'Shipping Address',
                        style: AppTextStyles.headline3.copyWith(
                          fontSize: 14,
                          color: AppColors.textHeadline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.textHeadline.withValues(alpha: 0.1),
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
                        : _paymentMethod == 'COP'
                        ? _buildFarmPickupSection()
                        : _buildShippingAddressSection(setSheetState),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.payment_rounded, size: 18, color: AppColors.textHeadline),
                      const SizedBox(width: 8),
                      Text(
                        'Payment Method',
                        style: AppTextStyles.headline3.copyWith(
                          fontSize: 14,
                          color: AppColors.textHeadline,
                        ),
                      ),
                    ],
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
                  const SizedBox(height: 20),
                  TextField(
                    controller: _instructionsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Special Instructions (Optional)',
                      hintStyle: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSubtle,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
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
                            '\u20B1${subtotal.toStringAsFixed(2)}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
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
                                ? '\u20B1${deliveryFee.toStringAsFixed(2)}'
                                : 'Free',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: deliveryFee > 0
                                  ? AppColors.textHeadline
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Amount', style: AppTextStyles.headline3.copyWith(fontSize: 18)),
                          Text(
                            '\u20B1${grandTotal.toStringAsFixed(2)}',
                            style: AppTextStyles.headline1.copyWith(
                              color: AppColors.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
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
                      onPressed:
                          (_paymentMethod == 'COD' && _address == null ||
                              _isOrdering)
                          ? null
                          : () async {
                              setSheetState(() {
                                _isOrdering = true;
                              });
                              await _handleOrderNow(deliveryFee);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isOrdering
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Placing Order...',
                                  style: AppTextStyles.headline3.copyWith(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            )
                          : Text(
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Farmer Location',
                    style: AppTextStyles.labelSmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    widget.product.farmerName ?? 'AgriDirect Farmer',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _buildMapButton(),
          ],
        ),
        const Divider(height: 24),
        Row(
          children: [
            const Icon(
              Icons.storefront_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.product.farm,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShippingAddressSection(StateSetter setSheetState) {
    if (_address == null) {
      return OutlinedButton.icon(
        onPressed: () async {
          final updated = await _openAddressEditor();
          if (updated != null && mounted) {
            setState(() => _address = updated);
            setSheetState(() {});
          }
        },
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Address'),
      );
    }
    return Column(
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
        Text(_address!.street, style: AppTextStyles.bodyMedium),
        Text(
          '${_address!.barangay}, ${_address!.city}',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final sel = await _openAddressSelector();
                  if (sel != null) {
                    setState(() => _address = sel);
                    setSheetState(() {});
                  }
                },
                child: const Text('Change'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final upd = await _openAddressEditor(_address);
                  if (upd != null) {
                    setState(() => _address = upd);
                    setSheetState(() {});
                  }
                },
                child: const Text('Edit'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleOrderNow(double deliveryFee) async {
    if (widget.product.productId == null || widget.product.farmerId == null) {
      return;
    }
    setState(() => _isOrdering = true);
    try {
      // Simulate/allow loading state transition
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      final unitPrice =
          double.tryParse(
            widget.product.price.replaceAll(RegExp(r'[^0-9.]'), ''),
          ) ??
          0.0;
      await OrderService().createOfflineOrder(
        farmerId: widget.product.farmerId!,
        items: [
          OrderItemInput(
            productId: widget.product.productId!,
            quantity: _quantity.toDouble(),
            unitPrice: unitPrice,
          ),
        ],
        paymentMethod: _paymentMethod,
        deliveryAddressId: _paymentMethod == 'COP' ? null : _address?.addressId,
        notes: _instructionsController.text.trim(),
        deliveryFee: deliveryFee,
      );
      if (!mounted) return;
      
      // Close checkout confirmation sheet
      Navigator.of(context).pop();

      // Route to our beautiful animated success page
      context.go(AppRoutes.orderSuccess, extra: widget.product.categoryName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isOrdering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProduct) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final rating = _getRating();
    final reviewCount = _getReviewCount();
    final farmerAvatarUrl =
        (_product.farmerImageUrl ?? _product.farmerAvatarUrl ?? '')
            .trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Shopee-like light gray background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _buildAppBarBtn(
          Icons.arrow_back_ios_new_rounded,
          () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        actions: [
          _buildAppBarBtn(Icons.flag_outlined, _openProductReportDialog),
          _buildAppBarBtn(
            _isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            _toggleFavorite,
            iconColor: _isSaved ? Colors.redAccent : Colors.white,
          ),
          _buildAppBarBtn(
            Icons.ios_share_rounded,
            () {
              if (widget.product.productId == null) return;
              final shareUrl = ShareUtil.generateProductShareLink(widget.product.productId!);
              
              ShareBottomSheet.show(
                context: context,
                shareUrl: shareUrl,
                title: 'Share Product',
                subtitle: 'Let others scan this QR code or share the link to this product.',
                shareSubject: 'Check out ${widget.product.name} on AgriDirect!',
              );
            },
          ),
          _buildHeaderCart(),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: _buildStickyBottomBar(),
      body: ListView(
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildImageGallery(),
          _buildPriceBanner(),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNamePriceSection(rating, reviewCount),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildShippingRow(),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: _buildHarvestBadge(),
          ),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            child: _buildFarmerCard(farmerAvatarUrl),
          ),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: _buildQuantitySelector(),
          ),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: _buildAboutSection(),
          ),
          const SizedBox(height: 8),
          _buildReviewsSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAppBarBtn(
    IconData icon,
    VoidCallback onTap, {
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(icon, size: 20, color: iconColor),
        ),
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
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CartScreen())),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Center(
                  child: Icon(
                    Icons.shopping_cart_outlined,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                if (count > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
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
                          height: 1.0,
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

  Widget _buildImageGallery() {
    return Stack(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.width, // Square image
          width: double.infinity,
          child: widget.product.imageUrls.isNotEmpty
              ? PageView.builder(
                  itemCount: widget.product.imageUrls.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, i) =>
                      widget.product.imageUrls[i].isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.product.imageUrls[i],
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: AppColors.background,
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.textSubtle,
                              size: 48,
                            ),
                          ),
                        ),
                )
              : widget.product.imageUrl.isNotEmpty
              ? (widget.heroTag != null 
                  ? Hero(
                      tag: widget.heroTag!,
                      child: CachedNetworkImage(
                        imageUrl: widget.product.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: widget.product.imageUrl,
                      fit: BoxFit.cover,
                    ))
              : Container(
                  color: AppColors.background,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.textSubtle,
                      size: 64,
                    ),
                  ),
                ),
        ),
        if (widget.product.imageUrls.length > 1)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_currentPage + 1}/${widget.product.imageUrls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPriceBanner() {
    return const SizedBox.shrink();
  }


  Widget _buildNamePriceSection(double? rating, int reviewCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                widget.product.price,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _toggleFavorite,
              child: Icon(
                _isSaved ? Icons.favorite_rounded : Icons.favorite_border,
                color: _isSaved ? Colors.redAccent : Colors.grey.shade600,
                size: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          widget.product.name,
          style: AppTextStyles.headline1.copyWith(fontSize: 18, height: 1.2),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (rating != null && rating > 0) ...[
              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
              const SizedBox(width: 4),
              Text(
                rating.toStringAsFixed(1),
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 12, color: Colors.grey.shade300),
              const SizedBox(width: 12),
            ],
            Text(
              '$reviewCount Reviews',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                if (widget.product.productId == null) return;
                final shareUrl = ShareUtil.generateProductShareLink(widget.product.productId!);
                ShareBottomSheet.show(
                  context: context,
                  shareUrl: shareUrl,
                  title: 'Share Product',
                  subtitle: 'Let others scan this QR code or share the link to this product.',
                  shareSubject: 'Check out ${widget.product.name} on AgriDirect!',
                );
              },
              child: Icon(Icons.share_outlined, color: Colors.grey.shade400, size: 20),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShippingRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Free Shipping',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Get up to \u20B140 if order arrives late',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 24),
        ],
      ),
    );
  }

  Widget _buildHarvestBadge() {
    final days = int.tryParse(widget.product.harvestDays ?? '0') ?? 0;
    final harvested = _isHarvested(widget.product);
    final isPreorder = widget.product.isPreorder && !harvested;

    final label = harvested
        ? 'Ready Now'
        : (days > 0
              ? 'Harvest in $days days'
              : (isPreorder ? 'Pre-order' : 'Ready Now'));

    final double? stock = isPreorder
        ? widget.product.targetQuantity
        : widget.product.stockQuantity;
    final double? reserved = widget.product.reservedQuantity;

    String stockText;
    if (isPreorder) {
      final double target = stock ?? 0;
      final double res = reserved ?? 0;
      stockText = '${res.toInt()} / ${target.toInt()} ordered';
    } else {
      final double available = stock ?? 0;
      stockText = available > 0
          ? '${available.toInt()} available'
          : 'Out of stock';
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPreorder
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : ((stock ?? 0) > 0
                        ? Colors.orange.withValues(alpha: 0.08)
                        : Colors.red.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPreorder
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : ((stock ?? 0) > 0
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPreorder
                      ? Icons.shopping_bag_outlined
                      : ((stock ?? 0) > 0
                            ? Icons.inventory_2_outlined
                            : Icons.info_outline),
                  color: isPreorder
                      ? AppColors.primary
                      : ((stock ?? 0) > 0
                            ? Colors.orange.shade800
                            : Colors.red),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stockText,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isPreorder
                          ? AppColors.primary
                          : ((stock ?? 0) > 0
                                ? Colors.orange.shade800
                                : Colors.red),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About this product', style: AppTextStyles.headline3),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.textHeadline.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            _getDescription(),
            style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
          ),
        ),
      ],
    );
  }

  Widget _buildFarmerCard(String avatarUrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          SafeCircleAvatar(
            imageUrl: avatarUrl,
            radius: 32,
            child: const Icon(
              Icons.storefront_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.farm.isNotEmpty ? widget.product.farm : 'Farm / Store',
                  style: AppTextStyles.headline3.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to view shop profile',
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              if (widget.product.farmerId != null) {
                context.push('${AppRoutes.farmerProfileBase}/${widget.product.farmerId}');
              }
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Visit',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Product Reviews', style: AppTextStyles.headline3),
              Text(
                'View All >',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'No reviews yet for this product.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSubtle),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    final isPreorder = widget.product.targetQuantity != null;
    final maxQty = isPreorder
        ? 999
        : (widget.product.stockQuantity?.toInt() ?? 0);
    final canAdd = isPreorder || _quantity < maxQty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quantity', style: AppTextStyles.headline3),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.textHeadline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQtySelectorBtn(
                Icons.remove_rounded,
                _quantity > 1 ? () => setState(() => _quantity--) : null,
              ),
              Text(
                '$_quantity ${widget.product.unit}',
                style: AppTextStyles.headline3,
              ),
              _buildQtySelectorBtn(
                Icons.add_rounded,
                canAdd ? () => setState(() => _quantity++) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQtySelectorBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        child: Icon(
          icon,
          color: onTap != null
              ? AppColors.primary
              : AppColors.textSubtle.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  bool _isHarvested(ProductItem product) {
    final days = int.tryParse(product.harvestDays ?? '');
    if (days == null) return false;
    if (days <= 0) return true;
    if (product.createdAt != null) {
      final harvestDate = product.createdAt!.add(Duration(days: days));
      final now = DateTime.now();
      return harvestDate.difference(now).isNegative;
    }
    return false;
  }

  Widget _buildStickyBottomBar() {
    final isOwnProduct =
        AuthService().userId.isNotEmpty &&
        widget.product.farmerId == AuthService().userId;

    if (isOwnProduct) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Text(
          'This is your own product.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary),
        ),
      );
    }

    final isPreOrder = widget.product.targetQuantity != null;
    final isOutOfStock =
        !widget.product.isPreorder && (widget.product.stockQuantity ?? 0) <= 0;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => context.push(
                      AppRoutes.customerMessages,
                      extra: {'farmerId': widget.product.farmerId, 'product': widget.product},
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 20),
                        const SizedBox(height: 2),
                        const Text(
                          'Chat',
                          style: TextStyle(fontSize: 10, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.grey.shade300),
                Expanded(
                  child: InkWell(
                    key: _addToCartBtnKey,
                    onTap: isOutOfStock
                        ? null
                        : () async {
                            _runFlyToCartAnimation(_addToCartBtnKey, widget.product.imageUrl);
                            final errorMsg = await CartService().addItem(
                              widget.product,
                              _quantity,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMsg ?? 'Added to cart'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_shopping_cart,
                          color: isOutOfStock ? Colors.grey : AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOutOfStock ? 'No Stock' : 'Add to Cart',
                          style: TextStyle(
                            fontSize: 10,
                            color: isOutOfStock ? Colors.grey : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: (isOutOfStock || _isOrdering) ? null : _showCheckoutSheet,
              child: Container(
                color: isOutOfStock ? Colors.grey.shade400 : AppColors.primary,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isPreOrder ? 'Pre-Order Now' : 'Order Now',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!isOutOfStock)
                      Text(
                        widget.product.price,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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



  Widget _buildMapButton() {
    return _buildSmallBtn(Icons.map_outlined, 'View Map', _showFarmerMapSheet);
  }

  Widget _buildQtyBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.textHeadline.withValues(alpha: 0.1),
          ),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }

  Widget _buildSmallBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontSize: 10,
              ),
            ),
          ],
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
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textHeadline.withValues(alpha: 0.1),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: AppTextStyles.headline3.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textHeadline,
              ),
            ),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  void _showFarmerMapSheet() {
    final lat = widget.product.latitude;
    final lng = widget.product.longitude;
    if (lat == null || lng == null) {
      _viewFarmOnMap();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                          style: AppTextStyles.headline1.copyWith(fontSize: 20),
                        ),
                        Text(
                          'GPS Coordinates (Pickup)',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(lat, lng),
                          initialZoom: 15.5,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(lat, lng),
                                width: 120,
                                height: 80,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.location_on_rounded,
                                      color: AppColors.primary,
                                      size: 36,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: ElevatedButton.icon(
                          onPressed: _viewFarmOnMap,
                          icon: const Icon(Icons.navigation_rounded),
                          label: const Text('Navigate to Farm'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewFarmOnMap() async {
    final query =
        (widget.product.latitude != null && widget.product.longitude != null)
        ? '${widget.product.latitude},${widget.product.longitude}'
        : Uri.encodeComponent(widget.product.farm);
    final url = 'https://www.google.com/maps/search/?api=1&query=$query';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<UserAddress?> _openAddressEditor([UserAddress? initial]) =>
      showModalBottomSheet<UserAddress>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (context) => AddressEditorSheet(initialAddress: initial),
      );
  Future<UserAddress?> _openAddressSelector() =>
      showModalBottomSheet<UserAddress>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            AddressSelectorSheet(currentAddressId: _address?.addressId),
      );

  Future<void> _openProductReportDialog() async {
    final pid = widget.product.productId;
    if (pid == null) return;
    final sub = await showDialog<bool>(
      context: context,
      builder: (context) => ReportContentDialog(
        contentLabel: 'product',
        contentTitle: widget.product.name,
        onSubmit: (r, d) => SupabaseDataService().reportProduct(
          productId: pid,
          reason: r,
          description: d,
        ),
      ),
    );
    if (sub == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product reported.')));
    }
  }
}
