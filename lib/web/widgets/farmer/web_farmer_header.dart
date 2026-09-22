import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/localization/farmer_locale_service.dart';
import '../../../mobile/widgets/farmer/farmer_language_toggle.dart';
import '../../constants/web_design_tokens.dart';

/// 🏢 Enterprise Farmer Portal Header for AgriDirect Web
/// Sits flush at top of the browser window.
/// Includes portal badge, tab navigation, quick "Switch to Buyer Mode" CTA,
/// notifications bell, and farmer profile account menu.
class WebFarmerHeader extends StatefulWidget {
  final int currentIndex;
  final void Function(int, [String?]) onNavigate;
  final VoidCallback? onNotificationTap;

  const WebFarmerHeader({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    this.onNotificationTap,
  });

  @override
  State<WebFarmerHeader> createState() => _WebFarmerHeaderState();
}

class _WebFarmerHeaderState extends State<WebFarmerHeader> {
  int _hoveredIndex = -1;

  List<Map<String, dynamic>> _getTabs(FarmerLocaleService loc) {
    return [
      {
        'label': loc.s('Dashboard', 'Dashboard'),
        'icon': Icons.dashboard_outlined,
        'activeIcon': Icons.dashboard_rounded,
        'index': 0,
      },
      {
        'label': loc.s('Products', 'Mga Paninda'),
        'icon': Icons.inventory_2_outlined,
        'activeIcon': Icons.inventory_2_rounded,
        'index': 1,
      },
      {
        'label': loc.s('Orders', 'Mga Order'),
        'icon': Icons.local_shipping_outlined,
        'activeIcon': Icons.local_shipping_rounded,
        'index': 2,
      },
      {
        'label': loc.s('Pre-Orders', 'Paunang Order'),
        'icon': Icons.eco_outlined,
        'activeIcon': Icons.eco_rounded,
        'index': 4,
      },
      {
        'label': loc.s('Community', 'Komunidad'),
        'icon': Icons.forum_outlined,
        'activeIcon': Icons.forum_rounded,
        'index': 3,
      },
    ];
  }

