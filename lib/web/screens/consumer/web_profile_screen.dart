import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/router/app_router.dart';
import '../../widgets/animated_components.dart';

/// Web Profile screen.
/// Shows user info, "Start Selling" button, and account settings.
class WebProfileScreen extends StatefulWidget {
  final VoidCallback onModeChanged;
  final VoidCallback onLogout;
  final Function(int) onNavigate;
  final int currentIndex;

  const WebProfileScreen({
    super.key,
    required this.onModeChanged,
    required this.onLogout,
    required this.onNavigate,
    required this.currentIndex,
  });

  @override
  State<WebProfileScreen> createState() => _WebProfileScreenState();
}

class _WebProfileScreenState extends State<WebProfileScreen> with TickerProviderStateMixin {
  static const Color primary = Color(0xFF16A34A);
  static const Color _accent = Color(0xFF22C55E);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  // Animations
  late AnimationController _fadeInController;
  final Set<int> _hoveredButtons = {};
  int _hoveredNav = -1;

  @override
  void initState() {
    super.initState();
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    super.dispose();
  }

  void _handleStartSelling() {
    context.push(AppRoutes.webFarmerRegister, extra: () {
      widget.onModeChanged();
    });
  }

  void _handleSwitchToFarmer() {
    AuthService().switchToFarmerMode();
    widget.onModeChanged();
  }

