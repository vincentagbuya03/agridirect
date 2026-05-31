import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/styles/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _loadFarmerData();
  }

  Future<void> _loadFarmerData() async {
    final auth = AuthService();
    try {
      final farmers = await SupabaseConfig.client
          .from('farmers')
          .select('farm_name, image_url')
          .eq('user_id', auth.userId)
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

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Out'),
          ),
        ],
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.1),
            AppColors.surface,
          ],
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
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Farmer Profile',
                      style: AppTextStyles.headline1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: _handleSwitchToCustomer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Switch to Buying',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  _buildProfileImage(),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _farmerName ?? 'My Farm',
                          style: AppTextStyles.headline2.copyWith(fontSize: 24),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          auth.userEmail,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSubtle),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Verified Farmer',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: (_farmerImageUrl != null && _farmerImageUrl!.isNotEmpty)
            ? CachedNetworkImage(
                key: ValueKey(_farmerImageUrl), // 🟢 Force refresh when URL changes
                imageUrl: _farmerImageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: Colors.grey[100]),
                errorWidget: (_, _, _) => const Icon(Icons.agriculture, size: 40, color: Colors.grey),
              )
            : Container(
                color: Colors.grey[100],
                child: const Icon(Icons.agriculture, size: 40, color: Colors.grey),
              ),
      ),
    );
  }

  Widget _buildFarmerMenu(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Business Settings', style: AppTextStyles.headline3.copyWith(fontSize: 18)),
          const SizedBox(height: 16),
          Container(
            decoration: AppDecorations.cardDecoration.copyWith(borderRadius: BorderRadius.circular(24)),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.dashboard_rounded,
                  title: 'Sales Dashboard',
                  subtitle: 'Analytics and revenue overview',
                  color: Colors.green,
                  onTap: () => widget.onModeChanged(), // Already in dashboard tab effectively
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.inventory_2_outlined,
                  title: 'My Products',
                  subtitle: 'Manage listings and inventory',
                  color: Colors.orange,
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
                  icon: Icons.forum_outlined,
                  title: 'Farmer Community',
                  subtitle: 'Connect with other growers',
                  color: Colors.teal,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Support', style: AppTextStyles.headline3.copyWith(fontSize: 18)),
          const SizedBox(height: 16),
          Container(
            decoration: AppDecorations.cardDecoration.copyWith(borderRadius: BorderRadius.circular(24)),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.help_center_outlined,
                  title: 'Help Center',
                  color: Colors.purple,
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.settings_outlined,
                  title: 'App Settings',
                  color: Colors.blueGrey,
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
                  Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSubtle)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() => Divider(height: 1, indent: 70, endIndent: 20, color: Colors.grey[200]);

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}
