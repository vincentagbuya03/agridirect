import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/integration/email_service.dart';
import '../../../shared/services/auth/otp_service.dart';
import 'web_complete_profile_screen.dart';

/// Web OTP Verification Screen — modern 3NF Implementation.
class WebOTPVerificationScreen extends StatefulWidget {
  final String userId; // Added userId
  final String email;
  final String name;
  final String password;
  final String? phoneNumber;
  final VoidCallback onVerificationSuccess;
  final int initialSecondsRemaining;

  const WebOTPVerificationScreen({
    super.key,
    required this.userId, // Added userId
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
  final List<TextEditingController> _codeControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late Timer _timerCountdown;
  int _secondsRemaining = 0;
  bool _isVerifying = false;
  String? _errorMessage;
  bool _canResend = false;

  static const Color _primary = Color(0xFF16A34A);

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
    final minutes = (seconds < 0 ? 0 : seconds) ~/ 60;
    final secs = (seconds < 0 ? 0 : seconds) % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _getOTPCode() => _codeControllers.map((c) => c.text).join();

  void _handleOTPChange(int index, String value) {
    if (value.length == 1) {
      if (index < 5) {
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      } else {
        if (!_isVerifying) {
          _verifyOTP();
        }
      }
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }
  }

  Future<void> _verifyOTP() async {
    if (_isVerifying) return;

    final otp = _getOTPCode();
    if (otp.length != 6) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final result = await OTPService().verifyOTP(
        userId: widget.userId,
        code: otp,
      );

      if (result['success'] != true) {
        setState(() {
          _errorMessage = result['message'] ?? 'Invalid or expired code.';
          _isVerifying = false;
        });
        _clearFields();
        return;
      }

      _timerCountdown.cancel();

      final loggedIn = await AuthService().login(
        email: widget.email,
        password: widget.password,
      );

      if (!mounted) return;

      if (loggedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WebCompleteProfileScreen(
              userId: widget.userId,
              email: widget.email,
              name: widget.name,
              onFinalizeSuccess: widget.onVerificationSuccess,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage =
              'Verification successful, but login failed. Please try logging in manually.';
          _isVerifying = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isVerifying = false;
      });
    }
  }

  Future<void> _resendOTP() async {
    setState(() {
      _errorMessage = null;
      _isVerifying = true;
    });

    try {
      final newCode = await OTPService().generateAndStoreOTP(
        userId: widget.userId,
        type: 'signup',
      );

      if (newCode != null) {
        final sent = await EmailService.sendOTPEmail(
          email: widget.email,
          otpCode: newCode,
        );
        if (sent) {
          _clearFields();
          _startCountdownTimer();
          _showSnackBar('New code sent to ${widget.email}');
        } else {
          setState(() => _errorMessage = 'Email delivery failed.');
        }
      } else {
        setState(() => _errorMessage = 'Code generation failed.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  void _clearFields() {
    for (var c in _codeControllers) {
      c.clear();
    }
    FocusScope.of(context).requestFocus(_focusNodes[0]);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final isCompact = MediaQuery.of(context).size.width < 1100;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          if (!isCompact)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF047857)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.mark_email_read_rounded,
                        color: Colors.white,
                        size: 100,
                      ),
                      const SizedBox(height: 36),
                      Text(
                        'Check Your Email',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    children: [
                      Text(
                        'Enter Verification Code',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'A 6-digit code was sent to ${widget.email}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          6,
                          (i) => SizedBox(
                            width: 50,
                            height: 60,
                            child: TextField(
                              controller: _codeControllers[i],
                              focusNode: _focusNodes[i],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              onChanged: (v) => _handleOTPChange(i, v),
                              decoration: InputDecoration(
                                counterText: '',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_errorMessage != null)
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      const SizedBox(height: 18),
                      Text(
                        _isVerifying
                            ? 'Verifying code...'
                            : 'The code will verify automatically once all 6 digits are entered.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _formatTime(_secondsRemaining),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_canResend)
                        TextButton(
                          onPressed: _resendOTP,
                          child: const Text(
                            'Resend Code',
                            style: TextStyle(color: _primary),
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