  void _handleSwitchToCustomer() {
    AuthService().switchToCustomerMode();
    widget.onModeChanged();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Column(
        children: [
          _buildNavBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                // Page title
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your account and preferences',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                const SizedBox(height: 32),

                // Top row: profile card + seller card
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile card
                    Expanded(flex: 3, child: _buildProfileCard(auth)),
                    const SizedBox(width: 24),
                    // Seller card
                    Expanded(flex: 4, child: _buildSellerCard(auth)),
                  ],
                ),
                const SizedBox(height: 24),

                // Settings grid
                _buildSettingsGrid(),

                const SizedBox(height: 24),

                // Logout
                Align(
                  alignment: Alignment.centerLeft,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: widget.onLogout,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Log Out',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.red,
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
          ),
        ),
      ),
    ),
    ],
    ),
    );
  }

  // ─── Navigation Bar ───
  Widget _buildNavBar() {
    final navItems = ['Home', 'Shop', 'Community'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo with pulsing glow
          Row(
            children: [
              PulsingGlow(
                color: primary,
                radius: 20,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AgriColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: AnimatedLeafIcon(size: 22, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AgriDirect',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 48),
          // Nav items
          ...List.generate(navItems.length, (i) {
            final isActive = i == widget.currentIndex;
            final isHovered = _hoveredNav == i;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoveredNav = i),
                onExit: (_) => setState(() => _hoveredNav = -1),
                child: GestureDetector(
                  onTap: () => widget.onNavigate(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isActive
                          ? primary.withValues(alpha: 0.08)
                          : isHovered
                              ? _border.withValues(alpha: 0.5)
                              : Colors.transparent,
                    ),
                    child: Text(
                      navItems[i],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? primary : isHovered ? _dark : _muted,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          // Circle person icon (active — profile page)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
              border: Border.all(
                color: primary,
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.person_rounded,
              color: primary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(AuthService auth) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: primary, width: 3),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.2),
                  blurRadius: 16,
                ),
              ],
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl:
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuA7SO8J3CebwmP_4K0nwWhDkMsWISrTpnfbOkYJ79_ZiTCLVxdvX_FJArJ1xwYsLAJx8gW_Wtk3xValGb9mDShlpRvdPIMoD9UGWJ9LwNRlF0vvmsKesjK6liNaDGy7C5HGWdOAE1hEPvF3UTq81_QK7QkgKAAMQgeICa4pykDXTF8JYtnrFYPiavyC7N-wkK4pGMGQJcdoyKpRglzbFXWGqTdoa3xP-Bm86BGxFKlWg21Mbw-FylTfHiJeJMKgLbfSJr8MhPFg1zqB',
                fit: BoxFit.cover,
                placeholder: (ctx, url) => Container(color: Colors.grey[200]),
                errorWidget: (ctx, url, err) => const Icon(Icons.person, size: 36),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            auth.userName.isNotEmpty ? auth.userName : 'User',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            auth.userEmail.isNotEmpty ? auth.userEmail : 'user@email.com',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 14),
          if (auth.isSeller)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront_rounded, size: 16, color: primary),
                  const SizedBox(width: 6),
                  Text(
                    'Verified Seller',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerCard(AuthService auth) {
    if (auth.isSeller) {
      final isViewingAsFarmer = auth.isViewingAsFarmer;
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primary.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isViewingAsFarmer
                        ? Icons.storefront_rounded
                        : Icons.shopping_bag_rounded,
                    color: primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isViewingAsFarmer ? 'Farmer Mode' : 'Customer Mode',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isViewingAsFarmer
                          ? 'Manage your products & sales'
                          : 'Browse & buy farm products',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              isViewingAsFarmer
                  ? 'You are viewing as a farmer. Manage products, track sales, and view analytics from the Dashboard.'
                  : 'You are viewing as a customer. Switch to farmer mode to manage your products and sales.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hoveredButtons.add(0)),
              onExit: (_) => setState(() => _hoveredButtons.remove(0)),
              child: GestureDetector(
                onTap: isViewingAsFarmer
                    ? _handleSwitchToCustomer
                    : _handleSwitchToFarmer,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isViewingAsFarmer
                          ? [const Color(0xFF3B82F6), const Color(0xFF60A5FA)]
                          : [const Color(0xFF22C55E), const Color(0xFF16A34A)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _hoveredButtons.contains(0)
                        ? [
                            BoxShadow(
                              color: (isViewingAsFarmer
                                      ? const Color(0xFF3B82F6)
                                      : primary)
                                  .withValues(alpha: 0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: (isViewingAsFarmer
                                      ? const Color(0xFF3B82F6)
                                      : primary)
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: AnimatedScale(
                    scale: _hoveredButtons.contains(0) ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isViewingAsFarmer
                              ? Icons.shopping_bag_rounded
                              : Icons.storefront_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isViewingAsFarmer
                              ? 'Switch to Customer'
                              : 'Switch to Farmer',
                          style: const TextStyle(
                            fontSize: 14,
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
      );
    }

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.1),
            primary.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.agriculture_rounded,
              size: 140,
              color: primary.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      color: primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Become a Seller',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Sell your farm produce directly to customers',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Activate Seller Mode to unlock the Farmer Dashboard. '
                'Manage your products, track sales analytics, get AI-powered suggestions, '
                'and connect directly with buyers across the platform.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoveredButtons.add(1)),
                onExit: (_) => setState(() => _hoveredButtons.remove(1)),
                child: GestureDetector(
                  onTap: _handleStartSelling,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_accent, primary]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _hoveredButtons.contains(1)
                          ? [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: AnimatedScale(
                      scale: _hoveredButtons.contains(1) ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Start Selling',
                            style: TextStyle(
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
  }

  Widget _buildSettingsGrid() {
    final items = [
      _SettingsItem(
        Icons.shopping_bag_outlined,
        'My Orders',
        'Track purchases',
      ),
      _SettingsItem(Icons.favorite_outline, 'Wishlist', 'Saved items'),
      _SettingsItem(
        Icons.location_on_outlined,
        'Addresses',
        'Delivery locations',
      ),
      _SettingsItem(Icons.payment_outlined, 'Payments', 'Cards & wallets'),
      _SettingsItem(
        Icons.notifications_outlined,
        'Notifications',
        'Alert preferences',
      ),
      _SettingsItem(Icons.shield_outlined, 'Privacy', 'Data & security'),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: items.map((item) {
        return SizedBox(
          width: 260,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      size: 20,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          item.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[300],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SettingsItem(this.icon, this.title, this.subtitle);
}
