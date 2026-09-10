import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/router/app_routes.dart';
import '../../../shared/widgets/distinctive_phone_input.dart';
import '../../widgets/web_consumer_nav_bar.dart';

/// Desktop/Web screen for updating user phone number directly without any SMS OTP.
/// Employs real-time uniqueness validation ("don't make it same with others").
class WebUpdatePhoneScreen extends StatefulWidget {
  final String? initialPhone;
  const WebUpdatePhoneScreen({super.key, this.initialPhone});

  @override
  State<WebUpdatePhoneScreen> createState() => _WebUpdatePhoneScreenState();
}

class _WebUpdatePhoneScreenState extends State<WebUpdatePhoneScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  String _currentVerifiedPhone = '';
  String _newPhoneE164 = '';
  bool _isNewPhoneValid = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentPhone();
  }

  Future<void> _loadCurrentPhone() async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user != null) {
      try {
        final profile = await SupabaseConfig.client
            .from('users')
            .select('phone')
            .eq('user_id', user.id)
            .maybeSingle();
        final rawPhone = profile?['phone']?.toString() ??
            user.userMetadata?['phone']?.toString() ??
            widget.initialPhone ??
            '';
        if (mounted && rawPhone.isNotEmpty) {
          setState(() {
            _currentVerifiedPhone = rawPhone;
          });
        }
      } catch (e) {
        debugPrint('Error loading current phone: $e');
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_isNewPhoneValid || _newPhoneE164.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid, unique Philippine mobile number.');
      return;
    }

    if (_newPhoneE164 == AuthService.normalizeToE164(_currentVerifiedPhone)) {
      setState(() => _errorMessage = 'This is already your current mobile number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await AuthService().updatePhoneNumber(_newPhoneE164);

    if (!mounted) return;

    if (success) {
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mobile number successfully updated to ${AuthService.formatDisplayPhone(_newPhoneE164)}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) context.pop(true);
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = AuthService().errorMessage ?? 'Failed to update mobile number. Please try again.';
      });
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
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF64748B)),
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
                          const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                          const SizedBox(width: 8),
                          Text(
                            'Update Mobile Number',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Main Card
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Current verified phone card
                            if (_currentVerifiedPhone.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF059669).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.phone_android_rounded,
                                        color: Color(0xFF059669),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Current Mobile Number',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: const Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            AuthService.formatDisplayPhone(_currentVerifiedPhone),
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Linked',
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
                              const SizedBox(height: 28),
                            ],

                            Text(
                              'Update Mobile Number',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Enter your new Philippine mobile number. It will be verified instantly for uniqueness and linked to your AgriDirect account without SMS code delays.',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                color: const Color(0xFF64748B),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Distinctive Phone Input Widget
                            DistinctivePhoneInput(
                              label: 'New Mobile Number',
                              autofocus: true,
                              onChanged: (formattedE164, isValidAndUnique) {
                                setState(() {
                                  _newPhoneE164 = formattedE164;
                                  _isNewPhoneValid = isValidAndUnique;
                                  _errorMessage = null;
                                });
                              },
                            ),

                            if (_errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          color: const Color(0xFFDC2626),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 32),

                            // Action button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: (_isLoading || !_isNewPhoneValid || _isSuccess) ? null : _handleSave,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor: const Color(0xFF94A3B8),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.check_circle_rounded, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Save Mobile Number',
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
