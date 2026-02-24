import 'package:flutter/material.dart';
import '../shared/services/auth_service.dart';
import 'screens/web_marketplace_home.dart';
import 'screens/web_sales_dashboard.dart';
import 'screens/web_community_hub.dart';
import 'screens/web_profile_screen.dart';

/// Web Navigation Wrapper
/// Modern dark sidebar with web-specific screens.
/// Customer mode: Marketplace, Community, Profile
/// Farmer mode: Dashboard, Community, Profile
class WebNavigation extends StatefulWidget {
  final VoidCallback onLogout;

  const WebNavigation({super.key, required this.onLogout});

  @override
  State<WebNavigation> createState() => _WebNavigationState();
}

class _WebNavigationState extends State<WebNavigation> {
  int _currentIndex = 0;
  bool _sidebarCollapsed = false;
  final _auth = AuthService();

  static const Color _sidebarBg = Color(0xFF0F172A);
  static const Color _sidebarText = Color(0xFF94A3B8);
  static const Color _sidebarActive = Color(0xFF10B981);
  static const Color _accent = Color(0xFF13EC5B);
  static const Color _border = Color(0xFF1E293B);

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

  List<Widget> get _screens {
    if (_auth.isViewingAsFarmer) {
      // Farmer mode: Dashboard, Community, Profile
      return [
        const WebSalesDashboard(),
        const WebCommunityHub(),
        WebProfileScreen(
          onModeChanged: () => setState(() => _currentIndex = 0),
          onLogout: widget.onLogout,
        ),
      ];
    }
    // Customer mode: Marketplace, Community, Profile
    return [
      const WebMarketplaceHome(),
      const WebCommunityHub(),
      WebProfileScreen(
        onModeChanged: () => setState(() => _currentIndex = 0),
        onLogout: widget.onLogout,
      ),
    ];
  }

  List<_WebNavItem> get _navItems {
    if (_auth.isViewingAsFarmer) {
      return [
        _WebNavItem(Icons.dashboard_rounded, 'Dashboard'),
        _WebNavItem(Icons.forum_rounded, 'Community'),
        _WebNavItem(Icons.person_rounded, 'Profile'),
      ];
    }
    return [
      _WebNavItem(Icons.storefront_rounded, 'Marketplace'),
      _WebNavItem(Icons.forum_rounded, 'Community'),
      _WebNavItem(Icons.person_rounded, 'Profile'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screens = _screens;
    final navItems = _navItems;

    // Clamp index to valid range
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: Row(
        children: [
          // ─── Dark Sidebar ───
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _sidebarCollapsed ? 72 : 260,
            decoration: const BoxDecoration(color: _sidebarBg),
            child: Column(
              children: [
                // Logo
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _sidebarCollapsed ? 16 : 24,
                    vertical: 24,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_sidebarActive, _accent],
                          ),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      if (!_sidebarCollapsed) ...[
                        const SizedBox(width: 12),
                        const Text(
                          'AgriDirect',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Divider
                Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: _sidebarCollapsed ? 12 : 20,
                  ),
                  height: 1,
                  color: _border,
                ),

                const SizedBox(height: 16),

                // Label
                if (!_sidebarCollapsed)
                  Padding(
                    padding: const EdgeInsets.only(left: 24, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'MENU',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _sidebarText.withValues(alpha: 0.5),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),

                // Nav items
                ...List.generate(navItems.length, (i) {
                  return _buildNavItem(navItems[i].icon, navItems[i].label, i);
                }),

                const Spacer(),

                // Collapse toggle
                Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: _sidebarCollapsed ? 12 : 20,
                  ),
                  height: 1,
                  color: _border,
                ),
                const SizedBox(height: 8),

                // Footer
                if (!_sidebarCollapsed) ...[
                  _buildFooterItem(
                    Icons.help_outline_rounded,
                    'Help & Support',
                  ),
                  _buildFooterItem(Icons.settings_rounded, 'Settings'),
                ],

                // Collapse button
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => setState(
                        () => _sidebarCollapsed = !_sidebarCollapsed,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _border.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _sidebarCollapsed
                              ? Icons.chevron_right_rounded
                              : Icons.chevron_left_rounded,
                          color: _sidebarText,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),

          // ─── Main Content ───
          Expanded(child: screens[_currentIndex]),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _sidebarCollapsed ? 12 : 12,
        vertical: 2,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _currentIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: _sidebarCollapsed ? 0 : 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? _sidebarActive.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: _sidebarCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? _sidebarActive : _sidebarText,
                ),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? Colors.white : _sidebarText,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _sidebarActive,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: _sidebarText),
              const SizedBox(width: 14),
              Text(label, style: TextStyle(fontSize: 13, color: _sidebarText)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebNavItem {
  final IconData icon;
  final String label;
  const _WebNavItem(this.icon, this.label);
}
