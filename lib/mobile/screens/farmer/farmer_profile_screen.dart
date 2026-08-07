import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/services/farmer/farmer_service.dart';
import '../../../shared/router/app_router.dart';
import '../../../shared/router/app_routes.dart';
import 'package:agridirect/shared/widgets/premium_confirm_dialog.dart';
import '../../widgets/auth/mobile_two_factor_sheet.dart';

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

class _FarmerProfileScreenState extends State<FarmerProfileScreen>
    with TickerProviderStateMixin {
  String? _farmerName;
  String? _farmerImageUrl;
  bool _hasMfaEnabled = false;
  int _selectedTab = 0; // 0: Profile, 1: Addresses, 2: Privacy & Security

  Map<String, dynamic> _dashboardStats = const {
    'followers': 0,
    'activeListings': 0,
    'communityPosts': 0,
  };

  static const Color _primary = Color(0xFF059669);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _amberDark = Color(0xFF92400E);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadFarmerData();
    _loadDashboardStats();
    _checkMfaStatus();
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
        final safeUrl =
            await SupabaseDatabase.getSafeUrl(rawUrl, defaultBucket: 'uploads');
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

  Future<void> _checkMfaStatus() async {
    try {
      final res = await SupabaseConfig.client.auth.mfa.listFactors();
      if (mounted) {
        setState(() {
          _hasMfaEnabled = res.totp.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error checking MFA status: $e');
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

  Future<void> _openChangePasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    final currentController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureCurrent = true;
    bool obscurePassword = true;
    bool obscureConfirm = true;
    bool isSaving = false;
    final auth = AuthService();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              setModalState(() => isSaving = true);
              final success = await auth.changePassword(
                currentPassword: currentController.text.trim(),
                newPassword: passwordController.text.trim(),
              );
              if (!dialogContext.mounted) return;
              setModalState(() => isSaving = false);
              if (success) {
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password updated successfully.'),
                    backgroundColor: _primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                final message = (auth.errorMessage ?? '').trim();
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                        message.isNotEmpty ? message : 'Unable to update password.'),
                    backgroundColor: Colors.red.shade600,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(Icons.shield_outlined, color: _amber, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Change Password',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Confirm your identity by entering your current password first.',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: _muted, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      StatefulBuilder(
                        builder: (_, ss) => TextFormField(
                          controller: currentController,
                          obscureText: obscureCurrent,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            suffixIcon: IconButton(
                              onPressed: () => setModalState(
                                  () => obscureCurrent = !obscureCurrent),
                              icon: Icon(
                                obscureCurrent
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                              ),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Enter your current password.'
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StatefulBuilder(
                        builder: (_, ss) => TextFormField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon:
                                const Icon(Icons.lock_rounded, size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            suffixIcon: IconButton(
                              onPressed: () => setModalState(
                                  () => obscurePassword = !obscurePassword),
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                              ),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().length < 8)
                                  ? 'Password must be at least 8 characters.'
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StatefulBuilder(
                        builder: (_, ss) => TextFormField(
                          controller: confirmController,
                          obscureText: obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon:
                                const Icon(Icons.lock_rounded, size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            suffixIcon: IconButton(
                              onPressed: () => setModalState(
                                  () => obscureConfirm = !obscureConfirm),
                              icon: Icon(
                                obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                              ),
                            ),
                          ),
                          validator: (v) =>
                              v != passwordController.text
                                  ? 'Passwords do not match.'
                                  : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Cancel',
                      style: GoogleFonts.inter(color: _muted)),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Update',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
    currentController.dispose();
    passwordController.dispose();
    confirmController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildHeroHeader(auth),
          _buildTabBar(),
          Expanded(child: _buildTabContent(auth)),
        ],
      ),
    );
  }

  // ─── Hero Header (Amber/Farmer theme) ───
  Widget _buildHeroHeader(AuthService auth) {
    final canPop = Navigator.canPop(context);
    final displayName = _farmerName ?? auth.userName;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.amber.shade700, Colors.amber.shade500],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            children: [
              // Top bar
              Row(
                children: [
                  if (canPop)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20, color: Colors.white),
                      onPressed: () => context.pop(),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      'Farmer Profile',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        size: 22, color: Colors.white70),
                    onPressed: () => context.push(AppRoutes.appSettings),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Avatar + name row
              Row(
                children: [
                  // Farm logo avatar
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: (_farmerImageUrl != null &&
                              _farmerImageUrl!.isNotEmpty)
                          ? CachedNetworkImage(
                              key: ValueKey(_farmerImageUrl),
                              imageUrl: _farmerImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  Container(color: Colors.white24),
                              errorWidget: (_, _, _) => const Icon(
                                  Icons.agriculture,
                                  size: 36,
                                  color: Colors.white54),
                            )
                          : Container(
                              color: Colors.white24,
                              child: const Icon(Icons.agriculture,
                                  size: 36, color: Colors.white54),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName.isNotEmpty ? displayName : 'My Farm',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          auth.userEmail,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Verified farmer badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded,
                                  size: 11, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'Verified Farmer',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Stats banner
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                          '${_dashboardStats['followers'] ?? 0}',
                          'Followers',
                          Icons.groups_rounded),
                    ),
                    Container(width: 1, height: 24, color: Colors.white30),
                    Expanded(
                      child: _buildStatItem(
                          '${_dashboardStats['activeListings'] ?? 0}',
                          'Products',
                          Icons.inventory_2_outlined),
                    ),
                    Container(width: 1, height: 24, color: Colors.white30),
                    Expanded(
                      child: _buildStatItem(
                          '${_dashboardStats['communityPosts'] ?? 0}',
                          'Posts',
                          Icons.forum_outlined),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Switch to Customer
              GestureDetector(
                onTap: _handleSwitchToCustomer,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_bag_outlined,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('Switch to Buying Mode',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white70)),
      ],
    );
  }

  // ─── Tab Bar ───
  Widget _buildTabBar() {
    final tabs = [
      (icon: Icons.storefront_outlined, label: 'Farm Profile'),
      (icon: Icons.location_on_outlined, label: 'Addresses'),
      (icon: Icons.shield_outlined, label: 'Privacy & Security'),
    ];

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final isSelected = _selectedTab == i;
            final selectedColor = Colors.amber.shade700;
            return GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? selectedColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSelected ? selectedColor : _border),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _amber.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(tabs[i].icon,
                        size: 14,
                        color: isSelected ? Colors.white : _muted),
                    const SizedBox(width: 6),
                    Text(
                      tabs[i].label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color:
                            isSelected ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─── Tab Content ───
  Widget _buildTabContent(AuthService auth) {
    switch (_selectedTab) {
      case 0:
        return _buildProfileTab(auth);
      case 1:
        return _buildAddressesTab();
      case 2:
        return _buildPrivacyTab(auth);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Farm Profile Tab ───
  Widget _buildProfileTab(AuthService auth) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Farm info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.shade200),
              boxShadow: [
                BoxShadow(
                    color: _amber.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.storefront_rounded,
                          color: _amberDark, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Farm Store Profile',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _dark)),
                          Text('Manage your public farm store details',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: _muted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text('FARMER',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _amberDark)),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _buildInfoRow(
                    icon: Icons.storefront_outlined,
                    label: 'Farm Name',
                    value: _farmerName ?? '—'),
                _buildInfoRow(
                    icon: Icons.mail_outline,
                    label: 'Email Address',
                    value: auth.userEmail,
                    badge: 'Verified'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await context.push(AppRoutes.myDetails);
                      _loadFarmerData();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Farm Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _dark,
                      side: BorderSide(color: Colors.amber.shade300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Business Settings
          _buildSectionTitle('BUSINESS SETTINGS'),
          const SizedBox(height: 8),
          _buildMenuCard(isAmber: true, children: [
            _buildMenuTile(
              icon: Icons.dashboard_rounded,
              title: 'Sales Dashboard',
              subtitle: 'Analytics and revenue overview',
              onTap: () {
                SupabaseDataService.navigationTabNotifier.value = 0;
                widget.onModeChanged();
              },
            ),
            _buildMenuTile(
              icon: Icons.inventory_2_outlined,
              title: 'My Products',
              subtitle: 'Manage your crop listings',
              onTap: () {
                SupabaseDataService.navigationTabNotifier.value = 1;
                widget.onModeChanged();
              },
            ),
            _buildMenuTile(
              icon: Icons.confirmation_number_outlined,
              title: 'Manage Vouchers',
              subtitle: 'Discount codes for your store',
              onTap: () => context.push(AppRoutes.farmerVouchers),
              isLast: true,
            ),
          ]),

          const SizedBox(height: 16),
          _buildSectionTitle('COMMUNITY'),
          const SizedBox(height: 8),
          _buildMenuCard(isAmber: true, children: [
            _buildMenuTile(
              icon: Icons.groups_rounded,
              title: 'Followers',
              subtitle: 'Buyers following your farm',
              onTap: () => context.push(AppRoutes.farmerFollowers),
            ),
            _buildMenuTile(
              icon: Icons.forum_outlined,
              title: 'Farmer Community',
              subtitle: 'Posts and discussions',
              onTap: () {
                SupabaseDataService.navigationTabNotifier.value = 3;
                widget.onModeChanged();
              },
              isLast: true,
            ),
          ]),

          const SizedBox(height: 16),
          _buildSectionTitle('MORE'),
          const SizedBox(height: 8),
          _buildMenuCard(isAmber: true, children: [
            _buildMenuTile(
              icon: Icons.help_center_outlined,
              title: 'Help Center',
              subtitle: 'Farmer guides and FAQs',
              onTap: () => context.push(AppRoutes.helpCenter),
            ),
            _buildMenuTile(
              icon: Icons.settings_outlined,
              title: 'App Settings',
              subtitle: 'Notifications, cache, updates',
              onTap: () => context.push(AppRoutes.appSettings),
              isLast: true,
            ),
          ]),

          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Log Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              side: BorderSide(color: Colors.red.shade200),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Farmer Edition v2.4.2',
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.grey[400])),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Addresses Tab ───
  Widget _buildAddressesTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.location_on_rounded,
                      color: _amberDark, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Delivery Addresses',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _dark)),
                      Text('Manage addresses for shipments',
                          style:
                              GoogleFonts.inter(fontSize: 12, color: _muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.addressBook),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open Address Book'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Privacy & Security Tab ───
  Widget _buildPrivacyTab(AuthService auth) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.shade200),
          boxShadow: [
            BoxShadow(
                color: _amber.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Privacy & Security Settings',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.w800, color: _dark)),
            const SizedBox(height: 4),
            Text(
                'Manage password, authentication, and privacy controls',
                style: GoogleFonts.inter(fontSize: 12, color: _muted)),
            const Divider(height: 28, color: Color(0xFFF1F5F9)),

            // 1. Account Password
            _buildPrivacyRow(
              icon: Icons.lock_outline_rounded,
              title: 'Account Password',
              description:
                  'Change your account password regularly to keep your farm account secure.',
              buttonText: 'Change Password',
              onTap: _openChangePasswordDialog,
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),

            // 2. 2FA
            _buildPrivacyRow(
              icon: Icons.security_rounded,
              title: 'Two-Factor Authentication (2FA)',
              description:
                  'Add an extra layer of security to your farmer account with an Authenticator App.',
              buttonText: _hasMfaEnabled ? 'Manage 2FA' : 'Enable 2FA',
              badge: _hasMfaEnabled ? 'Active' : 'Recommended',
              badgeIsGreen: _hasMfaEnabled,
              onTap: () async {
                final result = await MobileTwoFactorSheet.show(
                  context,
                  initialIsActive: _hasMfaEnabled,
                );
                if (result == true) {
                  _checkMfaStatus();
                }
              },
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),

            // 3. Active Sessions
            _buildPrivacyRow(
              icon: Icons.devices_rounded,
              title: 'Active Sessions & Devices',
              description:
                  'View active browsers and devices logged into your account.',
              buttonText: 'View Sessions',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Current session is verified and active.'),
                    backgroundColor: _primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),

            // 4. Data Privacy
            _buildPrivacyRow(
              icon: Icons.visibility_off_outlined,
              title: 'Data & Activity Privacy',
              description:
                  'Control how your farm activity and transactions are visible.',
              buttonText: 'Privacy Policy',
              onTap: () => context.push(AppRoutes.helpCenter),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helper Widgets ───
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    String? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _muted,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _dark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          if (badge != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(badge,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _primary)),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.8,
          )),
    );
  }

  Widget _buildMenuCard(
      {required List<Widget> children, bool isAmber = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isAmber ? Colors.amber.shade100 : _border),
        boxShadow: [
          BoxShadow(
              color: isAmber
                  ? _amber.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: _amber),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _dark)),
                      Text(subtitle,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: _muted)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 58, endIndent: 18, color: Colors.grey[100]),
      ],
    );
  }

  Widget _buildPrivacyRow({
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onTap,
    String? badge,
    bool badgeIsGreen = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF475569)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(title,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _dark)),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeIsGreen
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(badge,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: badgeIsGreen ? _primary : _muted,
                          )),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(description,
            style: GoogleFonts.inter(
                fontSize: 12, color: _muted, height: 1.4)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: _dark,
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Text(buttonText,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
