import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/integration/weather_alert_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/styles/app_theme.dart';

/// Mobile Profile screen for customers.
/// Contains user info, settings, and the "Start Selling" button
/// that registers the user as a farmer. Once registered, they can
/// switch between customer and farmer modes.
class MobileProfileScreen extends StatefulWidget {
  final VoidCallback onModeChanged;
  final VoidCallback onLogout;

  const MobileProfileScreen({
    super.key,
    required this.onModeChanged,
    required this.onLogout,
  });

  @override
  State<MobileProfileScreen> createState() => _MobileProfileScreenState();
}

class _MobileProfileScreenState extends State<MobileProfileScreen> {
  String? _farmerName; // Farm name loaded from database
  String? _farmerImageUrl; // Farm image URL loaded from database
  String? _customerImageUrl; // Customer avatar URL loaded from users table

  @override
  void initState() {
    super.initState();

    _loadHeaderProfileData();
  }

  // Listen to connectivity changes

  Future<void> _loadHeaderProfileData() async {
    final auth = AuthService();

    try {
      if (auth.isViewingAsFarmer) {
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
      } else {
        final users = await SupabaseConfig.client
            .from('users')
            .select('avatar_url')
            .eq('user_id', auth.userId)
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
      }
    } catch (e) {
      debugPrint('Error loading profile header data: $e');
    }
  }

  void _handleStartSelling() {
    final auth = AuthService();
    if (auth.registrationStatus == 'rejected') {
      // Rejected applications should always be allowed to re-apply.
      context.push(
        AppRoutes.farmerRegister,
        extra: () async {
          widget.onModeChanged();
        },
      );
      return;
    }

    // If already registered as seller, just switch to farmer mode
    if (auth.isSeller) {
      _handleSwitchToFarmer();
    } else if (auth.registrationStatus == 'pending') {
      // Show pending approval dialog
      _showPendingDialog();
    } else {
      // Show registration screen for new sellers
      context.push(
        AppRoutes.farmerRegister,
        extra: () async {
          widget.onModeChanged();
        },
      );
    }
  }

