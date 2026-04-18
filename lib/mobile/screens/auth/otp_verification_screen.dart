import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'dart:async';
import '../../../shared/services/integration/email_service.dart';
import '../../../shared/services/auth/otp_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/styles/app_theme.dart';
import 'registration_completion_screen.dart';

/// OTP Verification Screen - Premium Design
class OTPVerificationScreen extends StatefulWidget {
  final String userId;
  final String email;
  final String name;
  final String password; // This holds the temp password used for login
  final VoidCallback onVerificationSuccess;
  final int initialSecondsRemaining;

  const OTPVerificationScreen({
    super.key,
    required this.userId,
    required this.email,
    required this.name,
    required this.password,
    required this.onVerificationSuccess,
    this.initialSecondsRemaining = 600,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
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
        _focusNodes[index].unfocus();
      }

      // Auto-submit once all 6 fields are filled.
      if (_getOTPCode().length == 6 && !_isVerifying) {
        _verifyOTP();
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
          _errorMessage = result['message'] ?? 'Invalid code';
          _isVerifying = false;
        });
        return;
      }

      _timerCountdown.cancel();

      // Create a temporary authenticated session for profile completion
      // without triggering global auth redirect to dashboard yet.
      final signInResult = await SupabaseConfig.client.auth.signInWithPassword(
        email: widget.email,
        password: widget.password,
      );

      final hasSession = signInResult.user != null;

      if (hasSession && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RegistrationCompletionScreen(
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
              'Verification succeeded, but we could not open profile setup. Please try again.';
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
        } else {
          setState(() => _errorMessage = 'Failed to send email.');
        }
      } else {
        setState(() => _errorMessage = 'Failed to generate code.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  void _clearFields() {
    for (var controller in _codeControllers) {
      controller.clear();
    }
    FocusScope.of(context).requestFocus(_focusNodes[0]);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textHeadline,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                color: AppColors.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Verify Your Email',
              style: AppTextStyles.headline1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSubtle,
                ),
                children: [
                  const TextSpan(
                    text: 'We have sent a 6-digit verification code to ',
                  ),
                  TextSpan(
                    text: widget.email,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textHeadline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) => _buildOTPField(i)),
            ),
            const SizedBox(height: 32),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 48),
            if (_isVerifying)
              Column(
                children: [
                  const SizedBox(
                    height: 24,
                    width: 24,
                    child: AppShimmerLoader(
                      color: AppColors.primary,
                      strokeWidth: 2.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Verifying code...',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSubtle,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
              Text(
                'Code will verify automatically once complete.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSubtle,
                ),
              ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: _secondsRemaining > 0
                      ? AppColors.textSubtle
                      : AppColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(_secondsRemaining),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _canResend
                        ? AppColors.textSubtle
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              "Didn't receive the code?",
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSubtle,
              ),
            ),
            TextButton(
              onPressed: _canResend ? _resendOTP : null,
              child: Text(
                'Resend New Code',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: _canResend
                      ? AppColors.primary
                      : AppColors.textSubtle.withValues(alpha: 0.5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOTPField(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
        controller: _codeControllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        onChanged: (v) => _handleOTPChange(index, v),
        style: AppTextStyles.headline2.copyWith(color: AppColors.primary),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}
