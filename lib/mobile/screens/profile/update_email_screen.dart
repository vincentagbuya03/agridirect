import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/styles/app_theme.dart';

class UpdateEmailScreen extends StatefulWidget {
  final String? initialEmail;
  const UpdateEmailScreen({super.key, this.initialEmail});

  @override
  State<UpdateEmailScreen> createState() => _UpdateEmailScreenState();
}

class _UpdateEmailScreenState extends State<UpdateEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String _currentEmail = '';
  bool _isSuccess = false;
  String _pendingNewEmail = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentEmail();
  }

  Future<void> _loadCurrentEmail() async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _currentEmail = user.email ?? widget.initialEmail ?? '';
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailChange() async {
    if (!_formKey.currentState!.validate()) return;

    final newEmail = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (newEmail == _currentEmail.toLowerCase()) {
      setState(() {
        _errorMessage = 'The new email address cannot be the same as your current email.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Verify current password credentials first for security
      final currentUser = SupabaseConfig.client.auth.currentUser;
      if (currentUser?.email != null) {
        final reauth = await SupabaseConfig.client.auth.signInWithPassword(
          email: currentUser!.email!,
          password: password,
        );
        if (reauth.user == null) {
          throw const AuthException('Incorrect password provided.');
        }
      }

      // 2. Request Email Update via Supabase Auth
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(email: newEmail),
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _pendingNewEmail = newEmail;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to update email: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(_isSuccess),
        ),
        title: Text(
          'Email Address',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _isSuccess ? _buildSuccessView() : _buildFormView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Email Card
          if (_currentEmail.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.email_outlined,
                        color: Color(0xFF059669), size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Registered Email',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currentEmail,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 12, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text(
                          'Active',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          Text(
            'Change Email Address',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your new email address and confirm your current password to proceed.',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),

          // New Email Field
          Text(
            'New Email Address',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'e.g. yourname@gmail.com',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.mail_outline_rounded,
                  color: Color(0xFF64748B), size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF059669), width: 1.5),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a valid email address';
              }
              final emailRegex =
                  RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Please enter a valid email format';
              }
              return null;
            },
          ),

          const SizedBox(height: 18),

          // Password Field
          Text(
            'Current Password',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Enter current password to verify',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  color: Color(0xFF64748B), size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF64748B),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF059669), width: 1.5),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your current password';
              }
              return null;
            },
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(
                        fontSize: 12.5, color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Security Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.security_rounded,
                    color: Color(0xFF64748B), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'For your security, a confirmation link will be sent to your new email address. Your email will be updated once verified.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitEmailChange,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(
                      'Update Email Address',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    width: 2),
              ),
              child: const Icon(Icons.mark_email_read_rounded,
                  color: Color(0xFF059669), size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'Verification Email Sent!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We sent a confirmation link to:\n$_pendingNewEmail',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please open your email inbox and click the confirmation link to complete updating your account email.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => context.pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Back to Account & Security',
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
    );
  }
}
