import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/styles/app_theme.dart';

/// Mobile Profile screen specifically for Customers (Buyers).
class CustomerProfileScreen extends StatefulWidget {
  final VoidCallback onModeChanged;
  final VoidCallback onLogout;

  const CustomerProfileScreen({
    super.key,
    required this.onModeChanged,
    required this.onLogout,
  });

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  String? _customerImageUrl;

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  Future<void> _loadCustomerData({int attempt = 0}) async {
    final auth = AuthService();
    final userId = (SupabaseConfig.currentUser?.id ?? auth.userId).trim();
    if (userId.isEmpty) {
      // Auth state can still be initializing when this screen mounts.
      if (attempt < 5) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        return _loadCustomerData(attempt: attempt + 1);
      }
      return;
    }

    try {
      final users = await SupabaseConfig.client
          .from('users')
          .select('avatar_url')
          .eq('user_id', userId)
          .limit(1);

      if (users.isNotEmpty && mounted) {
        final rawUrl = users[0]['avatar_url'] as String?;
        final safeUrl = await SupabaseDatabase.getSafeUrl(
          rawUrl,
          defaultBucket: 'uploads',
        );
        if (mounted) {
          setState(() {
            _customerImageUrl = safeUrl;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading customer profile data: $e');
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

  void _handleSwitchToFarmer() {
    final auth = AuthService();
    if (auth.isSeller) {
      auth.switchToFarmerMode();
      widget.onModeChanged();
    } else {
      context.push(AppRoutes.farmerRegister, extra: widget.onModeChanged);
    }
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
            _buildCustomerHeader(auth),
            const SizedBox(height: 24),
            _buildCustomerMenu(context),
            const SizedBox(height: 32),
            _buildLogoutButton(),
            const SizedBox(height: 24),
            Text(
              'Version 2.4.2 (AgriDirect)',
              style: AppTextStyles.labelSmall.copyWith(color: Colors.grey[400]),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerHeader(AuthService auth) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
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
                  Text('Profile', style: AppTextStyles.headline1),
                  GestureDetector(
                    onTap: _handleSwitchToFarmer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.agriculture,
                            size: 18,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            auth.isSeller
                                ? 'Switch to Selling'
                                : 'Start Selling',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.accent,
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
                          auth.userName.isNotEmpty ? auth.userName : 'User',
                          style: AppTextStyles.headline2.copyWith(fontSize: 24),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          auth.userEmail,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSubtle,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Premium Buyer',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
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
        border: Border.all(color: AppColors.primary, width: 3),
      ),
      child: ClipOval(
        child: (_customerImageUrl != null && _customerImageUrl!.isNotEmpty)
            ? CachedNetworkImage(
                key: ValueKey(
                  _customerImageUrl,
                ), // 🟢 Force refresh when URL changes
                imageUrl: _customerImageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: Colors.grey[100]),
                errorWidget: (_, _, _) =>
                    const Icon(Icons.person, size: 40, color: Colors.grey),
              )
            : Container(
                color: Colors.grey[100],
                child: const Icon(Icons.person, size: 40, color: Colors.grey),
              ),
      ),
    );
  }

  Widget _buildCustomerMenu(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Settings',
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
                  icon: Icons.person_outline_rounded,
                  title: 'My Details',
                  subtitle: 'Personal info and security',
                  color: Colors.blue,
                  onTap: () async {
                    await context.push(AppRoutes.myDetails);
                    _loadCustomerData();
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.location_on_outlined,
                  title: 'Address Book',
                  subtitle: 'Manage delivery addresses',
                  color: Colors.orange,
                  onTap: () => context.push(AppRoutes.addressBook),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.favorite_outline_rounded,
                  title: 'Favorites',
                  subtitle: 'Saved products and farms',
                  color: Colors.pink,
                  onTap: () => context.push(AppRoutes.favorites),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Messages',
                  subtitle: 'Contact support or sellers',
                  color: Colors.teal,
                  onTap: () => context.push(AppRoutes.customerMessages),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Other', style: AppTextStyles.headline3.copyWith(fontSize: 18)),
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
      child: FilledButton.tonal(
        onPressed: _confirmLogout,
        style: FilledButton.styleFrom(
          foregroundColor: AppColors.error,
          backgroundColor: AppColors.error.withValues(alpha: 0.1),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Text('Log Out'),
      ),
    );
  }
}
