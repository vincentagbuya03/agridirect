import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/services/auth/auth_service.dart';
import '../../shared/services/commerce/cart_service.dart';
import '../../shared/widgets/brand_logo.dart';
import 'web_hamburger_menu_button.dart';


class WebConsumerNavBar extends StatefulWidget {
  final int currentIndex;
  final void Function(int) onNavigate;
  final VoidCallback? onCartTap;
  final bool isCartActive;
  final EdgeInsetsGeometry margin;

  const WebConsumerNavBar({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    this.onCartTap,
    this.isCartActive = false,
    this.margin = const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  });

  @override
  State<WebConsumerNavBar> createState() => _WebConsumerNavBarState();
}

class _WebConsumerNavBarState extends State<WebConsumerNavBar> {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  static bool _dismissedMobileBanner = false;

  int _hoveredNav = -1;

  Future<void> _downloadAndroidApk() async {
    final uri = Uri.parse('/AgriDirect-Installer.apk');
    await launchUrl(uri, webOnlyWindowName: '_self');
  }

  Widget _buildGlobalMobileAppBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF042F2E), Color(0xFF064E3B)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.android_rounded,
              color: Color(0xFF4ADE80),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Get the AgriDirect App',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Enjoy faster load times and push notifications.',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _downloadAndroidApk,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Get APK',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () {
              setState(() {
                _dismissedMobileBanner = true;
              });
            },
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white60,
              size: 14,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 12,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService(),
      builder: (context, _) {
        final sw = MediaQuery.of(context).size.width;
        final compact = sw < 900;
        final isMobile = sw < 650;
        
        final isFarmerMode = AuthService().isViewingAsFarmer;
        final navItems = isFarmerMode 
            ? const ['Dashboard', 'Products', 'Orders', 'Community']
            : const ['Home', 'Shop', 'Community'];

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMobile && !_dismissedMobileBanner)
              _buildGlobalMobileAppBanner(),
            Container(
              margin: widget.margin,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 28,
                vertical: compact ? 10 : 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => widget.onNavigate(0),
                      child: BrandLogo(
                        size: isMobile
                            ? BrandLogoSize.small
                            : (compact ? BrandLogoSize.small : BrandLogoSize.medium),
                      ),
                    ),
                  ),
                  if (!isMobile) ...[
                    SizedBox(width: compact ? 12 : 48),
                    ...List.generate(navItems.length, (i) {
                      final isActive = i == widget.currentIndex;
                      final isHovered = _hoveredNav == i;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _hoveredNav = i),
                          onExit: (_) => setState(() => _hoveredNav = -1),
                          child: GestureDetector(
                            onTap: () => widget.onNavigate(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 10 : 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: isActive
                                    ? _primary.withValues(alpha: 0.1)
                                    : isHovered
                                    ? _border.withValues(alpha: 0.55)
                                    : Colors.transparent,
                              ),
                              child: Text(
                                navItems[i],
                                style: GoogleFonts.inter(
                                  fontSize: compact ? 12 : 14,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isActive
                                      ? _primary
                                      : isHovered
                                      ? _dark
                                      : _muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                  const Spacer(),
                  
                  // Only show cart if NOT in Farmer Mode
                  if (!isFarmerMode) ...[
                    ListenableBuilder(
                      listenable: CartService(),
                      builder: (context, _) {
                        final cartCount = CartService().itemCount;
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: widget.onCartTap,
                            child: Container(
                              width: compact ? 36 : 44,
                              height: compact ? 36 : 44,
                              decoration: BoxDecoration(
                                color: widget.isCartActive
                                    ? _primary.withValues(alpha: 0.12)
                                    : _border.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.isCartActive
                                      ? _primary.withValues(alpha: 0.35)
                                      : _border,
                                ),
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Center(
                                    child: Icon(
                                      Icons.shopping_cart_outlined,
                                      color: widget.isCartActive ? _primary : _dark,
                                      size: compact ? 18 : 20,
                                    ),
                                  ),
                                  if (cartCount > 0)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        decoration: const BoxDecoration(
                                          color: _primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            cartCount > 99 ? '99+' : '$cartCount',
                                            style: GoogleFonts.inter(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],

                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => widget.onNavigate(isFarmerMode ? 4 : 3),
                      child: Container(
                        width: compact ? 36 : 44,
                        height: compact ? 36 : 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                          border: Border.all(color: _primary, width: 1.5),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          color: _primary,
                          size: compact ? 18 : 22,
                        ),
                      ),
                    ),
                  ),
                  if (isMobile) ...[
                    const SizedBox(width: 8),
                    WebHamburgerMenuButton(
                      currentIndex: widget.currentIndex,
                      onNavigate: widget.onNavigate,
                      onCartTap: widget.onCartTap,
                      isCartActive: widget.isCartActive,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
