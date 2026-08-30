import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/auto_update_service.dart';
import '../../../shared/services/offline/offline_cache_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/router/app_routes.dart';
import '../../widgets/web_consumer_nav_bar.dart';
import '../../../mobile/widgets/auth/mobile_two_factor_sheet.dart';

class WebAppSettingsScreen extends StatefulWidget {
  const WebAppSettingsScreen({super.key});

  @override
  State<WebAppSettingsScreen> createState() => _WebAppSettingsScreenState();
}

class _WebAppSettingsScreenState extends State<WebAppSettingsScreen> {
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
    setState(() => _loadingUserData = true);
    final user = SupabaseConfig.client.auth.currentUser;
    if (user != null) {
      String email = user.email ?? '';
      String phone = '';

      try {
        final profile = await SupabaseConfig.client
            .from('users')
            .select('phone, two_factor_enabled')
            .eq('user_id', user.id)
            .maybeSingle();

        if (profile != null) {
          phone = profile['phone'] ?? '';
          _is2faActive = profile['two_factor_enabled'] ?? false;
        }

        final factors = await SupabaseConfig.client.auth.mfa.listFactors();
        if (factors.totp.isNotEmpty) {
          _is2faActive = factors.totp.any((f) => f.status.toString().contains('verified'));
        }
      } catch (e) {
        debugPrint('Web load profile data error: $e');
      }

      if (mounted) {
        setState(() {
          _userEmail = email;
          _userPhone = phone;
          _loadingUserData = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _loadingUserData = false);
      }
    }
  }

  String _obfuscateEmail(String email) {
    if (email.isEmpty) return 'None registered';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '$name***@$domain';
    return '${name.substring(0, 2)}***${name.substring(name.length - 1)}@$domain';
  }

  String _obfuscatePhone(String phone) {
    if (phone.isEmpty) return 'None registered';
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 4) return phone;
    if (digits.length == 10) {
      return '09*****${digits.substring(8)}';
    } else if (digits.length == 11) {
      return '09*****${digits.substring(9)}';
    } else if (digits.length >= 12 && digits.startsWith('63')) {
      final sub = digits.substring(2);
      return '09*****${sub.substring(sub.length - 2)}';
    }
    return phone;
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
        content: Text('Auto-cached products cleared successfully.'),
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
                context.go(AppRoutes.login);
              } catch (e) {
                setModalState(() => isDeleting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete account: $e')),
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
                  SizedBox(width: 8),
                  Text('Delete Account permanently?'),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WARNING: This action is permanent. All your personal data, products, and order history will be permanently deleted.',
                        style: TextStyle(fontSize: 13, color: AppColors.error, height: 1.4, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      const Text('Please type "DELETE" to confirm:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: confirmationController,
                        decoration: InputDecoration(
                          hintText: 'DELETE',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) => value?.trim() != 'DELETE' ? 'Please type "DELETE" exactly.' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          WebConsumerNavBar(
            currentIndex: 3,
            onNavigate: (index) {
              if (index == 0) context.go(AppRoutes.home);
              if (index == 1) context.go(AppRoutes.shop);
              if (index == 2) context.go(AppRoutes.community);
              if (index == 3) context.go(AppRoutes.profile);
            },
            onCartTap: () => context.go(AppRoutes.cart),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWebSidebar(),
                Container(width: 1, color: const Color(0xFFE2E8F0)),
                Expanded(child: _buildWebSettingsContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebSidebar() {
    final categories = [
      {'title': 'Account & Security', 'icon': Icons.shield_outlined},
      {'title': 'Storage & Cache', 'icon': Icons.cleaning_services_outlined},
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
                    child: const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF475569)),
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
                          color: isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          cat['title'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                            color: isActive ? const Color(0xFF047857) : const Color(0xFF334155),
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
            _buildWebHeader('Account & Security', 'Manage your login details and account authentication.'),
            const SizedBox(height: 24),
            _buildSectionCard([
              _WebSettingsTile(
                icon: Icons.phone_outlined,
                title: 'Mobile Number',
                subtitle: 'Verified phone for order delivery and driver communication.',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _loadingUserData ? 'Loading...' : _obfuscatePhone(_userPhone),
                      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  ],
                ),
                onTap: () async {
                  final result = await context.push(AppRoutes.updatePhone);
                  if (result == true || mounted) _loadUserData();
                },
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _WebSettingsTile(
                icon: Icons.email_outlined,
                title: 'Email Address',
                subtitle: 'Primary email used for receipts and account recovery.',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _loadingUserData ? 'Loading...' : _obfuscateEmail(_userEmail),
                      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  ],
                ),
                onTap: () async {
                  final result = await context.push(AppRoutes.updateEmail);
                  if (result == true || mounted) _loadUserData();
                },
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _WebSettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Change Password',
                subtitle: 'Update your account login password.',
                onTap: () => context.push(AppRoutes.changePassword),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _WebSettingsTile(
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
              _WebSettingsTile(
                icon: Icons.history_rounded,
                title: 'Check Account Activity',
                subtitle: 'Review your login and security events in the last 30 days.',
                onTap: () => context.push(AppRoutes.accountActivity),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _WebSettingsTile(
                icon: Icons.devices_rounded,
                title: 'Manage Login Devices',
                subtitle: 'Review the devices that have logged in to your AgriDirect account.',
                onTap: () => context.push(AppRoutes.manageDevice),
              ),
            ]),
          ] else if (_activeTabIndex == 1) ...[
            _buildWebHeader('Storage & Cache', 'Manage temporary offline cache and data storage.'),
            const SizedBox(height: 24),
            _buildSectionCard([
              _WebSettingsTile(
                icon: Icons.cleaning_services_outlined,
                title: 'Clear Offline Product Cache',
                subtitle: 'Remove temporary cached images and product listings.',
                trailing: _clearingCache
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                onTap: _clearingCache ? null : _clearAutoCache,
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _WebSettingsTile(
                icon: Icons.system_update_rounded,
                title: 'Application Version',
                subtitle: 'AgriDirect Web Build v1.0.3 (Latest)',
                trailing: const Text('Up to date', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                onTap: () => AutoUpdateService().checkForUpdates(context, showFeedback: true),
              ),
            ]),
          ] else if (_activeTabIndex == 2) ...[
            _buildWebHeader('Account Actions', 'Irreversible actions regarding your account.'),
            const SizedBox(height: 24),
            _buildSectionCard([
              _WebSettingsTile(
                icon: Icons.delete_forever_rounded,
                title: 'Delete Account',
                subtitle: 'Permanently delete your profile, store listings, and account data.',
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
      child: Column(children: children),
    );
  }
}

class _WebSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? iconBgColor;
  final Color? titleColor;

  const _WebSettingsTile({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBgColor ?? const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: iconColor ?? const Color(0xFF475569)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titleColor ?? const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
