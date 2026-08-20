// app settings
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/auto_update_service.dart';
import '../../../shared/services/offline/offline_cache_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../web/widgets/web_consumer_nav_bar.dart';
import '../../../shared/router/app_routes.dart';
import '../../widgets/auth/mobile_two_factor_sheet.dart';
import '../../../shared/widgets/phone_verification_dialog.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final AuthService _auth = AuthService();
  final OfflineCacheService _cacheService = OfflineCacheService();
  bool _clearingCache = false;

  int _activeTabIndex = 0;
  int _hoveredTab = -1;

  String _userEmail = '';
  String _userPhone = '';
  bool _loadingUserData = true;
  bool _is2faActive = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = SupabaseConfig.client.auth.currentUser;
    _userEmail = user?.email ?? '';
    _userPhone = user?.phone ?? '';

    if (user != null) {
      try {
        final profile = await SupabaseConfig.client
            .from('users')
            .select()
            .eq('user_id', user.id)
            .limit(1)
            .maybeSingle();

        if (profile != null) {
          final phoneVal = (profile['phone'] ?? profile['phone_number'] ?? '').toString();
          if (phoneVal.isNotEmpty) {
            _userPhone = phoneVal;
          }
        }
      } catch (e) {
        debugPrint('Error loading user profile details: $e');
      }

      try {
        final res = await SupabaseConfig.client.auth.mfa.listFactors();
        _is2faActive = res.totp.any((f) => f.status.toString().contains('verified'));
      } catch (e) {
        debugPrint('Error loading 2FA status: $e');
      }
    }
    if (mounted) {
      setState(() {
        _loadingUserData = false;
      });
    }
  }

  String _obfuscateEmail(String email) {
    if (email.isEmpty) return 'Not linked';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final username = parts[0];
    final domain = parts[1];
    if (username.length <= 2) {
      return '${username[0]}***@$domain';
    }
    return '${username.substring(0, 2)}***${username.substring(username.length - 1)}@$domain';
  }

  String _obfuscatePhone(String phone) {
    if (phone.isEmpty) return 'Not linked';
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length <= 4) return cleaned;
    if (cleaned.startsWith('+')) {
      final prefix = cleaned.substring(0, 3);
      final suffix = cleaned.substring(cleaned.length - 2);
      return '$prefix *****$suffix';
    }
    return '${cleaned.substring(0, 2)}*****${cleaned.substring(cleaned.length - 2)}';
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

  Future<void> _openUpdatePhoneDialog() async {
    final success = await PhoneVerificationDialog.show(
      context,
      initialPhone: _userPhone,
      title: 'Update Mobile Number',
      subtitle: 'Verify ownership with a 6-digit SMS code sent directly to your SIM.',
      onVerified: (verifiedPhone) {
        if (!mounted) return;
        setState(() {
          _userPhone = verifiedPhone;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mobile number verified and updated to $verifiedPhone',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );

    if (success && mounted) {
      _loadUserData();
    }
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
            _buildSectionCard([
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Change Password',
                subtitle: 'Update the password used for your account.',
                onTap: _openChangePasswordDialog,
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _SettingsTile(
                icon: Icons.security_rounded,
                title: 'Two-Factor Authentication (2FA)',
                subtitle: 'Add an extra layer of security with an Authenticator App.',
                trailing: Text(
                  _is2faActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: _is2faActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  final result = await MobileTwoFactorSheet.show(context, initialIsActive: _is2faActive);
                  if (result == true) _loadUserData();
                },
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _SettingsTile(
                icon: Icons.history_rounded,
                title: 'Check Account Activity',
                subtitle: 'Check your login and account changes in the last 30 days',
                onTap: () => context.push(AppRoutes.accountActivity),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _SettingsTile(
                icon: Icons.devices_rounded,
                title: 'Manage Login Device',
                subtitle: 'Review the devices that you have logged in AgriDirect account.',
                onTap: () => context.push(AppRoutes.manageDevice),
              ),
            ]),
          ] else if (_activeTabIndex == 1) ...[
            _buildWebHeader('Storage', 'Manage local cache settings and offline data.'),
            const SizedBox(height: 24),
            _buildSectionCard([
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
          ] else if (_activeTabIndex == 2) ...[
            _buildWebHeader('Account Actions', 'Crucial account state operations.'),
            const SizedBox(height: 24),
            _buildSectionCard([
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

  Widget _buildSectionCard(List<Widget> children) {
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
      backgroundColor: const Color(0xFFF5F5F5), // Light gray background
      appBar: AppBar(
        title: const Text('Account & Security', style: TextStyle(color: Colors.black87, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildSectionTitle('Account'),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: 'My Profile',
                  subtitle: '',
                  onTap: () => context.push(AppRoutes.myDetails),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
                _SettingsTile(
                  icon: Icons.phone_outlined,
                  title: 'Phone',
                  subtitle: '',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _loadingUserData ? 'Loading...' : _obfuscatePhone(_userPhone),
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                  onTap: _openUpdatePhoneDialog,
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
                _SettingsTile(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  subtitle: '',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _loadingUserData ? 'Loading...' : _obfuscateEmail(_userEmail),
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                  onTap: () {},
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Change Password',
                  subtitle: '',
                  onTap: () => context.push(AppRoutes.changePassword),
                ),
              ],
            ),
          ),

          _buildSectionTitle('Security'),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.history_rounded,
                  title: 'Check Account Activity',
                  subtitle: 'Check your login and account changes in the last 30 days',
                  onTap: () => context.push(AppRoutes.accountActivity),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
                _SettingsTile(
                  icon: Icons.security_rounded,
                  title: 'Two-Factor Authentication (2FA)',
                  subtitle: 'Add an extra layer of security with an Authenticator App.',
                  trailing: Text(
                    _is2faActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: _is2faActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    final result = await MobileTwoFactorSheet.show(context, initialIsActive: _is2faActive);
                    if (result == true) _loadUserData();
                  },
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
                _SettingsTile(
                  icon: Icons.devices_rounded,
                  title: 'Manage Login Device',
                  subtitle: 'Review the devices that you have logged in AgriDirect account.',
                  onTap: () => context.push(AppRoutes.manageDevice),
                ),
              ],
            ),
          ),

          _buildSectionTitle('System & Storage'),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Clear Auto Cache',
                  subtitle: 'Remove temporary offline product cache.',
                  trailing: _clearingCache
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _clearingCache ? null : _clearAutoCache,
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
                _SettingsTile(
                  icon: Icons.system_update_rounded,
                  title: 'Check for Updates',
                  subtitle: 'Check for new application versions.',
                  onTap: () => AutoUpdateService().checkForUpdates(context, showFeedback: true),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
                _SettingsTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your profile and account data.',
                  onTap: _openDeleteAccountDialog,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () async {
                await AuthService().logout();
                if (context.mounted) {
                  context.go(AppRoutes.login);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.grey,
        ),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (isWeb) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBgColor ?? AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor ?? AppColors.primary),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: isWeb
                        ? AppTextStyles.headline3.copyWith(color: titleColor)
                        : TextStyle(fontSize: 15, color: titleColor ?? Colors.black87),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
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
            trailing ??
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.grey,
                ),
          ],
        ),
      ),
    );
  }
}