  void _showPendingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_bottom_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text('Pending Admin Approval', style: AppTextStyles.headline3),
            const SizedBox(height: 12),
            Text(
              'Your farmer registration is under review. We will notify you once it\'s approved.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSubtle,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: AppDecorations.primaryButton.copyWith(
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildPremiumHeader(auth),
                const SizedBox(height: 24),
                _buildMenuSection(context),
                const SizedBox(height: 32),
                _buildLogoutButton(),
                const SizedBox(height: 24),
                Text(
                  'Version 2.4.2 (AgriDirect)',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleSwitchToFarmer() {
    unawaited(_switchToFarmerMode());
  }

  Future<void> _switchToFarmerMode() async {
    final auth = AuthService();

    if (auth.isSeller) {
      auth.switchToFarmerMode();
    } else if (auth.registrationStatus == 'approved') {
      // Offline flow: cached approved registration should still open farmer mode.
      await auth.startSelling();
    } else {
      return;
    }

    await _loadHeaderProfileData();
    if (!mounted) return;
    widget.onModeChanged();
  }

  void _handleSwitchToCustomer() {
    AuthService().switchToCustomerMode();
    _loadHeaderProfileData();
    widget.onModeChanged();
  }

  String _messagesRoute(AuthService auth) {
    return auth.isViewingAsFarmer
        ? AppRoutes.farmerMessages
        : AppRoutes.customerMessages;
  }

  Widget _buildPremiumHeader(AuthService auth) {
    final isFarmer = auth.isViewingAsFarmer;
    final profileImageUrl = isFarmer ? _farmerImageUrl : _customerImageUrl;

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
            color: AppColors.textHeadline.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isFarmer ? AppColors.accent : AppColors.primary)
                    .withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isFarmer ? AppColors.accent : AppColors.primary)
                    .withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Profile', style: AppTextStyles.headline1),
                      if (auth.registrationStatus == 'approved' || auth.isSeller)
                        GestureDetector(
                          onTap: isFarmer
                              ? _handleSwitchToCustomer
                              : _handleSwitchToFarmer,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isFarmer
                                  ? AppColors.accent.withValues(alpha: 0.1)
                                  : AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isFarmer
                                    ? AppColors.accent.withValues(alpha: 0.2)
                                    : AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 18,
                                  color: isFarmer
                                      ? AppColors.accent
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isFarmer ? 'Buying Mode' : 'Selling Mode',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: isFarmer
                                        ? AppColors.accent
                                        : AppColors.primary,
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
                      Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isFarmer
                                    ? AppColors.accent
                                    : AppColors.primary,
                                width: 3,
                                strokeAlign: BorderSide.strokeAlignOutside,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isFarmer
                                              ? AppColors.accent
                                              : AppColors.primary)
                                          .withValues(alpha: 0.2),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child:
                                  (profileImageUrl != null &&
                                      profileImageUrl.isNotEmpty)
                                  ? CachedNetworkImage(
                                      imageUrl: profileImageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, _) =>
                                          Container(color: Colors.grey[100]),
                                      errorWidget: (_, _, _) => const Icon(
                                        Icons.person_rounded,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey[100],
                                      child: Icon(
                                        isFarmer
                                            ? Icons.agriculture
                                            : Icons.person_rounded,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isFarmer
                                    ? Icons.verified_rounded
                                    : Icons.camera_alt_rounded,
                                size: 18,
                                color: isFarmer
                                    ? AppColors.accent
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                isFarmer && _farmerName != null
                                    ? _farmerName!
                                    : (auth.userName.isNotEmpty
                                          ? auth.userName
                                          : 'User'),
                                style: AppTextStyles.headline2.copyWith(
                                  fontSize: 24,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              auth.userEmail.isNotEmpty
                                  ? auth.userEmail
                                  : 'No email',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSubtle,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isFarmer) ...[const SizedBox(height: 8)],
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isFarmer
                                    ? AppColors.accent.withValues(alpha: 0.1)
                                    : AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isFarmer ? 'Verified Farmer' : 'Premium Buyer',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: isFarmer
                                      ? AppColors.accent
                                      : AppColors.primary,
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
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    final auth = AuthService();
    final isFarmer = auth.isViewingAsFarmer;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'General Settings',
            style: AppTextStyles.headline3.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: AppDecorations.cardDecoration.copyWith(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                if (auth.registrationStatus == 'pending') ...[
                  _buildPendingApprovalMenuItem(),
                  _buildDivider(),
                ] else if (auth.registrationStatus == 'rejected') ...[
                  _buildRejectedRetryMenuItem(),
                  _buildDivider(),
                ] else if (!auth.isSeller && (auth.registrationStatus == null ||
                    auth.registrationStatus == '')) ...[
                  _buildStartSellingMenuItem(),
                  _buildDivider(),
                ],
                if (auth.registrationStatus == 'approved' || auth.isSeller) ...[
                  _buildMenuItem(
                    icon: Icons.dashboard_rounded,
                    title: isFarmer
                        ? 'Farmer Dashboard'
                        : 'Switch to Farmer Mode',
                    color: isFarmer ? Colors.green : Colors.orange,
                    subtitle: isFarmer
                        ? 'View sales & analytics'
                        : 'Open your seller tools',
                    onTap: () {
                      _handleSwitchToFarmer();
                    },
                  ),
                  _buildDivider(),
                ],
                _buildMenuItem(
                  icon: Icons.person_outline_rounded,
                  title: 'My Details',
                  color: const Color(0xFF3B82F6),
                  subtitle: isFarmer
                      ? 'Farm info, business details'
                      : 'Personal info, security',
                  onTap: () async {
                    await context.push(AppRoutes.myDetails);
                    await _loadHeaderProfileData();
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.location_on_outlined,
                  title: 'Address Book',
                  color: const Color(0xFFFF9500),
                  subtitle: 'Delivery locations',
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Messages',
                  color: const Color(0xFF14B8A6),
                  subtitle: 'Chat support & updates',
                  onTap: () => context.push(_messagesRoute(auth)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Preferences',
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
                  icon: Icons.favorite_outline_rounded,
                  title: 'Favorites',
                  color: const Color(0xFFEC4899),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.help_outline_rounded,
                  title: 'Help Center',
                  color: const Color(0xFF8B5CF6),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.settings_outlined,
                  title: 'App Settings',
                  color: const Color(0xFF64748B),
                ),
                if (kDebugMode) ...[
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.cloud_sync_rounded,
                    title: 'Test Weather Alert',
                    color: const Color(0xFF0EA5E9),
                    subtitle: 'Simulate bad weather alert',
                    onTap: () async {
                      await WeatherAlertService().testWeatherNotification();
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalMenuItem() {
    return InkWell(
      onTap: _showPendingDialog,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.hourglass_empty_rounded,
                size: 22,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registration Pending',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHeadline,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Waiting for admin review',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSubtle,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[300],
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartSellingMenuItem() {
    return InkWell(
      onTap: _handleStartSelling,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start Selling',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHeadline,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Register as a farmer',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSubtle,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[300],
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedRetryMenuItem() {
    return InkWell(
      onTap: _handleStartSelling,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                size: 22,
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rejected - Try Again',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your last application was rejected. Tap to re-apply.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSubtle,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[300],
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
                  border: Border.all(color: color.withValues(alpha: 0.2)),
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
                        color: textColor ?? AppColors.textHeadline,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.textSubtle.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.textSubtle.withValues(alpha: 0.1),
      indent: 70,
      endIndent: 20,
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FilledButton.tonal(
        onPressed: _confirmLogout,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.error.withValues(alpha: 0.1),
          foregroundColor: AppColors.error,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          minimumSize: const Size(double.infinity, 56),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, size: 22),
            SizedBox(width: 8),
            Text(
              'Log Out',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
