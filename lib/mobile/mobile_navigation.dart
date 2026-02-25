import 'package:flutter/material.dart';
import '../shared/services/auth_service.dart';
import 'screens/consumer/home_screen.dart';
import 'screens/consumer/marketplace_screen.dart';
import 'screens/consumer/preorder_hub_screen.dart';
import 'screens/consumer/orders_screen.dart';
import 'screens/farmer/farmer_sales_dashboard.dart';
import 'screens/farmer/farmer_products_screen.dart';
import 'screens/farmer/farmer_orders_screen.dart';
import 'screens/farmer/farmer_community_hub.dart';
import 'screens/consumer/profile_screen.dart';
import 'screens/common/loading_screen.dart';

/// Mobile Navigation Wrapper
/// Customer mode: Home, Community, Profile
/// Farmer mode: Dashboard, Community, Profile
class MobileNavigation extends StatefulWidget {
  final VoidCallback onLogout;

  const MobileNavigation({super.key, required this.onLogout});

  @override
  State<MobileNavigation> createState() => _MobileNavigationState();
}

class _MobileNavigationState extends State<MobileNavigation> {
  int _currentIndex = 0;
  bool _isLoading = true;
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

  void _onLoadingFinished() {
    if (mounted) setState(() => _isLoading = false);
  }

  List<Widget> get _screens {
    if (_auth.isViewingAsFarmer) {
      // Farmer mode: Dashboard, Products, Orders, Community, Profile
      return [
        const FarmerSalesDashboard(),
        const FarmerProductsScreen(),
        const FarmerOrdersScreen(),
        const FarmerCommunityHub(),
        MobileProfileScreen(
          onModeChanged: () => setState(() => _currentIndex = 0),
          onLogout: widget.onLogout,
        ),
      ];
    }
    // Customer mode: Home, Marketplace, Pre-Order, Orders, Profile
    return [
      const HomeScreen(),
      const MarketplaceScreen(),
      const PreOrderHubScreen(),
      const OrdersScreen(),
      MobileProfileScreen(
        onModeChanged: () => setState(() => _currentIndex = 0),
        onLogout: widget.onLogout,
      ),
    ];
  }

  List<_NavItemData> get _navItems {
    if (_auth.isViewingAsFarmer) {
      return [
        _NavItemData(Icons.dashboard_rounded, 'Dashboard'),
        _NavItemData(Icons.inventory_2_rounded, 'Products'),
        _NavItemData(Icons.receipt_long_rounded, 'Orders'),
        _NavItemData(Icons.groups_rounded, 'Community'),
        _NavItemData(Icons.person_rounded, 'Profile'),
      ];
    }
    return [
      _NavItemData(Icons.home_rounded, 'Home'),
      _NavItemData(Icons.storefront_rounded, 'Marketplace'),
      _NavItemData(Icons.timer_rounded, 'Pre-Order'),
      _NavItemData(Icons.receipt_long_rounded, 'Orders'),
      _NavItemData(Icons.person_rounded, 'Profile'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return LoadingScreen(onFinished: _onLoadingFinished);
    }

    final screens = _screens;
    final navItems = _navItems;

    // Clamp index to valid range
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(navItems.length, (i) {
                // Special center Pre-Order button for consumer mode
                final isCenter = !_auth.isViewingAsFarmer && i == 2;
                if (isCenter) {
                  return _buildCenterNavItem(
                    icon: navItems[i].icon,
                    label: navItems[i].label,
                    index: i,
                  );
                }
                return _buildNavItem(
                  icon: navItems[i].icon,
                  label: navItems[i].label,
                  index: i,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF13EC5B)
                  : const Color(0xFF94A3B8),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF13EC5B)
                    : const Color(0xFF94A3B8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF13EC5B)
                  : const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              border: isSelected
                  ? null
                  : Border.all(
                      color: const Color(0xFF13EC5B).withValues(alpha: 0.3),
                      width: 2,
                    ),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF13EC5B),
              size: 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? const Color(0xFF13EC5B)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData(this.icon, this.label);
}
