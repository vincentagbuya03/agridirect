import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/farmer/farmer_service.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/styles/app_theme.dart';
import 'package:agridirect/shared/widgets/premium_confirm_dialog.dart';

/// Mobile Profile screen specifically for Farmers.
class FarmerProfileScreen extends StatefulWidget {
  final VoidCallback onModeChanged;
  final VoidCallback onLogout;

  const FarmerProfileScreen({
    super.key,
    required this.onModeChanged,
    required this.onLogout,
  });

  @override
  State<FarmerProfileScreen> createState() => _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends State<FarmerProfileScreen> {
  String? _farmerName;
  String? _farmerImageUrl;
  Map<String, dynamic> _dashboardStats = const {
    'followers': 0,
    'activeListings': 0,
    'communityPosts': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadFarmerData();
    _loadDashboardStats();
  }

  Future<void> _loadFarmerData({int attempt = 0}) async {
    final auth = AuthService();
    final userId = (SupabaseConfig.currentUser?.id ?? auth.userId).trim();
    if (userId.isEmpty) {
      if (attempt < 5) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        return _loadFarmerData(attempt: attempt + 1);
      }
      return;
    }

    try {
      final farmers = await SupabaseConfig.client
          .from('farmers')
          .select('farm_name, image_url')
          .eq('user_id', userId)
          .limit(1);

      if (farmers.isNotEmpty && mounted) {
        setState(() {
          _farmerName = farmers[0]['farm_name'] as String?;
        });
        final rawUrl = farmers[0]['image_url'] as String?;
        final safeUrl = await SupabaseDatabase.getSafeUrl(
          rawUrl,
          defaultBucket: 'uploads',
        );
        if (mounted) {
          setState(() {
            _farmerImageUrl = safeUrl;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading farmer header data: $e');
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final stats = await FarmerService().getFarmerStats();
      if (!mounted) return;
      setState(() {
        _dashboardStats = stats;
      });
    } catch (e) {
      debugPrint('Error loading farmer profile stats: $e');
    }
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const PremiumConfirmDialog(
        title: 'Confirm Logout',
        content: 'Are you sure you want to log out of AgriDirect?',
      ),
    );

    if (shouldLogout == true) {
      widget.onLogout();
    }
  }

  void _handleSwitchToCustomer() {
    AuthService().switchToCustomerMode();
    widget.onModeChanged();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildFarmerHeader(auth),
            const SizedBox(height: 24),
            _buildFarmerMenu(context),
            const SizedBox(height: 32),
            _buildLogoutButton(),
            const SizedBox(height: 24),
            Text(
              'Farmer Edition v2.4.2',
              style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[400]),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmerHeader(AuthService auth) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFFFF4DB), AppColors.surface],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Farmer Profile',
                          style: AppTextStyles.headline2.copyWith(fontSize: 30),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your farm, products, and followers',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSubtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textHeadline.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildProfileImage(),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _farmerName ?? 'My Farm',
                                style: AppTextStyles.headline2.copyWith(
                                  fontSize: 26,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                auth.userEmail,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSubtle,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildVerifiedBadge(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _buildStatsStrip(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _handleSwitchToCustomer,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: AppColors.primaryDark,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                        label: const Text('Switch to Buying'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.8),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: (_farmerImageUrl != null && _farmerImageUrl!.isNotEmpty)
            ? CachedNetworkImage(
                key: ValueKey(
                  _farmerImageUrl,
                ), // 🟢 Force refresh when URL changes
                imageUrl: _farmerImageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: Colors.grey[100]),
                errorWidget: (_, _, _) =>
                    const Icon(Icons.agriculture, size: 40, color: Colors.grey),
              )
            : Container(
                color: Colors.grey[100],
                child: const Icon(
                  Icons.agriculture,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
      ),
    );
  }

  Widget _buildStatsStrip() {
    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
            value: '${_dashboardStats['followers'] ?? 0}',
            label: 'Followers',
            icon: Icons.groups_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            value: '${_dashboardStats['activeListings'] ?? 0}',
            label: 'Products',
            icon: Icons.inventory_2_outlined,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            value: '${_dashboardStats['communityPosts'] ?? 0}',
            label: 'Posts',
            icon: Icons.forum_outlined,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.headline3.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSubtle,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            'Verified Farmer',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerMenu(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Settings',
            style: AppTextStyles.headline3.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: AppDecorations.cardDecoration.copyWith(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.dashboard_rounded,
                  title: 'Sales Dashboard',
                  subtitle: 'Analytics and revenue overview',
                  color: Colors.green,
                  onTap: () {
                    SupabaseDataService.navigationTabNotifier.value = 0;
                    widget.onModeChanged();
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.inventory_2_outlined,
                  title: 'My Products',
                  subtitle: 'Manage listings and inventory',
                  color: Colors.orange,
                  onTap: () {
                    SupabaseDataService.navigationTabNotifier.value = 1;
                    widget.onModeChanged();
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.business_center_outlined,
                  title: 'Farm Details',
                  subtitle: 'Business info and location',
                  color: Colors.blue,
                  onTap: () async {
                    await context.push(AppRoutes.myDetails);
                    _loadFarmerData();
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.groups_rounded,
                  title: 'Followers',
                  subtitle:
                      '${_dashboardStats['followers'] ?? 0} customers following your farm',
                  color: Colors.pink,
                  onTap: () => context.push(AppRoutes.farmerFollowers),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.forum_outlined,
                  title: 'Farmer Community',
                  subtitle: 'Connect with other growers',
                  color: Colors.teal,
                  onTap: () {
                    SupabaseDataService.navigationTabNotifier.value = 3;
                    widget.onModeChanged();
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.confirmation_number_outlined,
                  title: 'Manage Vouchers',
                  subtitle: 'Create and distribute discount coupons',
                  color: Colors.purple,
                  onTap: () => context.push(AppRoutes.farmerVouchers),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Support',
            style: AppTextStyles.headline3.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: AppDecorations.cardDecoration.copyWith(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.help_center_outlined,
                  title: 'Help Center',
                  color: Colors.purple,
                  onTap: () => context.push(AppRoutes.helpCenter),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.settings_outlined,
                  title: 'App Settings',
                  color: Colors.blueGrey,
                  onTap: () => context.push(AppRoutes.appSettings),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSubtle,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() =>
      Divider(height: 1, indent: 70, endIndent: 20, color: Colors.grey[200]);

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: OutlinedButton.icon(
        onPressed: _confirmLogout,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Log Out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
