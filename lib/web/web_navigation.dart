import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../shared/services/auth/auth_service.dart';
import '../shared/router/app_router.dart';
import 'screens/consumer/web_marketplace_home.dart';
import 'screens/consumer/web_shop_screen.dart';
import 'screens/farmer/web_sales_dashboard.dart';
import 'screens/farmer/web_community_hub.dart';
import 'screens/consumer/web_profile_screen.dart';
import 'screens/auth/web_login_screen.dart';
import 'screens/admin/admin_dashboard_redesigned.dart';


class WebNavigation extends StatefulWidget {
  final VoidCallback onLogout;

  const WebNavigation({super.key, required this.onLogout});

  @override
  State<WebNavigation> createState() => _WebNavigationState();
}

class _WebNavigationState extends State<WebNavigation> {
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

  /// Navigate to a tab by index. Profile (3) requires login.
  void _navigateTo(int index) {
    if (index == 3 && !_auth.isLoggedIn) {
      _showLoginDialog();
      return;
    }
    context.go(AppRoutes.webTabRoute(index, isFarmer: _auth.isViewingAsFarmer));
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: WebLoginScreen(
          onLoginSuccess: () {
            Navigator.of(context).pop();
            context.go(AppRoutes.profile);
          },
        ),
      ),
    );
  }

  void _handleLogout() {
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    // Admin: bypass tab navigation entirely
    if (_auth.isAdmin) {
      return AdminDashboardRedesigned(onLogout: widget.onLogout);
    }

    // Derive active tab index from the current route
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = AppRoutes.webTabIndex(location);

    // ── Guest (not logged in): Marketplace / Shop / Community only ──
    if (!_auth.isLoggedIn) {
      final guestIndex = currentIndex.clamp(0, 2);
      return Scaffold(body: _buildGuestScreen(guestIndex));
    }

    // ── Authenticated: Farmer or Consumer ──
    return Scaffold(
      body: _auth.isViewingAsFarmer
          ? _buildFarmerScreen(currentIndex)
          : _buildConsumerScreen(currentIndex),
    );
  }

  Widget _buildGuestScreen(int index) {
    switch (index) {
      case 1:  return WebShopScreen(onNavigate: _navigateTo, currentIndex: index);
      case 2:  return WebCommunityHub(onNavigate: _navigateTo, currentIndex: index);
      default: return WebMarketplaceHome(onNavigate: _navigateTo, currentIndex: index);
    }
  }

  Widget _buildFarmerScreen(int index) {
    switch (index) {
      case 1:  return WebShopScreen(onNavigate: _navigateTo, currentIndex: index);
      case 2:  return WebCommunityHub(onNavigate: _navigateTo, currentIndex: index);
      case 3:  return WebProfileScreen(
        onModeChanged: () => context.go(AppRoutes.marketplace),
        onLogout: _handleLogout,
        onNavigate: _navigateTo,
        currentIndex: index,
      );
      default: return WebSalesDashboard(onNavigate: _navigateTo, currentIndex: index);
    }
  }

  Widget _buildConsumerScreen(int index) {
    switch (index) {
      case 1:  return WebShopScreen(onNavigate: _navigateTo, currentIndex: index);
      case 2:  return WebCommunityHub(onNavigate: _navigateTo, currentIndex: index);
      case 3:  return WebProfileScreen(
        onModeChanged: () => context.go(AppRoutes.farmerDashboard),
        onLogout: _handleLogout,
        onNavigate: _navigateTo,
        currentIndex: index,
      );
      default: return WebMarketplaceHome(onNavigate: _navigateTo, currentIndex: index);
    }
  }
}
