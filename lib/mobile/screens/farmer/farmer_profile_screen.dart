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
            const SizedBox(height: 16),
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
    final canPop = Navigator.canPop(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (canPop)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => context.pop(),
                  )
                else
                  const SizedBox(width: 48),
                Text('Farmer Profile', style: AppTextStyles.headline3.copyWith(fontSize: 20)),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: AppDecorations.cardDecoration.copyWith(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildProfileImage(),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _farmerName ?? 'My Farm',
                              style: AppTextStyles.headline3.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              auth.userEmail,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSubtle,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            _buildVerifiedBadge(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildStatsStrip(),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _handleSwitchToCustomer,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Switch to Buying Mode',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Container(
      width: 80,
      height: 80,
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
                ),
                imageUrl: _farmerImageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: Colors.grey[100]),
                errorWidget: (_, _, _) =>
                    const Icon(Icons.agriculture, size: 36, color: Colors.grey),
              )
            : Container(
                color: Colors.grey[100],
                child: const Icon(
                  Icons.agriculture,
                  size: 36,
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
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Business Settings',
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ),
          Container(
            decoration: AppDecorations.cardDecoration.copyWith(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.dashboard_rounded,
                  title: 'Sales Dashboard',
                  color: AppColors.textBody,
                  onTap: () {
                    SupabaseDataService.navigationTabNotifier.value = 0;
                    widget.onModeChanged();
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.inventory_2_outlined,
                  title: 'My Products',
                  color: AppColors.textBody,
                  onTap: () {
                    SupabaseDataService.navigationTabNotifier.value = 1;
                    widget.onModeChanged();
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.business_center_outlined,
                  title: 'Farm Details',
                  color: AppColors.textBody,
                  onTap: () async {
                    await context.push(AppRoutes.myDetails);
                    _loadFarmerData();
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.confirmation_number_outlined,
                  title: 'Manage Vouchers',
                  color: AppColors.textBody,
                  onTap: () => context.push(AppRoutes.farmerVouchers),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Community',
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ),
          Container(
            decoration: AppDecorations.cardDecoration.copyWith(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.groups_rounded,
                  title: 'Followers',
                  color: AppColors.textBody,
                  onTap: () => context.push(AppRoutes.farmerFollowers),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.forum_outlined,
                  title: 'Farmer Community',
                  color: AppColors.textBody,
                  onTap: () {
                    SupabaseDataService.navigationTabNotifier.value = 3;
                    widget.onModeChanged();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Security & Support',
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ),
          Container(
            decoration: AppDecorations.cardDecoration.copyWith(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.help_center_outlined,
                  title: 'Help Center',
                  color: AppColors.textBody,
                  onTap: () => context.push(AppRoutes.helpCenter),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.settings_outlined,
                  title: 'App Settings',
                  color: AppColors.textBody,
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.grey[600]),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textHeadline,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() =>
      Divider(height: 1, indent: 58, endIndent: 20, color: Colors.grey[100]);

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: OutlinedButton.icon(
        onPressed: _confirmLogout,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Log Out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
