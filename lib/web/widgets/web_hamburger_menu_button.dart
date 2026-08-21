import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../shared/services/auth/auth_service.dart';
import '../../shared/router/app_routes.dart';
import '../../shared/utils/apk_downloader.dart';
import '../../shared/widgets/premium_confirm_dialog.dart';

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
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => PremiumConfirmDialog(
        title: 'Confirm Logout',
        content: 'Are you sure you want to log out of AgriDirect?',
        confirmText: 'Log Out',
        loadingText: 'Logging out...',
        onConfirm: () async {
          await _auth.logout();
          if (mounted) {
            context.go(AppRoutes.login);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFarmerMode = _auth.isViewingAsFarmer;
    final isLoggedIn = _auth.isLoggedIn;
    final isSeller = _auth.isSeller;

    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: _primary.withValues(alpha: 0.05),
      ),
      child: PopupMenuButton<int>(
        icon: const Icon(Icons.menu, color: _primary),
        tooltip: 'Menu',
        elevation: 12,
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
          } else if (index == 102) {
            context.go(AppRoutes.farmersMap);
          } else if (index == 103) {
            context.go(AppRoutes.articles);
          } else if (index == 104) {
            context.go(AppRoutes.aboutUs);
          } else if (index == 105) {
            context.go(AppRoutes.weatherRadar);
          } else if (index == 106) {
            if (isFarmerMode) {
              _auth.switchToCustomerMode();
              widget.onNavigate(0);
            } else {
              _auth.switchToFarmerMode();
              widget.onNavigate(0);
            }
          } else if (index == 107) {
            context.go(AppRoutes.webFarmerRegister);
          } else if (index == 108) {
            context.go(AppRoutes.notifications);
          } else if ((isFarmerMode && index == 6) || (!isFarmerMode && index == 5)) {
            context.go(AppRoutes.messages, extra: {'asFarmer': isFarmerMode});
          } else if (!isFarmerMode && index == 3) {
            widget.onNavigate(3);
          } else if (!isFarmerMode && index == 4) {
            if (widget.onCartTap != null) {
              widget.onCartTap!();
            } else {
              context.go(AppRoutes.cart);
            }
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
          final currentPath = GoRouterState.of(context).uri.path;

          // 1. Mode Header
          items.add(
            PopupMenuItem<int>(
              enabled: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isFarmerMode
                            ? Icons.storefront_rounded
                            : Icons.shopping_bag_outlined,
                        color: _primary,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isFarmerMode ? 'FARMER MODE' : 'CUSTOMER MODE',
                        style: headerStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          // 2. Mode Switcher action if applicable
          if (isLoggedIn) {
            if (isFarmerMode) {
              items.add(
                PopupMenuItem<int>(
                  value: 106,
                  child: _buildActionItem(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Switch to Customer Mode',
                    color: const Color(0xFF0284C7),
                    bgColor: const Color(0xFFE0F2FE),
                  ),
                ),
              );
            } else if (isSeller) {
              items.add(
                PopupMenuItem<int>(
                  value: 106,
                  child: _buildActionItem(
                    icon: Icons.storefront_rounded,
                    label: 'Switch to Farmer Mode',
                    color: _primary,
                    bgColor: const Color(0xFFDCFCE7),
                  ),
                ),
              );
            } else {
              items.add(
                PopupMenuItem<int>(
                  value: 107,
                  child: _buildActionItem(
                    icon: Icons.agriculture_rounded,
                    label: 'Become a Farmer',
                    color: _primary,
                    bgColor: const Color(0xFFDCFCE7),
                  ),
                ),
              );
            }
          }

          items.add(const PopupMenuDivider(height: 1));

          // 3. Navigation Links
          if (isFarmerMode) {
            final farmerMenuItems = [
              (0, Icons.dashboard_rounded, 'Dashboard', widget.currentIndex == 0),
              (1, Icons.inventory_2_rounded, 'Products', widget.currentIndex == 1),
              (2, Icons.receipt_long_rounded, 'Orders', widget.currentIndex == 2),
              (3, Icons.groups_rounded, 'Community', widget.currentIndex == 3),
              (4, Icons.pending_actions_rounded, 'Pre-Orders', widget.currentIndex == 4),
              (5, Icons.person_rounded, 'Profile', widget.currentIndex == 5),
              (6, Icons.chat_bubble_rounded, 'Messages', currentPath.startsWith(AppRoutes.messages)),
              (102, Icons.map_rounded, 'Find Farmer', currentPath == AppRoutes.farmersMap),
              (103, Icons.article_rounded, 'DA Articles', currentPath.startsWith(AppRoutes.articles)),
              (105, Icons.thunderstorm_rounded, 'Weather Radar', currentPath.startsWith(AppRoutes.weatherRadar)),
            ];

            for (final item in farmerMenuItems) {
              items.add(
                PopupMenuItem<int>(
                  value: item.$1,
                  child: _buildNavItem(
                    icon: item.$2,
                    label: item.$3,
                    isActive: item.$4,
                  ),
                ),
              );
            }
          } else {
            final customerMenuItems = [
              (0, Icons.home_rounded, 'Home', currentPath == '/' || currentPath.startsWith(AppRoutes.marketplace)),
              (1, Icons.shopping_bag_rounded, 'Shop', currentPath.startsWith(AppRoutes.shop)),
              (2, Icons.people_rounded, 'Community', currentPath.startsWith(AppRoutes.community)),
              (103, Icons.article_rounded, 'DA Articles', currentPath.startsWith(AppRoutes.articles)),
              (104, Icons.info_outline_rounded, 'About Us', currentPath.startsWith(AppRoutes.aboutUs)),
              (102, Icons.map_rounded, 'Find Farmer', currentPath == AppRoutes.farmersMap),
              (105, Icons.thunderstorm_rounded, 'Weather Radar', currentPath.startsWith(AppRoutes.weatherRadar)),
              (3, Icons.person_rounded, 'Profile', currentPath.startsWith(AppRoutes.profile)),
              (4, Icons.shopping_cart_rounded, 'Cart', widget.isCartActive || currentPath.startsWith(AppRoutes.cart)),
              (5, Icons.chat_bubble_rounded, 'Messages', currentPath.startsWith(AppRoutes.messages)),
            ];

            for (final item in customerMenuItems) {
              items.add(
                PopupMenuItem<int>(
                  value: item.$1,
                  child: _buildNavItem(
                    icon: item.$2,
                    label: item.$3,
                    isActive: item.$4,
                  ),
                ),
              );
            }
          }

          // 4. Get Android App
          items.add(const PopupMenuDivider(height: 1));
          items.add(
            PopupMenuItem<int>(
              value: 99,
              child: _buildActionItem(
                icon: Icons.android_rounded,
                label: 'Get Android App',
                color: _primary,
                bgColor: const Color(0xFFDCFCE7),
              ),
            ),
          );

          // 5. Auth Action
          items.add(const PopupMenuDivider(height: 1));
          if (isLoggedIn) {
            items.add(
              PopupMenuItem<int>(
                value: 100,
                child: _buildActionItem(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  color: Colors.red,
                  bgColor: Colors.red.shade50,
                ),
              ),
            );
          } else {
            items.add(
              PopupMenuItem<int>(
                value: 101,
                child: _buildActionItem(
                  icon: Icons.login_rounded,
                  label: 'Login / Sign Up',
                  color: _primary,
                  bgColor: _primary.withValues(alpha: 0.1),
                ),
              ),
            );
          }

          return items;
        },
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isActive ? _primary.withValues(alpha: 0.1) : Colors.transparent,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive ? _primary : _muted,
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive ? _primary : _dark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: bgColor,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
