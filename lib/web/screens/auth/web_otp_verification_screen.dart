import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/auth/email_service.dart';
import '../../../shared/services/auth/otp_service.dart';

/// Web OTP Verification Screen — modern split layout.
class WebOTPVerificationScreen extends StatefulWidget {
  final String email;
  final String name;
  final String password;
  final String? phoneNumber;
  final VoidCallback onVerificationSuccess;
  final int initialSecondsRemaining;

  const WebOTPVerificationScreen({
    super.key,
    required this.email,
    required this.name,
    required this.password,
    this.phoneNumber,
    required this.onVerificationSuccess,
    this.initialSecondsRemaining = 600,
  });

  @override
  State<WebOTPVerificationScreen> createState() =>
      _WebOTPVerificationScreenState();
}

class _WebOTPVerificationScreenState extends State<WebOTPVerificationScreen> {
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late Timer _timerCountdown;
  int _secondsRemaining = 0;
  bool _isVerifying = false;
  String? _errorMessage;
  bool _canResend = false;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _accent = Color(0xFF22C55E);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF9CA3AF);
  static const Color _mutedDark = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _secondsRemaining = widget.initialSecondsRemaining;
    _canResend = _secondsRemaining <= 0;

    _timerCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          timer.cancel();
          _canResend = true;
        }
      });
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _getOTPCode() => _codeControllers.map((c) => c.text).join();

  void _handleOTPChange(int index, String value) {
    if (value.length == 1) {
      if (index < 5) {
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      } else {
        _verifyOTP();
      }
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _getOTPCode();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final verified = await OTPService().verifyOTP(
        email: widget.email,
        code: otp,
      );

      if (!verified) {
        setState(() {
          _errorMessage = 'Invalid or expired code. Please try again.';
          _isVerifying = false;
        });
        _clearFields();
        return;
      }

      final success = await AuthService().register(
        name: widget.name,
        email: widget.email,
        password: widget.password,
        phoneNumber: widget.phoneNumber,
      );

      if (mounted) {
        setState(() => _isVerifying = false);
        if (success) {
          await OTPService().deleteOTP(email: widget.email);
          _showSuccessDialog();
        } else {
          setState(() =>
              _errorMessage = AuthService().errorMessage ?? 'Registration failed');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error verifying code: $e';
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendOTP() async {
    setState(() => _errorMessage = null);
    try {
      final newCode = await OTPService().resendOTP(email: widget.email);
      if (newCode != null) {
        final sent = await EmailService.sendOTPEmail(
          email: widget.email,
          otpCode: newCode,
        );
        if (sent) {
          _clearFields();
          _startCountdownTimer();
          _showSnackBar('Code resent to ${widget.email}');
        } else {
          setState(() => _errorMessage = 'Failed to send code. Please try again.');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error resending code: $e');
    }
  }

  void _clearFields() {
    for (var c in _codeControllers) {
      c.clear();
    }
    FocusScope.of(context).requestFocus(_focusNodes[0]);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primary.withOpacity(0.1), _accent.withOpacity(0.15)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: _primary, size: 38),
              ),
              const SizedBox(height: 24),
              Text(
                'Email Verified!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your account is ready to use.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: _mutedDark, height: 1.5),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    widget.onVerificationSuccess();
                  },
                  child: Text(
                    'Continue to Login',
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
        backgroundColor: _dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    for (var c in _codeControllers) {
      c.dispose();
    }
    for (var n in _focusNodes) {
      n.dispose();
    }
    _timerCountdown.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 1100;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Left branding sidebar
          if (!isCompact)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF047857)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -80,
                      right: -60,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [_accent.withOpacity(0.12), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.15)),
                            ),
                            child: const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 44),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            'Check Your Email',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: 300,
                            child: Text(
                              'We sent a 6-digit verification code to confirm your identity',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: Colors.white.withOpacity(0.65),
                                height: 1.7,
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

          // Right form
          Expanded(
            child: Container(
              color: Colors.white,
              child: Center(
                child: SingleChildScrollView(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 440),
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 24 : 44,
                      vertical: 48,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Back button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              _timerCountdown.cancel();
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF111827)),
                            label: Text('Back',
                                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF111827))),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Mail icon
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_primary.withOpacity(0.1), _accent.withOpacity(0.1)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.mail_outline_rounded, color: _primary, size: 30),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Enter Verification Code',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'We sent a 6-digit code to:',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 14, color: _mutedDark),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.email,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),

                        // OTP Input Fields
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 56,
                              height: 64,
                              child: TextField(
                                controller: _codeControllers[index],
                                focusNode: _focusNodes[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                enabled: !_isVerifying,
                                onChanged: (v) => _handleOTPChange(index, v),
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: _primary, width: 1.5),
                                  ),
                                ),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: _dark,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 24),

                        // Error message
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.inter(color: const Color(0xFFDC2626), fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Verify Button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _primary.withOpacity(0.6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _isVerifying ? null : _verifyOTP,
                            child: _isVerifying
                                ? const SizedBox(
                                    height: 22, width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text('Verify Code',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Timer
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _secondsRemaining > 0
                                ? const Color(0xFFF0FDF4)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _secondsRemaining > 0 ? Icons.timer_outlined : Icons.timer_off_outlined,
                                size: 16,
                                color: _secondsRemaining > 60 ? _primary : const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _secondsRemaining > 0
                                    ? 'Code expires in ${_formatTime(_secondsRemaining)}'
                                    : 'Code has expired',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _secondsRemaining > 60 ? _primary : const Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Resend
                        Center(
                          child: _canResend
                              ? TextButton(
                                  onPressed: _resendOTP,
                                  child: Text(
                                    'Resend Code',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _primary,
                                    ),
                                  ),
                                )
                              : Text(
                                  "Didn't receive code? Wait for the timer.",
                                  style: GoogleFonts.inter(fontSize: 13, color: _muted),
                                ),
                        ),
                      ],
                    ),
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
