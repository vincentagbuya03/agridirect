import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../../shared/services/auth/auth_service.dart';
import '../../shared/router/app_routes.dart';
import '../../shared/utils/apk_downloader.dart';

class WebHamburgerMenuButton extends StatefulWidget {
  final int currentIndex;
  final void Function(int) onNavigate;
  final VoidCallback? onCartTap;
  final bool isCartActive;

  const WebHamburgerMenuButton({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    this.onCartTap,
    this.isCartActive = false,
  });

  @override
  State<WebHamburgerMenuButton> createState() => _WebHamburgerMenuButtonState();
}

class _WebHamburgerMenuButtonState extends State<WebHamburgerMenuButton> {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _downloadAndroidApk() async {
    await ApkDownloader.download();
  }

  void _handleLogout() async {
    await _auth.logout();
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFarmerMode = _auth.isViewingAsFarmer;

    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: _primary.withValues(alpha: 0.05),
      ),
      child: PopupMenuButton<int>(
        icon: const Icon(Icons.menu, color: _primary),
        tooltip: '',
        elevation: 10,
        offset: const Offset(0, 52),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _border, width: 1.5),
        ),
        onSelected: (index) {
          if (index == 99) {
            _downloadAndroidApk();
          } else if (index == 100) {
            _handleLogout();
          } else if (index == 101) {
            context.go(AppRoutes.login);
          } else if (!isFarmerMode && index == 4) {
            if (widget.onCartTap != null) widget.onCartTap!();
          } else {
            widget.onNavigate(index);
          }
        },
        itemBuilder: (context) {
          final headerStyle = GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: _muted,
            letterSpacing: 1.2,
          );

          final items = <PopupMenuEntry<int>>[];

          // Mode Header
          items.add(
            PopupMenuItem<int>(
              enabled: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isFarmerMode ? Icons.storefront_rounded : Icons.shopping_bag_outlined,
                        color: _primary,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isFarmerMode ? 'FARMER MODE' : 'CUSTOMER MODE',
                      style: headerStyle,
                    ),
                  ],
                ),
              ),
            ),
          );

          items.add(const PopupMenuDivider(height: 1));

          if (isFarmerMode) {
            final farmerMenuItems = [
              (0, Icons.dashboard_rounded, 'Dashboard'),
              (1, Icons.inventory_2_rounded, 'Products'),
              (2, Icons.receipt_long_rounded, 'Orders'),
              (3, Icons.groups_rounded, 'Community'),
              (4, Icons.person_rounded, 'Profile'),
            ];

            items.addAll(farmerMenuItems.map((item) {
              final isActive = widget.currentIndex == item.$1;
              return PopupMenuItem<int>(
                value: item.$1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isActive ? _primary.withValues(alpha: 0.1) : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.$2,
                        color: isActive ? _primary : _muted,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item.$3,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                          color: isActive ? _primary : _dark,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }));
          } else {
            final customerMenuItems = [
              (0, Icons.home_rounded, 'Home'),
              (1, Icons.shopping_bag_rounded, 'Shop'),
              (2, Icons.people_rounded, 'Community'),
              (3, Icons.person_rounded, 'Profile'),
              (4, Icons.shopping_cart_rounded, 'Cart'),
            ];

            items.addAll(customerMenuItems.map((item) {
              final isActive = item.$1 == 4
                  ? widget.isCartActive
                  : widget.currentIndex == item.$1;
              return PopupMenuItem<int>(
                value: item.$1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isActive ? _primary.withValues(alpha: 0.1) : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.$2,
                        color: isActive ? _primary : _muted,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item.$3,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                          color: isActive ? _primary : _dark,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }));
          }

          // Add Get Android App Menu Item
          items.add(const PopupMenuDivider(height: 1));
          items.add(
            PopupMenuItem<int>(
              value: 99,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFDCFCE7),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.android_rounded,
                      color: _primary,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Get Android App',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          // Add Sign Out / Login Menu Item
          items.add(const PopupMenuDivider(height: 1));
          if (_auth.isLoggedIn) {
            items.add(
              PopupMenuItem<int>(
                value: 100,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.red.shade50,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        color: Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Sign Out',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            items.add(
              PopupMenuItem<int>(
                value: 101,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _primary.withValues(alpha: 0.1),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.login_rounded,
                        color: _primary,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Login / Sign Up',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return items;
        },
      ),
    );
  }
}
