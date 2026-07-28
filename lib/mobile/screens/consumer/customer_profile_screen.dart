import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/styles/app_theme.dart';
import 'package:agridirect/shared/widgets/premium_confirm_dialog.dart';

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

  void _handleSwitchToFarmer() {
    final auth = AuthService();
    if (auth.isSeller) {
      auth.switchToFarmerMode();
      widget.onModeChanged();
    } else if (auth.registrationStatus == 'pending' || auth.registrationStatus == 'under_review') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Your registration is pending admin review.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
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
            const SizedBox(height: 16),
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
                Text('Profile', style: AppTextStyles.headline3.copyWith(fontSize: 20)),
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
                              auth.userName.isNotEmpty ? auth.userName : 'User',
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
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _handleSwitchToFarmer,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            auth.isSeller
                                ? Icons.agriculture_rounded
                                : (auth.registrationStatus == 'pending' || auth.registrationStatus == 'under_review'
                                    ? Icons.hourglass_empty_rounded
                                    : Icons.agriculture_rounded),
                            size: 18,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            auth.isSeller
                                ? 'Switch to Selling Mode'
                                : (auth.registrationStatus == 'pending' || auth.registrationStatus == 'under_review'
                                    ? 'Pending Admin Review'
                                    : 'Start Selling on AgriDirect'),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.accent,
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
                    const Icon(Icons.person, size: 36, color: Colors.grey),
              )
            : Container(
                color: Colors.grey[100],
                child: const Icon(Icons.person, size: 36, color: Colors.grey),
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
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Account',
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
                  icon: Icons.person_outline_rounded,
                  title: 'My Details',
                  color: AppColors.textBody,
                  onTap: () async {
                    await context.push(AppRoutes.myDetails);
                    _loadCustomerData();
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.location_on_outlined,
                  title: 'Address Book',
                  color: AppColors.textBody,
                  onTap: () => context.push(AppRoutes.addressBook),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.favorite_outline_rounded,
                  title: 'Favorites',
                  color: AppColors.textBody,
                  onTap: () => context.push(AppRoutes.favorites),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Preferences',
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
                  icon: Icons.confirmation_number_outlined,
                  title: 'My Vouchers',
                  color: AppColors.textBody,
                  onTap: () => context.push(AppRoutes.claimedVouchers),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Messages',
                  color: AppColors.textBody,
                  onTap: () => context.push(AppRoutes.customerMessages),
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
