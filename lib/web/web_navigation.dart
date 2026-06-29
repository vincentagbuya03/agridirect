import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../shared/services/auth/auth_service.dart';
import '../shared/router/app_routes.dart';
import 'screens/consumer/web_marketplace_home.dart';
import 'screens/consumer/web_shop_screen.dart';
import 'screens/farmer/web_sales_dashboard.dart';
import 'screens/farmer/web_farmer_products.dart';
import 'screens/farmer/web_farmer_orders.dart';
import 'screens/farmer/web_community_hub.dart';
import 'screens/consumer/web_profile_screen.dart';
import 'screens/auth/web_login_screen.dart';
import 'screens/admin/admin_dashboard_redesigned.dart';

class WebNavigation extends StatefulWidget {
  final VoidCallback onLogout;
  final int initialIndex;
  final bool showPreOrdersInShop;

  const WebNavigation({
    super.key,
    required this.onLogout,
    this.initialIndex = 0,
    this.showPreOrdersInShop = false,
  });

  @override
  State<WebNavigation> createState() => _WebNavigationState();
}

class _WebNavigationState extends State<WebNavigation> {
  late int _currentIndex;
  final _auth = AuthService();
  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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

  void _navigateTo(int index, [String? category]) {
    // If trying to access Profile (index 3) and not logged in, show login instead
    if (index == 3 && !_auth.isLoggedIn) {
      _showLoginDialog();
      return;
    }
    setState(() {
      _currentIndex = index;
      _selectedCategoryFilter = category;
    });
    if (!_auth.isViewingAsFarmer) {
      context.go(AppRoutes.webTabRoute(index));
    }
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: WebLoginScreen(
          onLoginSuccess: () {
            Navigator.of(dialogContext).pop();
            // Re-render to let WebNavigation.build() check admin status
            // This will show AdminDashboard if _auth.isAdmin is true
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  void _handleLogout() {
    // Navigate to home first, then logout
    setState(() {
      _currentIndex = 0;
      _selectedCategoryFilter = null;
    });
    widget.onLogout();
  }

  List<Widget> get _screens {
    if (_auth.isViewingAsFarmer) {
      return [
        WebSalesDashboard(onNavigate: _navigateTo, currentIndex: _currentIndex),
        WebFarmerProducts(onNavigate: _navigateTo, currentIndex: _currentIndex),
        WebFarmerOrders(onNavigate: _navigateTo, currentIndex: _currentIndex),
        WebCommunityHub(onNavigate: _navigateTo, currentIndex: _currentIndex),
        WebProfileScreen(
          onModeChanged: () => setState(() => _currentIndex = 0),
          onLogout: _handleLogout,
          onNavigate: _navigateTo,
          currentIndex: _currentIndex,
        ),
      ];
    }
    return [
      WebMarketplaceHome(onNavigate: _navigateTo, currentIndex: _currentIndex),
      WebShopScreen(
        onNavigate: _navigateTo,
        currentIndex: _currentIndex,
        initialShowPreOrders: widget.showPreOrdersInShop,
        initialCategory: _selectedCategoryFilter,
      ),
      WebCommunityHub(onNavigate: _navigateTo, currentIndex: _currentIndex),
      WebProfileScreen(
        onModeChanged: () => setState(() => _currentIndex = 0),
        onLogout: _handleLogout,
        onNavigate: _navigateTo,
        currentIndex: _currentIndex,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔵 WebNavigation.build() called');
    debugPrint('   isLoggedIn: ${_auth.isLoggedIn}');
    debugPrint('   isAdmin: ${_auth.isAdmin}');
    debugPrint('   isViewingAsFarmer: ${_auth.isViewingAsFarmer}');

    // If user is not logged in, we still show the selected screen but restrict actions
    if (!_auth.isLoggedIn) {
      debugPrint('   → Showing guest dashboard (current tab: $_currentIndex)');
      final screens = _screens;
      if (_currentIndex >= screens.length) {
        _currentIndex = 0;
      }
      return Scaffold(body: screens[_currentIndex]);
    }

    // If user is admin, show admin dashboard
    if (_auth.isAdmin) {
      debugPrint('   → Showing admin dashboard');
      return AdminDashboardRedesigned(onLogout: widget.onLogout);
    }

    debugPrint('   → Showing customer dashboard (current tab: $_currentIndex)');
    final screens = _screens;

    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(body: screens[_currentIndex]);
  }
}
