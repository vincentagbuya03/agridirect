import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/offline/offline_cache_service.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../web/widgets/web_consumer_nav_bar.dart';
import '../../../shared/router/app_routes.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final AuthService _auth = AuthService();
  final OfflineCacheService _cacheService = OfflineCacheService();
  bool _clearingCache = false;

  bool _publicProfile = true;
  bool _locationPermission = true;
  bool _diagnosticsEnabled = true;

  int _activeTabIndex = 0;
  int _hoveredTab = -1;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _publicProfile = prefs.getBool('privacy.public_profile') ?? true;
      _locationPermission = prefs.getBool('privacy.location_permission') ?? true;
      _diagnosticsEnabled = prefs.getBool('privacy.diagnostics_enabled') ?? true;
    });
  }

  Future<void> _updatePrivacySetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    _loadPrivacySettings();
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

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;

              setModalState(() => isSaving = true);
              final success = await _auth.changePassword(
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
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                final message = (_auth.errorMessage ?? '').trim();
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      message.isNotEmpty
                          ? message
                          : 'Unable to update password.',
                    ),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Change Password',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Confirm your identity by entering your current password first.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: currentController,
                        obscureText: obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () => setModalState(
                              () => obscureCurrent = !obscureCurrent,
                            ),
                            icon: Icon(
                              obscureCurrent
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your current password.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: const Icon(Icons.lock_open_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () => setModalState(
                              () => obscurePassword = !obscurePassword,
                            ),
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          final error = AuthService.validatePassword(text);
                          return error;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: confirmController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () => setModalState(
                              () => obscureConfirm = !obscureConfirm,
                            ),
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if ((value?.trim() ?? '') !=
                              passwordController.text.trim()) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Must be at least 10 characters with uppercase, lowercase, and a number.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSubtle,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSaving ? null : submit,
                  child: Text(isSaving ? 'Updating...' : 'Update Password'),
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

  Future<void> _clearAutoCache() async {
    setState(() => _clearingCache = true);
    if (!_cacheService.isInitialized) {
      await _cacheService.init();
    }
    await _cacheService.clearAutoCachedProducts();
    if (!mounted) return;
    setState(() => _clearingCache = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Auto-cached products cleared.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _openDeleteAccountDialog() async {
    final confirmationController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isDeleting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submitDelete() async {
              if (!formKey.currentState!.validate()) return;

              setModalState(() => isDeleting = true);
              try {
                await _auth.logout();
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account successfully scheduled for deletion.'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                Navigator.of(context).popUntil((route) => route.isFirst);
              } catch (e) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete account: $e'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } finally {
                setModalState(() => isDeleting = false);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Delete Account',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WARNING: This action is permanent and cannot be undone. All your personal data, products, and order history will be permanently deleted.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.error,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Please type "DELETE" to confirm your decision:',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSubtle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: confirmationController,
                        decoration: InputDecoration(
                          hintText: 'DELETE',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim() != 'DELETE') {
                            return 'Please type "DELETE" exactly.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isDeleting ? null : submitDelete,
                  child: Text(isDeleting ? 'Deleting...' : 'Delete Permanently'),
                ),
              ],
            );
          },
        );
      },
    );

    confirmationController.dispose();
  }

  Widget _buildWebLayout() {
    final isFarmer = _auth.isViewingAsFarmer;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          WebConsumerNavBar(
            currentIndex: -1,
            onNavigate: (index) {
              if (isFarmer) {
                context.go(AppRoutes.farmerDashboard);
              } else {
                context.go(AppRoutes.webTabRoute(index));
              }
            },
            onCartTap: () => context.go(AppRoutes.cart),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWebSidebar(),
                Container(
                  width: 1,
                  color: const Color(0xFFE2E8F0),
                ),
                Expanded(
                  child: _buildWebSettingsContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebSidebar() {
    final categories = [
      {'title': 'Security', 'icon': Icons.lock_outline_rounded},
      {'title': 'Privacy', 'icon': Icons.visibility_outlined},
      {'title': 'Storage', 'icon': Icons.cleaning_services_outlined},
      {'title': 'Account Actions', 'icon': Icons.delete_forever_rounded},
    ];

    return Container(
      width: 280,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Settings',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ...List.generate(categories.length, (index) {
            final cat = categories[index];
            final isActive = _activeTabIndex == index;
            final isHovered = _hoveredTab == index;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoveredTab = index),
                onExit: (_) => setState(() => _hoveredTab = -1),
                child: GestureDetector(
                  onTap: () => setState(() => _activeTabIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                          : isHovered
                              ? const Color(0xFFF1F5F9)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          cat['icon'] as IconData,
                          size: 20,
                          color: isActive
                              ? const Color(0xFF10B981)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          cat['title'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                            color: isActive
                                ? const Color(0xFF047857)
                                : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWebSettingsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_activeTabIndex == 0) ...[
            _buildWebHeader('Security', 'Manage the security of your account.'),
            const SizedBox(height: 24),
            _buildWebTileCard([
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Change Password',
                subtitle: 'Update the password used for your account.',
                onTap: _openChangePasswordDialog,
              ),
            ]),
          ] else if (_activeTabIndex == 1) ...[
            _buildWebHeader('Privacy', 'Configure your data and visibility preferences.'),
            const SizedBox(height: 24),
            _buildWebTileCard([
              _SwitchSettingsTile(
                icon: Icons.visibility_outlined,
                title: 'Public Profile',
                subtitle: 'Allow other users to search or view your profile details.',
                value: _publicProfile,
                onChanged: (val) => _updatePrivacySetting('privacy.public_profile', val),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _SwitchSettingsTile(
                icon: Icons.location_on_outlined,
                title: 'Location Services',
                subtitle: 'Use device location to match and find nearby farms.',
                value: _locationPermission,
                onChanged: (val) => _updatePrivacySetting('privacy.location_permission', val),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _SwitchSettingsTile(
                icon: Icons.analytics_outlined,
                title: 'Usage Diagnostics',
                subtitle: 'Share anonymous usage reports to help improve AgriDirect.',
                value: _diagnosticsEnabled,
                onChanged: (val) => _updatePrivacySetting('privacy.diagnostics_enabled', val),
              ),
            ]),
          ] else if (_activeTabIndex == 2) ...[
            _buildWebHeader('Storage', 'Manage local cache settings and offline data.'),
            const SizedBox(height: 24),
            _buildWebTileCard([
              _SettingsTile(
                icon: Icons.cleaning_services_outlined,
                title: 'Clear Auto Cache',
                subtitle: 'Remove temporary offline product cache.',
                trailing: _clearingCache
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _clearingCache ? null : _clearAutoCache,
              ),
            ]),
          ] else if (_activeTabIndex == 3) ...[
            _buildWebHeader('Account Actions', 'Crucial account state operations.'),
            const SizedBox(height: 24),
            _buildWebTileCard([
              _SettingsTile(
                icon: Icons.delete_forever_rounded,
                title: 'Delete Account',
                subtitle: 'Permanently delete your profile and account data.',
                onTap: _openDeleteAccountDialog,
                iconColor: AppColors.error,
                iconBgColor: AppColors.error.withValues(alpha: 0.1),
                titleColor: AppColors.error,
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildWebHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildWebTileCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && MediaQuery.of(context).size.width >= 650) {
      return _buildWebLayout();
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // Security Section
          Text('Security', style: AppTextStyles.headline3),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            subtitle: 'Update the password used for your account.',
            onTap: _openChangePasswordDialog,
          ),
          const SizedBox(height: 24),

          // Privacy Section
          Text('Privacy', style: AppTextStyles.headline3),
          const SizedBox(height: 12),
          _SwitchSettingsTile(
            icon: Icons.visibility_outlined,
            title: 'Public Profile',
            subtitle: 'Allow other users to search or view your profile details.',
            value: _publicProfile,
            onChanged: (val) => _updatePrivacySetting('privacy.public_profile', val),
          ),
          const SizedBox(height: 12),
          _SwitchSettingsTile(
            icon: Icons.location_on_outlined,
            title: 'Location Services',
            subtitle: 'Use device location to match and find nearby farms.',
            value: _locationPermission,
            onChanged: (val) => _updatePrivacySetting('privacy.location_permission', val),
          ),
          const SizedBox(height: 12),
          _SwitchSettingsTile(
            icon: Icons.analytics_outlined,
            title: 'Usage Diagnostics',
            subtitle: 'Share anonymous usage reports to help improve AgriDirect.',
            value: _diagnosticsEnabled,
            onChanged: (val) => _updatePrivacySetting('privacy.diagnostics_enabled', val),
          ),
          const SizedBox(height: 24),

          // Storage Section
          Text('Storage', style: AppTextStyles.headline3),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.cleaning_services_outlined,
            title: 'Clear Auto Cache',
            subtitle: 'Remove temporary offline product cache.',
            trailing: _clearingCache
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _clearingCache ? null : _clearAutoCache,
          ),
          const SizedBox(height: 24),

          // Account Actions Section
          Text('Account Actions', style: AppTextStyles.headline3),
          const SizedBox(height: 12),
          InkWell(
            onTap: _openDeleteAccountDialog,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: AppDecorations.cardDecoration.copyWith(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Account',
                          style: AppTextStyles.headline3.copyWith(color: AppColors.error),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Permanently delete your profile and account data.',
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
          ),
          const SizedBox(height: 24),

          // About Section
          Text('About', style: AppTextStyles.headline3),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppDecorations.cardDecoration.copyWith(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AgriDirect Mobile', style: AppTextStyles.headline3),
                const SizedBox(height: 8),
                Text(
                  'Profile settings now include account security, privacy toggles, cache tools, and account actions in one place.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSubtle,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? iconBgColor;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.iconBgColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb && MediaQuery.of(context).size.width >= 650;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(isWeb ? 16 : 22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: isWeb
            ? null
            : AppDecorations.cardDecoration.copyWith(
                borderRadius: BorderRadius.circular(22),
              ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor ?? AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor ?? AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.headline3.copyWith(
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSubtle,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
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
}

class _SwitchSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb && MediaQuery.of(context).size.width >= 650;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: isWeb
          ? null
          : AppDecorations.cardDecoration.copyWith(
              borderRadius: BorderRadius.circular(22),
            ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.headline3),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