  void _switchToBuyerMode() {
    final auth = AuthService();
    auth.switchToCustomerMode();
    if (mounted) {
      context.go(AppRoutes.marketplace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FarmerLocaleService.instance,
      builder: (context, _) {
        final loc = FarmerLocaleService.instance;
        final tabs = _getTabs(loc);
        final sw = MediaQuery.of(context).size.width;
        final isMobile = sw < 1000;
        final isCompact = sw < 1280;
        final isTight = sw < 1140;
        final auth = AuthService();

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: WebDesignTokens.border,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : (isCompact ? 16 : 28),
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // ─── 1. Brand Logo & Portal Tag ───
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => widget.onNavigate(0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BrandLogo(
                              size: (isMobile || isTight) ? BrandLogoSize.small : BrandLogoSize.medium,
                            ),
                            if (!isTight) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: WebDesignTokens.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: WebDesignTokens.primary.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: WebDesignTokens.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      loc.s('SELLER HUB', 'SENTRO NG NAGTITINDA'),
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: WebDesignTokens.primaryDark,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // ─── 2. Desktop Navigation Tabs ───
                    if (!isMobile) ...[
                      SizedBox(width: isCompact ? 12 : 24),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: tabs.map((tab) {
                              final tabIndex = tab['index'] as int;
                              final isSelected = widget.currentIndex == tabIndex;
                              final isHovered = _hoveredIndex == tabIndex;

                              return Padding(
                                padding: EdgeInsets.only(right: isCompact ? 4 : 8),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (_) => setState(() => _hoveredIndex = tabIndex),
                                  onExit: (_) => setState(() => _hoveredIndex = -1),
                                  child: GestureDetector(
                                    onTap: () => widget.onNavigate(tabIndex),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isCompact ? 8 : 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? WebDesignTokens.primary.withValues(alpha: 0.08)
                                            : (isHovered
                                                ? WebDesignTokens.bg
                                                : Colors.transparent),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? WebDesignTokens.primary.withValues(alpha: 0.25)
                                              : Colors.transparent,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSelected
                                                ? (tab['activeIcon'] as IconData)
                                                : (tab['icon'] as IconData),
                                            size: isCompact ? 16 : 17,
                                            color: isSelected
                                                ? WebDesignTokens.primary
                                                : (isHovered
                                                    ? WebDesignTokens.dark
                                                    : WebDesignTokens.slate600),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            tab['label'] as String,
                                            style: GoogleFonts.rubik(
                                              fontSize: isCompact ? 12.5 : 13.5,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : (isHovered
                                                      ? FontWeight.w600
                                                      : FontWeight.w500),
                                              color: isSelected
                                                  ? WebDesignTokens.primaryDark
                                                  : (isHovered
                                                      ? WebDesignTokens.dark
                                                      : WebDesignTokens.slate700),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ] else
                      const Spacer(),

                    // ─── 3. Action Buttons & Switch to Buyer Mode ───
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Language Toggle
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: FarmerLanguageToggle(compact: true),
                        ),

                        // Switch to Buyer Mode CTA Button
                        Tooltip(
                          message: loc.s('Switch to Buyer Mode', 'Bumalik sa Mamimili'),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: _switchToBuyerMode,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: (isMobile || isCompact) ? 10 : 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: WebDesignTokens.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: WebDesignTokens.border,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.storefront_outlined,
                                      size: 16,
                                      color: WebDesignTokens.slate700,
                                    ),
                                    if (!isMobile && !isCompact) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        loc.s('Switch to Buyer', 'Bumalik sa Mamimili'),
                                        style: GoogleFonts.nunitoSans(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: WebDesignTokens.dark,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Notification / Order Alert Bell
                        IconButton(
                          tooltip: loc.s('Order & Farm Notifications', 'Mga Notipikasyon ng Sakahan'),
                          icon: const Icon(
                            Icons.notifications_outlined,
                            size: 20,
                            color: WebDesignTokens.slate700,
                          ),
                          splashRadius: 20,
                          onPressed: widget.onNotificationTap ??
                              () => widget.onNavigate(2), // Jump to orders by default
                        ),

                        const SizedBox(width: 6),

                        // Farmer Profile Avatar & Menu
                        PopupMenuButton<String>(
                          tooltip: loc.s('Farmer Settings', 'Mga Setting ng Magsasaka'),
                          offset: const Offset(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          onSelected: (val) async {
                            switch (val) {
                              case 'profile':
                                widget.onNavigate(5);
                                break;
                              case 'buyer':
                                _switchToBuyerMode();
                                break;
                              case 'logout':
                                await auth.logout();
                                if (context.mounted) {
                                  context.go(AppRoutes.login);
                                }
                                break;
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              enabled: false,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        auth.userName.isNotEmpty
                                            ? auth.userName
                                            : loc.s('Producer Account', 'Account ng Magbubukid'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.rubik(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: WebDesignTokens.dark,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.verified_rounded,
                                        color: WebDesignTokens.primary,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    loc.s('Verified Farm Manager', 'Beripikadong Tagapamahala ng Sakahan'),
                                    style: GoogleFonts.nunitoSans(
                                      fontSize: 11,
                                      color: WebDesignTokens.slate500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'profile',
                              child: Row(
                                children: [
                                  const Icon(Icons.settings_outlined, size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    loc.s('Farm Settings & Profile', 'Mga Setting at Profile ng Sakahan'),
                                    style: GoogleFonts.nunitoSans(),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'buyer',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.swap_horiz_rounded,
                                    size: 18,
                                    color: WebDesignTokens.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    loc.s('Switch to Buyer Mode', 'Lumipat sa Mode ng Mamimili'),
                                    style: GoogleFonts.nunitoSans(
                                      fontWeight: FontWeight.w600,
                                      color: WebDesignTokens.primary,
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
                                    loc.s('Log Out', 'Mag-logout'),
                                    style: GoogleFonts.nunitoSans(
                                      color: WebDesignTokens.discountRed,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: WebDesignTokens.primary.withValues(alpha: 0.12),
                              border: Border.all(
                                color: WebDesignTokens.primary.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                auth.userName.isNotEmpty
                                    ? auth.userName[0].toUpperCase()
                                    : 'F',
                                style: GoogleFonts.rubik(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: WebDesignTokens.primaryDark,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Mobile Drawer Toggle Button
                        if (isMobile) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.menu_rounded),
                            onPressed: () => _showMobileDrawer(context, loc, tabs),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMobileDrawer(
    BuildContext context,
    FarmerLocaleService loc,
    List<Map<String, dynamic>> tabs,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      const BrandLogo(size: BrandLogoSize.small),
                      const SizedBox(width: 8),
                      Text(
                        loc.s('Farmer Portal', 'Portal ng Magsasaka'),
                        style: GoogleFonts.rubik(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: WebDesignTokens.dark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                ...tabs.map((t) {
                  final idx = t['index'] as int;
                  final isSelected = widget.currentIndex == idx;
                  return ListTile(
                    leading: Icon(
                      isSelected ? t['activeIcon'] as IconData : t['icon'] as IconData,
                      color: isSelected ? WebDesignTokens.primary : WebDesignTokens.slate600,
                    ),
                    title: Text(
                      t['label'] as String,
                      style: GoogleFonts.rubik(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? WebDesignTokens.primary : WebDesignTokens.dark,
                      ),
                    ),
                    selected: isSelected,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    selectedTileColor: WebDesignTokens.primary.withValues(alpha: 0.08),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onNavigate(idx);
                    },
                  );
                }),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.storefront_outlined,
                    color: WebDesignTokens.primary,
                  ),
                  title: Text(
                    loc.s('Switch to Buyer Mode', 'Lumipat sa Mode ng Mamimili'),
                    style: GoogleFonts.rubik(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: WebDesignTokens.primary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _switchToBuyerMode();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
