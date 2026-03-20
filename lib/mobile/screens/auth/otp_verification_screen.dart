import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/auth/email_service.dart';
import '../../../shared/services/auth/otp_service.dart';

/// OTP Verification Screen - User enters 6-digit code received via email
class OTPVerificationScreen extends StatefulWidget {
  final String email;
  final String name;
  final String password;
  final String? phoneNumber;
  final VoidCallback onVerificationSuccess;
  final int initialSecondsRemaining;

  const OTPVerificationScreen({
    super.key,
    required this.email,
    required this.name,
    required this.password,
    this.phoneNumber,
    required this.onVerificationSuccess,
    this.initialSecondsRemaining = 600,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _codeControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late Timer _timerCountdown;
  int _secondsRemaining = 0;
  bool _isVerifying = false;
  String? _errorMessage;
  bool _canResend = false;

  static const Color primary = Color(0xFF13EC5B);

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _secondsRemaining = widget.initialSecondsRemaining;
    _canResend = _secondsRemaining <= 0;

    _timerCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  String _getOTPCode() {
    return _codeControllers.map((c) => c.text).join();
  }

  void _handleOTPChange(int index, String value) {
    if (value.length == 1) {
      if (index < 5) {
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      } else {
        // Last digit entered, verify automatically
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
      // Verify OTP from database
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

      // OTP verified! Now create account via Supabase
      final success = await AuthService().register(
        name: widget.name,
        email: widget.email,
        password: widget.password,
        phoneNumber: widget.phoneNumber,
      );

      if (mounted) {
        setState(() => _isVerifying = false);

        if (success) {
          // Clean up OTP
          await OTPService().deleteOTP(email: widget.email);

          // Show success
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
        // Send new code via email
        final sent = await EmailService.sendOTPEmail(
          email: widget.email,
          otpCode: newCode,
        );

        if (sent) {
          _clearFields();
          _startCountdownTimer();
          _showSnackBar('Code resent to ${widget.email}');
        } else {
          setState(() =>
              _errorMessage = 'Failed to send code. Please try again.');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error resending code: $e');
    }
  }

  void _clearFields() {
    for (var controller in _codeControllers) {
      controller.clear();
    }
    FocusScope.of(context).requestFocus(_focusNodes[0]);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F7F3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Email Verified!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your account is ready to use.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  widget.onVerificationSuccess();
                },
                child: Text(
                  'Continue to Login',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _timerCountdown.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _timerCountdown.cancel();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
            onPressed: () {
              _timerCountdown.cancel();
              Navigator.pop(context);
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Email icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7F3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  color: primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Enter Verification Code',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                'We sent a 6-digit code to:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7F3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => SizedBox(
                    width: 50,
                    height: 60,
                    child: TextField(
                      controller: _codeControllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      enabled: !_isVerifying,
                      onChanged: (value) => _handleOTPChange(index, value),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primary, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red[600], fontSize: 14),
                  ),
                ),
              const SizedBox(height: 24),

              // Verify Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isVerifying ? null : _verifyOTP,
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Verify',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Timer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE0F7F3),
                    width: 1,
                  ),
                ),
                child: Text(
                  _secondsRemaining > 0
                      ? 'Code expires in ${_formatTime(_secondsRemaining)}'
                      : 'Code has expired',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _secondsRemaining > 60 ? const Color(0xFF13EC5B) : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Resend Button
              if (_canResend)
                TextButton(
                  onPressed: _resendOTP,
                  child: Text(
                    'Resend Code',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                )
              else
                Text(
                  'Didn\'t receive code?',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
