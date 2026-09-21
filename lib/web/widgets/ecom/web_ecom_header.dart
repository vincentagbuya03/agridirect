import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/auth/user_address_model.dart';
import '../../../shared/services/user/user_service.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/commerce/cart_service.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../constants/web_design_tokens.dart';
import 'web_location_modal.dart';
import 'web_cart_flyout.dart';
import '../web_mobile_farmer_dialog.dart';
import '../../../shared/widgets/farmer/farmer_mode_switcher_capsule.dart';

/// 3-Tier Enterprise E-Commerce & Marketplace Header for AgriDirect Web
class WebEcomHeader extends StatefulWidget {
  final int currentIndex;
  final void Function(int, [String?]) onNavigate;
  final ValueChanged<String>? onSearch;
  final String? initialSearchQuery;

  const WebEcomHeader({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    this.onSearch,
    this.initialSearchQuery,
  });

  @override
  State<WebEcomHeader> createState() => _WebEcomHeaderState();
}

class _WebEcomHeaderState extends State<WebEcomHeader> {
  final TextEditingController _searchCtrl = TextEditingController();
  final LayerLink _cartLayerLink = LayerLink();
  final LayerLink _searchLayerLink = LayerLink();

  OverlayEntry? _cartOverlayEntry;
  OverlayEntry? _searchOverlayEntry;

  String _currentBarangay = 'Brgy. Roxas';
  UserAddress? _currentAddress;
  String _selectedCategoryScope = 'All';
  bool _isSearchFocused = false;

