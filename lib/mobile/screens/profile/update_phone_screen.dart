import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/auth/textbee_otp_service.dart';
import '../../../shared/styles/app_theme.dart';

class UpdatePhoneScreen extends StatefulWidget {
  final String? initialPhone;
  const UpdatePhoneScreen({super.key, this.initialPhone});

  @override
  State<UpdatePhoneScreen> createState() => _UpdatePhoneScreenState();
}

class _UpdatePhoneScreenState extends State<UpdatePhoneScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _pinControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(6, (_) => FocusNode());

  final TextBeeOtpService _textBeeService = TextBeeOtpService();

  int _step = 1; // 1: Enter Phone, 2: Enter OTP, 3: Success
  bool _isLoading = false;
  String? _errorMessage;
  String _currentVerifiedPhone = '';
  String _formattedTargetPhone = '';

  Timer? _countdownTimer;
  int _countdownSeconds = 60;
  bool _canResend = false;

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
            // Pre-fill only the local 10 digits if empty
            if (_phoneController.text.isEmpty) {
              var digits = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
              if (digits.startsWith('63')) digits = digits.substring(2);
              if (digits.startsWith('0')) digits = digits.substring(1);
              _phoneController.text = digits;
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading current phone: $e');
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdownSeconds = 60;
      _canResend = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _countdownSeconds = 0;
          _canResend = true;
        });
      } else {
        setState(() {
          _countdownSeconds--;
        });
      }
    });
  }

  Future<void> _sendOtp() async {
    final rawDigits =
        _phoneController.text.replaceAll(RegExp(r'[^\d]'), '').trim();

    if (rawDigits.length != 10 && rawDigits.length != 11) {
      setState(() => _errorMessage = 'Please enter a valid 10 or 11-digit mobile number (e.g. 9123456789)');
      return;
    }

    final normalized = rawDigits.startsWith('0') ? rawDigits.substring(1) : rawDigits;
    if (normalized.length != 10 || !normalized.startsWith('9')) {
      setState(() => _errorMessage = 'Mobile numbers must start with 9 (e.g. 9123456789)');
      return;
    }

    final formatted = '+63$normalized';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _formattedTargetPhone = formatted;
    });

    try {
      final success = await _textBeeService.sendOtp(
        phoneNumber: formatted,
        onSuccess: (code) {
          debugPrint('SMS OTP successfully sent: $code');
        },
        onError: (err) {
          debugPrint('SMS OTP error: $err');
          if (mounted) {
            setState(() => _errorMessage = err);
          }
        },
      );

      if (success) {
        if (!mounted) return;
        setState(() {
          _step = 2;
          _isLoading = false;
        });
        _startCountdown();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _pinFocusNodes[0].requestFocus();
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = _errorMessage ??
              'Failed to send SMS code. Please check your signal or try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error sending SMS: $e';
      });
    }
  }

  Future<void> _verifyOtp() async {
    final code = _pinControllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of the code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isValid = _textBeeService.verifyOtp(
        phoneNumber: _formattedTargetPhone,
        enteredCode: code,
      );

      if (isValid) {
        final user = SupabaseConfig.client.auth.currentUser;
        if (user != null) {
          // Update in Auth
          await SupabaseConfig.client.auth.updateUser(
            UserAttributes(data: {'phone': _formattedTargetPhone}),
          );

          // Update in Public Users Table
          await SupabaseConfig.client
              .from('users')
              .update({
                'phone': _formattedTargetPhone,
                'phone_verified': true,
              })
              .eq('user_id', user.id);
        }

        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _step = 3;
        });

        // Delay then pop with true
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            context.pop(true);
          }
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Incorrect 6-digit verification code. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Verification error: $e';
      });
    }
  }

  String _formatDisplayPhone(String phone) {
    if (phone.isEmpty) return 'None registered';
    var digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('63') && digits.length >= 12) {
      final p = digits.substring(2);
      return '+63 ${p.substring(0, 3)} ${p.substring(3, 6)} ${p.substring(6)}';
    }
    return phone;
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
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Mobile Number',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_step == 1) _buildStep1EnterPhone(),
                  if (_step == 2) _buildStep2EnterOtp(),
                  if (_step == 3) _buildStep3Success(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1EnterPhone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current verified phone card
        if (_currentVerifiedPhone.isNotEmpty) ...[
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
                  child: const Icon(Icons.phone_android_rounded,
                      color: Color(0xFF059669), size: 20),
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
                        _formatDisplayPhone(_currentVerifiedPhone),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
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
                        'Verified',
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
          'Enter New Mobile Number',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'We will send a 6-digit SMS verification code to confirm ownership of this number.',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: const Color(0xFF64748B),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),

        // Phone Input
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _errorMessage != null
                  ? AppColors.error
                  : const Color(0xFFCBD5E1),
              width: _errorMessage != null ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🇵🇭', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      '+63',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                  decoration: InputDecoration(
                    hintText: '912 345 6789',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 15,
                      color: const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
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

        // Information banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFF64748B), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your mobile number is used to receive real-time order delivery updates and connect directly with riders and farmers.',
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
            onPressed: _isLoading ? null : _sendOtp,
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
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Send SMS Verification Code',
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
    );
  }

  Widget _buildStep2EnterOtp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sms_rounded,
                    color: Color(0xFF0EA5E9), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SMS Code Sent To',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDisplayPhone(_formattedTargetPhone),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _step = 1;
                    _errorMessage = null;
                  });
                },
                child: Text(
                  'Change',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        Text(
          'Enter 6-Digit Code',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Check your phone messages and enter the verification code below.',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: const Color(0xFF64748B),
          ),
        ),

        const SizedBox(height: 20),

        // 6-digit PIN boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 48,
              height: 56,
              child: TextField(
                controller: _pinControllers[index],
                focusNode: _pinFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(1),
                ],
                decoration: InputDecoration(
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
                    borderSide: const BorderSide(
                        color: Color(0xFF059669), width: 2),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    _pinFocusNodes[index + 1].requestFocus();
                  } else if (value.isEmpty && index > 0) {
                    _pinFocusNodes[index - 1].requestFocus();
                  }
                  if (_pinControllers.every((c) => c.text.isNotEmpty)) {
                    _verifyOtp();
                  }
                },
              ),
            );
          }),
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

        const SizedBox(height: 28),

        // Resend Timer Row
        Center(
          child: _canResend
              ? TextButton.icon(
                  onPressed: _isLoading ? null : _sendOtp,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    'Resend Verification Code',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF059669),
                    ),
                  ),
                )
              : Text(
                  'Resend code in $_countdownSeconds seconds',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
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
                    'Verify & Update Mobile Number',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Success() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    width: 2),
              ),
              child: const Icon(Icons.check_rounded,
                  color: Color(0xFF059669), size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'Mobile Number Updated!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your mobile number has been successfully verified as\n$_formattedTargetPhone',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(Color(0xFF059669)),
            ),
          ],
        ),
      ),
    );
  }
}
