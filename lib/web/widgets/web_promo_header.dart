import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../shared/services/commerce/cart_service.dart';
import '../../shared/services/auth/auth_service.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/router/app_routes.dart';

class WebPromoHeader extends StatefulWidget {
  final String activeTab; // 'free_shipping', 'flash_sale', 'vouchers', 'fresh_produce', 'wholesale', 'local_shops'
  final ValueChanged<String>? onSearchChanged;
  final String searchPlaceholder;

  const WebPromoHeader({
    super.key,
    required this.activeTab,
    this.onSearchChanged,
    this.searchPlaceholder = 'Search farm fresh produce, wholesale crops, seeds...',
  });

  @override
  State<WebPromoHeader> createState() => _WebPromoHeaderState();
}

class _WebPromoHeaderState extends State<WebPromoHeader> {
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _channels = [
    {
      'id': 'fresh_produce',
      'label': '🌾 Fresh Produce',
      'route': '/fresh-produce',
      'color': const Color(0xFF059669),
    },
    {
      'id': 'flash_sale',
      'label': '⚡ Flash Sale',
      'route': '/flash-sale',
      'color': const Color(0xFFDC2626),
    },
    {
      'id': 'free_shipping',
      'label': '🚚 Free Shipping',
      'route': '/free-shipping',
      'color': const Color(0xFF0D9488),
    },
    {
      'id': 'vouchers',
      'label': '🏷️ Vouchers Hub',
      'route': '/vouchers',
      'color': const Color(0xFFD97706),
    },
    {
      'id': 'wholesale',
      'label': '📦 Wholesale Bulk',
      'route': '/wholesale',
      'color': const Color(0xFF2563EB),
    },
    {
      'id': 'local_shops',
      'label': '🏡 Local Farms',
      'route': '/local-shops',
      'color': const Color(0xFF16A34A),
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isCompact = sw < 960;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        children: [
          // Top Bar (Logo, Search Bar, Cart, User)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1350),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    // Brand Logo
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => context.go(AppRoutes.marketplace),
                        child: Row(
                          children: [
                            const BrandLogo(size: BrandLogoSize.small),
                            if (!isCompact) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'MALL',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFB45309),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Search Bar (Shopee / Lazada Style)
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(Icons.search_rounded,
                                  color: Color(0xFF94A3B8), size: 20),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: widget.onSearchChanged,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF1E293B),
                                ),
                                decoration: InputDecoration(
                                  hintText: widget.searchPlaceholder,
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    size: 16, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _searchController.clear();
                                  widget.onSearchChanged?.call('');
                                  setState(() {});
                                },
                              ),
                            Container(
                              height: 42,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: const BoxDecoration(
                                color: Color(0xFF059669),
                                borderRadius: BorderRadius.horizontal(
                                    right: Radius.circular(9)),
                              ),
                              child: Center(
                                child: Text(
                                  'Search',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Vouchers Shortcut
                    if (!isCompact)
                      IconButton(
                        tooltip: 'Vouchers & Rewards',
                        onPressed: () => context.push('/vouchers'),
                        icon: const Icon(Icons.confirmation_num_outlined,
                            color: Color(0xFF475569)),
                      ),

                    // Cart Icon with Dynamic Count Badge
                    ListenableBuilder(
                      listenable: CartService(),
                      builder: (context, _) {
                        final count = CartService().itemCount;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              tooltip: 'Shopping Cart',
                              onPressed: () => context.push('/cart'),
                              icon: const Icon(Icons.shopping_cart_outlined,
                                  color: Color(0xFF1E293B), size: 24),
                            ),
                            if (count > 0)
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDC2626),
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Center(
                                    child: Text(
                                      count > 99 ? '99+' : '$count',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),

                    // User Auth State
                    const SizedBox(width: 8),
                    ListenableBuilder(
                      listenable: AuthService(),
                      builder: (context, _) {
                        final auth = AuthService();
                        if (auth.isLoggedIn) {
                          final displayName = auth.userName.isNotEmpty
                              ? auth.userName
                              : (auth.userEmail.isNotEmpty
                                  ? auth.userEmail.split('@').first
                                  : 'Account');
                          final initial = displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'U';
                          return InkWell(
                            onTap: () => context.push(AppRoutes.profile),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFF059669),
                                    child: Text(
                                      initial,
                                      style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (!isCompact) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      displayName,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }
                        return ElevatedButton(
                          onPressed: () => context.push(AppRoutes.login),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Sign In',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Channel Tabs Strip (Shopee / Lazada Sub-Nav)
          Container(
            color: const Color(0xFFFAFAFA),
            width: double.infinity,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1350),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: _channels.map((ch) {
                        final isActive = widget.activeTab == ch['id'];
                        final color = ch['color'] as Color;

                        return InkWell(
                          onTap: () {
                            if (!isActive) {
                              context.go(ch['route'] as String);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isActive ? color : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Text(
                              ch['label'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isActive
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: isActive
                                    ? color
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