  final List<String> _popularSuggestions = [
    'Native Red Tomatoes',
    'Dinorado Rice (5kg)',
    'Fresh Tagalog Eggplant',
    'San Carlos Sweet Mango',
    'Organic Baguio Beans',
    'Native White Onion',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null) {
      _searchCtrl.text = widget.initialSearchQuery!;
    }
    _loadUserAddress();
  }

  Future<void> _loadUserAddress() async {
    final auth = AuthService();
    if (!auth.isLoggedIn) {
      if (mounted) {
        setState(() {
          _currentAddress = null;
        });
      }
      return;
    }

    try {
      final address = await UserService().getUserAddress();
      if (mounted) {
        setState(() {
          _currentAddress = address;
          if (address != null && address.barangay.isNotEmpty) {
            _currentBarangay = address.barangay;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading user address in header: $e');
    }
  }

  String get _displayLocationText {
    if (_currentAddress != null) {
      final b = _currentAddress!.barangay.trim();
      final c = _currentAddress!.city.trim();
      if (b.isNotEmpty && c.isNotEmpty) {
        return '$b, $c ▾';
      } else if (b.isNotEmpty) {
        return '$b ▾';
      } else if (c.isNotEmpty) {
        return '$c ▾';
      }
    }
    if (AuthService().isLoggedIn) {
      return 'Set Delivery Address ▾';
    }
    return '$_currentBarangay, San Carlos ▾';
  }

  @override
  void dispose() {
    _removeCartOverlay();
    _removeSearchOverlay();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showCartOverlay() {
    _removeCartOverlay();
    final overlay = Overlay.of(context);
    _cartOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 360,
        child: CompositedTransformFollower(
          link: _cartLayerLink,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 10),
          child: MouseRegion(
            onExit: (_) => _removeCartOverlay(),
            child: WebCartFlyout(
              onViewCart: () {
                _removeCartOverlay();
                widget.onNavigate(4, AppRoutes.cart);
              },
              onCheckout: () {
                _removeCartOverlay();
                widget.onNavigate(4, AppRoutes.cartCheckout);
              },
            ),
          ),
        ),
      ),
    );
    overlay.insert(_cartOverlayEntry!);
  }

  void _removeCartOverlay() {
    _cartOverlayEntry?.remove();
    _cartOverlayEntry = null;
  }

  void _showSearchOverlay() {
    _removeSearchOverlay();
    final overlay = Overlay.of(context);
    _searchOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 540,
        child: CompositedTransformFollower(
          link: _searchLayerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: TapRegion(
            onTapOutside: (_) => _removeSearchOverlay(),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(14),
              color: WebDesignTokens.surface,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: WebDesignTokens.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.trending_up_rounded,
                            size: 16,
                            color: WebDesignTokens.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Popular Harvest Searches',
                            style: GoogleFonts.rubik(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: WebDesignTokens.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 12, color: WebDesignTokens.border),
                    ..._popularSuggestions.map(
                      (item) => ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: WebDesignTokens.slate400,
                        ),
                        title: Text(
                          item,
                          style: GoogleFonts.nunitoSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: WebDesignTokens.dark,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.north_west_rounded,
                          size: 14,
                          color: WebDesignTokens.slate400,
                        ),
                        onTap: () {
                          _searchCtrl.text = item;
                          _removeSearchOverlay();
                          _triggerSearch(item);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_searchOverlayEntry!);
  }

  void _removeSearchOverlay() {
    _searchOverlayEntry?.remove();
    _searchOverlayEntry = null;
  }

  void _triggerSearch(String query) {
    if (widget.onSearch != null) {
      widget.onSearch!(query);
    } else {
      widget.onNavigate(1, AppRoutes.shop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isCompact = sw < 1024;
    final isMobile = sw < 768;

    return ListenableBuilder(
      listenable: Listenable.merge([AuthService(), CartService()]),
      builder: (context, _) {
        final auth = AuthService();
        final cart = CartService();

        return Container(
          decoration: BoxDecoration(
            color: WebDesignTokens.surface,
            border: Border(
              bottom: BorderSide(
                color: WebDesignTokens.border.withValues(alpha: 0.8),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── TIER 1: Utility Strip (Desktop) ───
              if (!isMobile) _buildUtilityStrip(context),

              // ─── TIER 2: Main Omnibar Header ───
              _buildMainOmnibar(context, auth, cart, isCompact, isMobile),

              // ─── TIER 3: Mobile Quick Navigation Strip (Mobile) ───
              if (isMobile) _buildMobileQuickNavStrip(context),

              // ─── TIER 4: Department Mega-Menu Bar (Desktop) ───
              if (!isMobile) _buildDepartmentMegaMenu(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUtilityStrip(BuildContext context) {
    final auth = AuthService();
    return Container(
      color: WebDesignTokens.bg,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Location selector
          InkWell(
            onTap: () {
              WebLocationModal.show(
                context,
                currentAddress: _currentAddress,
                currentLocation: _currentAddress?.barangay ?? _currentBarangay,
                onAddressUpdated: (addr) {
                  setState(() {
                    _currentAddress = addr;
                    if (addr != null && addr.barangay.isNotEmpty) {
                      _currentBarangay = addr.barangay;
                    }
                  });
                },
                onLocationSelected: (loc) {
                  setState(() => _currentBarangay = loc);
                },
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 15,
                    color: WebDesignTokens.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Deliver to: ',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      color: WebDesignTokens.slate500,
                    ),
                  ),
                  Text(
                    _displayLocationText,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: WebDesignTokens.dark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center: Ticker
          Row(
            children: [
              const Icon(
                Icons.eco_rounded,
                size: 14,
                color: WebDesignTokens.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '100% Farm-Direct from Pangasinan Growers • Free Delivery on orders ₱500+',
                style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: WebDesignTokens.primaryDark,
                ),
              ),
            ],
          ),

          Row(
            children: [
              _buildUtilityLink('Community', () {
                context.go(AppRoutes.community);
              }),
              _buildUtilityDivider(),
              _buildUtilityLink('Find Farmer', () {
                context.go(AppRoutes.farmersMap);
              }),
              _buildUtilityDivider(),
              _buildUtilityLink('Weather', () {
                context.go(AppRoutes.weatherRadar);
              }),
              _buildUtilityDivider(),
              _buildUtilityLink('DA Articles', () {
                context.go(AppRoutes.articles);
              }),
              _buildUtilityDivider(),
              _buildUtilityLink('About Us', () {
                context.go(AppRoutes.aboutUs);
              }),
              _buildUtilityDivider(),
              if (auth.isAdmin) ...[
                _buildUtilityLink(
                  'Admin Portal',
                  () => context.go(AppRoutes.admin),
                  icon: Icons.admin_panel_settings_rounded,
                  isHighlighted: true,
                ),
                _buildUtilityDivider(),
              ],
              _buildUtilityLink('Farmer Portal', () {
                final auth = AuthService();
                if (auth.isLoggedIn) {
                  if (auth.isViewingAsFarmer) {
                    auth.switchToCustomerMode();
                    context.go(AppRoutes.marketplace);
                  } else if (auth.isSeller) {
                    auth.switchToFarmerMode();
                    context.go(AppRoutes.farmerDashboard);
                  } else {
                    WebMobileFarmerDialog.show(context);
                  }
                } else {
                  context.go(AppRoutes.login);
                }
              }),
              _buildUtilityDivider(),
              _buildUtilityLink('Track Harvest', () {
                final auth = AuthService();
                if (auth.isLoggedIn) {
                  context.go(AppRoutes.customerOrders);
                } else {
                  context.go(AppRoutes.login);
                }
              }),
              _buildUtilityDivider(),
              _buildUtilityLink('Help & FAQs', () {
                context.go(AppRoutes.faqs);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityLink(
    String title,
    VoidCallback onTap, {
    IconData? icon,
    bool isHighlighted = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isHighlighted
                    ? const Color(0xFF7C3AED)
                    : WebDesignTokens.slate600,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              title,
              style: GoogleFonts.nunitoSans(
                fontSize: 12,
                fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
                color: isHighlighted
                    ? const Color(0xFF7C3AED)
                    : WebDesignTokens.slate600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUtilityDivider() {
    return Container(
      height: 10,
      width: 1,
      color: WebDesignTokens.border,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildMainOmnibar(
    BuildContext context,
    AuthService auth,
    CartService cart,
    bool isCompact,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 12,
      ),
      child: Row(
        children: [
          // Logo (taps to Home / Welcome)
          InkWell(
            onTap: () => context.go(AppRoutes.webWelcome),
            borderRadius: BorderRadius.circular(8),
            child: BrandLogo(
              size: isMobile ? BrandLogoSize.small : BrandLogoSize.medium,
              showText: true,
            ),
          ),
          SizedBox(width: isMobile ? 8 : 24),

          // Omnibar Search Area
          if (!isMobile)
            Expanded(
              child: CompositedTransformTarget(
                link: _searchLayerLink,
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: WebDesignTokens.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSearchFocused
                          ? WebDesignTokens.primary
                          : WebDesignTokens.border,
                      width: _isSearchFocused ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Category Scoper Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: WebDesignTokens.border.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategoryScope,
                            icon: const Icon(
                              Icons.arrow_drop_down_rounded,
                              color: WebDesignTokens.slate500,
                            ),
                            style: GoogleFonts.nunitoSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: WebDesignTokens.dark,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'All',
                                child: Text('All Harvests'),
                              ),
                              DropdownMenuItem(
                                value: 'Vegetables',
                                child: Text('Vegetables'),
                              ),
                              DropdownMenuItem(
                                value: 'Fruits',
                                child: Text('Fruits'),
                              ),
                              DropdownMenuItem(
                                value: 'Grains',
                                child: Text('Grains & Rice'),
                              ),
                              DropdownMenuItem(
                                value: 'Organic',
                                child: Text('Organic'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCategoryScope = val);
                              }
                            },
                          ),
                        ),
                      ),

                      // Text Field
                      Expanded(
                        child: Focus(
                          onFocusChange: (focused) {
                            setState(() => _isSearchFocused = focused);
                            if (focused) {
                              _showSearchOverlay();
                            }
                          },
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText:
                                  'Search fresh crops, cooperatives, or farmers (e.g. Dinorado, Native Tomato)...',
                              hintStyle: GoogleFonts.nunitoSans(
                                fontSize: 13,
                                color: WebDesignTokens.slate400,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        size: 16,
                                        color: WebDesignTokens.slate400,
                                      ),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        _triggerSearch('');
                                      },
                                    )
                                  : null,
                            ),
                            onSubmitted: _triggerSearch,
                          ),
                        ),
                      ),

                      // Search CTA Button
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: WebDesignTokens.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _triggerSearch(_searchCtrl.text),
                          child: const Icon(Icons.search_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const Spacer(),

          const SizedBox(width: 20),

          // Right Action Cluster
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Chat & Notifications (hidden on narrow screens to prevent overflow)
              if (!isMobile) ...[
                IconButton(
                  tooltip: 'Farmer Chat',
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: WebDesignTokens.slate700,
                  ),
                  onPressed: () => widget.onNavigate(0, AppRoutes.messages),
                ),
                IconButton(
                  tooltip: 'Notifications',
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: WebDesignTokens.slate700,
                  ),
                  onPressed: () =>
                      widget.onNavigate(0, AppRoutes.notifications),
                ),
              ],

              // Cart Button
              if (isMobile)
                IconButton(
                  tooltip: 'Shopping Cart',
                  icon: Badge(
                    label: Text('${cart.itemCount}'),
                    isLabelVisible: cart.itemCount > 0,
                    backgroundColor: WebDesignTokens.primary,
                    textColor: Colors.white,
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      size: 24,
                      color: WebDesignTokens.primaryDark,
                    ),
                  ),
                  onPressed: () => widget.onNavigate(4, AppRoutes.cart),
                )
              else
                CompositedTransformTarget(
                  link: _cartLayerLink,
                  child: MouseRegion(
                    onEnter: (_) => _showCartOverlay(),
                    child: InkWell(
                      onTap: () => widget.onNavigate(4, AppRoutes.cart),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: WebDesignTokens.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: WebDesignTokens.primary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Badge(
                              label: Text('${cart.itemCount}'),
                              isLabelVisible: cart.itemCount > 0,
                              backgroundColor: WebDesignTokens.primary,
                              textColor: Colors.white,
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                                size: 22,
                                color: WebDesignTokens.primaryDark,
                              ),
                            ),
                            if (!isCompact) ...[
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'My Cart',
                                    style: GoogleFonts.nunitoSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: WebDesignTokens.slate500,
                                    ),
                                  ),
                                  Text(
                                    '₱${cart.totalAmount.toStringAsFixed(0)}',
                                    style: GoogleFonts.rubik(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: WebDesignTokens.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              SizedBox(width: isMobile ? 6 : 14),

              // Quick Farmer Mode Switcher Pill
              if (auth.isSeller || auth.isViewingAsFarmer) ...[
                FarmerModeSwitcherCapsule(
                  compact: true,
                  isFarmerMode: auth.isViewingAsFarmer,
                  onSwitch: () {
                    if (auth.isViewingAsFarmer) {
                      auth.switchToCustomerMode();
                      widget.onNavigate(0, AppRoutes.marketplace);
                    } else {
                      auth.switchToFarmerMode();
                      widget.onNavigate(0, AppRoutes.farmerDashboard);
                    }
                  },
                ),
                SizedBox(width: isMobile ? 6 : 12),
              ],

              // User Profile or Login
              if (auth.isLoggedIn)
                PopupMenuButton<String>(
                  offset: const Offset(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: isMobile ? 15 : 18,
                        backgroundColor: WebDesignTokens.primary,
                        backgroundImage: auth.userAvatarUrl.trim().isNotEmpty
                            ? NetworkImage(auth.userAvatarUrl.trim())
                            : null,
                        child: auth.userAvatarUrl.trim().isEmpty
                            ? Text(
                                auth.userName.isNotEmpty
                                    ? auth.userName[0].toUpperCase()
                                    : 'U',
                                style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontSize: isMobile ? 11 : 14,
                                ),
                              )
                            : null,
                      ),
                      if (!isCompact) ...[
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 130),
                          child: Text(
                            auth.userName.isNotEmpty
                                ? _formatShortName(auth.userName)
                                : 'My Account',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunitoSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: WebDesignTokens.dark,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                      ],
                    ],
                  ),
                  onSelected: (val) {
                    switch (val) {
                      case 'admin':
                        context.go(AppRoutes.admin);
                        break;
                      case 'profile':
                        widget.onNavigate(3, AppRoutes.profile);
                        break;
                      case 'orders':
                        context.go(AppRoutes.customerOrders);
                        break;
                      case 'toggle':
                        if (auth.isViewingAsFarmer) {
                          auth.switchToCustomerMode();
                          widget.onNavigate(0, AppRoutes.marketplace);
                        } else if (auth.isSeller) {
                          auth.switchToFarmerMode();
                          widget.onNavigate(0, AppRoutes.farmerDashboard);
                        } else {
                          WebMobileFarmerDialog.show(context);
                        }
                        break;
                      case 'logout':
                        auth.logout();
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.userName.isNotEmpty
                                ? auth.userName
                                : 'My Account',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.rubik(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: WebDesignTokens.dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            auth.isAdmin
                                ? 'Administrator'
                                : (auth.isViewingAsFarmer
                                    ? 'Farmer Mode'
                                    : 'Consumer Mode'),
                            style: GoogleFonts.nunitoSans(
                              fontSize: 11,
                              fontWeight: auth.isAdmin ? FontWeight.w700 : FontWeight.normal,
                              color: auth.isAdmin
                                  ? const Color(0xFF7C3AED)
                                  : WebDesignTokens.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    if (auth.isAdmin)
                      PopupMenuItem(
                        value: 'admin',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.admin_panel_settings_rounded,
                              size: 18,
                              color: Color(0xFF7C3AED),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Admin Dashboard',
                              style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF7C3AED),
                              ),
                            ),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 18),
                          const SizedBox(width: 10),
                          Text('My Profile', style: GoogleFonts.nunitoSans()),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'orders',
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            'My Orders & Deliveries',
                            style: GoogleFonts.nunitoSans(),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            auth.isViewingAsFarmer
                                ? Icons.swap_horiz_rounded
                                : (auth.isSeller
                                      ? Icons.storefront_rounded
                                      : Icons.agriculture_rounded),
                            size: 18,
                            color: auth.isSeller || auth.isViewingAsFarmer
                                ? null
                                : WebDesignTokens.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            auth.isViewingAsFarmer
                                ? 'Switch to Buyer Mode'
                                : (auth.isSeller
                                      ? 'Switch to Farmer Mode'
                                      : 'Become a Farmer'),
                            style: GoogleFonts.nunitoSans(
                              fontWeight:
                                  !auth.isSeller && !auth.isViewingAsFarmer
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: !auth.isSeller && !auth.isViewingAsFarmer
                                  ? WebDesignTokens.primary
                                  : WebDesignTokens.dark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            size: 18,
                            color: WebDesignTokens.discountRed,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Log Out',
                            style: GoogleFonts.nunitoSans(
                              color: WebDesignTokens.discountRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WebDesignTokens.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 18,
                      vertical: isMobile ? 8 : 12,
                    ),
                  ),
                  onPressed: () => context.go(AppRoutes.login),
                  child: Text(
                    'Sign In',
                    style: GoogleFonts.rubik(
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentMegaMenu() {
    final isHomeActive = widget.currentIndex == -1;
    final isMarketplaceActive = widget.currentIndex == 0;

    final mainNavButtons = [
      {
        'label': 'Home',
        'icon': Icons.home_rounded,
        'route': AppRoutes.webWelcome,
        'isActive': isHomeActive,
      },
      {
        'label': 'Marketplace',
        'icon': Icons.storefront_rounded,
        'route': AppRoutes.marketplace,
        'isActive': isMarketplaceActive,
      },
    ];

    final produceLinks = [
      {
        'label': '🥬 Vegetables',
        'route': '${AppRoutes.shop}?category=Vegetables',
      },
      {'label': '🍎 Fruits', 'route': '${AppRoutes.shop}?category=Fruits'},
      {
        'label': '🌾 Rice & Grains',
        'route': '${AppRoutes.shop}?category=Grains',
      },
      {'label': '⚡ Flash Deals', 'route': AppRoutes.flashSale},
      {'label': '📦 Pre-Orders', 'route': AppRoutes.preorders},
      {'label': '🚜 Farm Shops', 'route': AppRoutes.localShops},
    ];

    final serviceLinks = [
      {'label': '🌾 Find Farmer', 'route': AppRoutes.farmersMap},
      {'label': '💬 Community', 'route': AppRoutes.community},
      {'label': '🌦️ Weather Radar', 'route': AppRoutes.weatherRadar},
      {'label': 'ℹ️ About Us', 'route': AppRoutes.aboutUs},
      {'label': '✨ Welcome Tour', 'route': AppRoutes.webWelcome},
    ];

    return Container(
      decoration: BoxDecoration(
        color: WebDesignTokens.surface,
        border: Border(
          top: BorderSide(color: WebDesignTokens.border.withValues(alpha: 0.5)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Main Nav + Produce & Harvest Departments
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // 1. Primary Site Navigation: Home & Marketplace
                  ...mainNavButtons.map((btn) {
                    final isActive = btn['isActive'] as bool;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => context.go(btn['route'] as String),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? WebDesignTokens.primary.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isActive
                                    ? WebDesignTokens.primary.withValues(alpha: 0.4)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  btn['icon'] as IconData,
                                  size: 15,
                                  color: isActive
                                      ? WebDesignTokens.primaryDark
                                      : WebDesignTokens.slate600,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  btn['label'] as String,
                                  style: GoogleFonts.nunitoSans(
                                    fontSize: 13,
                                    fontWeight: isActive
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    color: isActive
                                        ? WebDesignTokens.primaryDark
                                        : WebDesignTokens.dark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Subtle divider between Site Navigation and Categories
                  Container(
                    height: 18,
                    width: 1.2,
                    margin: const EdgeInsets.only(left: 4, right: 8),
                    color: WebDesignTokens.border,
                  ),

                  // 2. Department & Category Links
                  ...produceLinks.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: WebDesignTokens.dark,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => context.go(cat['route']!),
                        child: Text(
                          cat['label']!,
                          style: GoogleFonts.nunitoSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Right: Community & Agricultural Services
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: serviceLinks.map((svc) {
                final isSpecial =
                    svc['label']!.contains('Community') ||
                    svc['label']!.contains('Find Farmer');
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: isSpecial
                          ? WebDesignTokens.primaryDark
                          : WebDesignTokens.slate600,
                      backgroundColor: isSpecial
                          ? WebDesignTokens.primaryLight.withValues(alpha: 0.5)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => context.go(svc['route']!),
                    child: Text(
                      svc['label']!,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 12.5,
                        fontWeight: isSpecial
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileQuickNavStrip(BuildContext context) {
    final navLinks = [
      {
        'label': 'Home',
        'icon': Icons.home_rounded,
        'action': () => context.go(AppRoutes.webWelcome),
      },
      {
        'label': 'Marketplace',
        'icon': Icons.storefront_rounded,
        'action': () => context.go(AppRoutes.marketplace),
      },
      {
        'label': 'Community',
        'icon': Icons.forum_outlined,
        'action': () => context.go(AppRoutes.community),
      },
      {
        'label': 'Find Farmer',
        'icon': Icons.map_outlined,
        'action': () => context.go(AppRoutes.farmersMap),
      },
      {
        'label': 'Weather',
        'icon': Icons.cloud_outlined,
        'action': () => context.go(AppRoutes.weatherRadar),
      },
      {
        'label': 'DA Articles',
        'icon': Icons.article_outlined,
        'action': () => context.go(AppRoutes.articles),
      },
      {
        'label': 'About Us',
        'icon': Icons.info_outline_rounded,
        'action': () => context.go(AppRoutes.aboutUs),
      },
      {
        'label': 'Track Harvest',
        'icon': Icons.local_shipping_outlined,
        'action': () {
          final auth = AuthService();
          if (auth.isLoggedIn) {
            context.go(AppRoutes.customerOrders);
          } else {
            context.go(AppRoutes.login);
          }
        },
      },
      {
        'label': 'Help & FAQs',
        'icon': Icons.help_outline_rounded,
        'action': () => context.go(AppRoutes.faqs),
      },
    ];

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: WebDesignTokens.bg,
        border: Border(
          top: BorderSide(color: WebDesignTokens.border.withValues(alpha: 0.7)),
          bottom: BorderSide(
            color: WebDesignTokens.border.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: navLinks.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final link = navLinks[i];
          final label = link['label'] as String;
          final icon = link['icon'] as IconData;
          final action = link['action'] as VoidCallback;

          return InkWell(
            onTap: action,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: WebDesignTokens.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: WebDesignTokens.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: WebDesignTokens.primary),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: WebDesignTokens.dark,
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

  String _formatShortName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'My Account';
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'My Account';

    String cap(String s) =>
        s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

    if (parts.length == 1) {
      final single = cap(parts[0]);
      return single.length > 14 ? '${single.substring(0, 12)}...' : single;
    }

    final first = cap(parts.first);
    final lastInitial = parts.last[0].toUpperCase();
    return '$first $lastInitial.';
  }
}
