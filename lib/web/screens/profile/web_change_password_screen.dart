import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/router/app_routes.dart';
import '../../widgets/web_consumer_nav_bar.dart';

class WebChangePasswordScreen extends StatefulWidget {
  const WebChangePasswordScreen({super.key});

  @override
  State<WebChangePasswordScreen> createState() => _WebChangePasswordScreenState();
}

class _WebChangePasswordScreenState extends State<WebChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _auth = AuthService();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final success = await _auth.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } else {
      final message = (_auth.errorMessage ?? '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isNotEmpty ? message : 'Unable to update password.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Breadcrumb
                      Row(
                        children: [
                          InkWell(
                            onTap: () => context.pop(),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.arrow_back_rounded,
                                      size: 18, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Account & Security',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('•',
                              style: TextStyle(color: Color(0xFF94A3B8))),
                          const SizedBox(width: 8),
                          Text(
                            'Change Password',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Card
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A)
                                  .withValues(alpha: 0.03),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF059669)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                        Icons.lock_reset_rounded,
                                        color: Color(0xFF059669),
                                        size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Change Password',
                                          style:
                                              GoogleFonts.plusJakartaSans(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Your password must be at least 8 characters long.',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),
                              const Divider(color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 24),

                              Text(
                                'Current Password',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _currentPasswordController,
                                obscureText: _obscureCurrent,
                                decoration: InputDecoration(
                                  hintText: 'Enter current password',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                      color: Color(0xFF64748B),
                                      size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureCurrent
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFF64748B),
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                        () => _obscureCurrent = !_obscureCurrent),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFCBD5E1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFCBD5E1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF059669), width: 1.5),
                                  ),
                                ),
                                validator: (value) => value == null || value.isEmpty
                                    ? 'Please enter your current password'
                                    : null,
                              ),

                              const SizedBox(height: 20),

                              Text(
                                'New Password',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _newPasswordController,
                                obscureText: _obscureNew,
                                decoration: InputDecoration(
                                  hintText: 'Enter new password (min. 8 characters)',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                      color: Color(0xFF64748B),
                                      size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureNew
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFF64748B),
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                        () => _obscureNew = !_obscureNew),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFCBD5E1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFCBD5E1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF059669), width: 1.5),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your new password';
                                  }
                                  if (value.length < 8) {
                                    return 'Password must be at least 8 characters long';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              Text(
                                'Confirm New Password',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirm,
                                decoration: InputDecoration(
                                  hintText: 'Re-enter new password',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                      color: Color(0xFF64748B),
                                      size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFF64748B),
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                        () => _obscureConfirm = !_obscureConfirm),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFCBD5E1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFCBD5E1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF059669), width: 1.5),
                                  ),
                                ),
                                validator: (value) {
                                  if (value != _newPasswordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 32),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : Text(
                                          'Update Password',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
