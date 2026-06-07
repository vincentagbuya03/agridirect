import 'package:flutter/material.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/offline/offline_cache_service.dart';
import '../../../shared/styles/app_theme.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final AuthService _auth = AuthService();
  final OfflineCacheService _cacheService = OfflineCacheService();
  bool _clearingCache = false;

  Future<void> _openChangePasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
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
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Change Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        suffixIcon: IconButton(
                          onPressed: () => setModalState(
                            () => obscurePassword = !obscurePassword,
                          ),
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        final error = AuthService.validatePassword(text);
                        return error;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        suffixIcon: IconButton(
                          onPressed: () => setModalState(
                            () => obscureConfirm = !obscureConfirm,
                          ),
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
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
                    const SizedBox(height: 10),
                    Text(
                      'Use at least 10 characters with uppercase, lowercase, and a number.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ],
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
                  onPressed: isSaving ? null : submit,
                  child: Text(isSaving ? 'Updating...' : 'Update Password'),
                ),
              ],
            );
          },
        );
      },
    );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Security', style: AppTextStyles.headline3),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            subtitle: 'Update the password used for your account.',
            onTap: _openChangePasswordDialog,
          ),
          const SizedBox(height: 24),
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
                  'Profile settings now include account security, cache tools, and password updates in one place.',
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

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AppDecorations.cardDecoration.copyWith(
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
