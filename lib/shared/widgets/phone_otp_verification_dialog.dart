import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth/textbee_otp_service.dart';
import 'app_shimmer_loader.dart';

/// Reusable Phone OTP Verification Dialog used across Mobile & Web
/// for verifying Philippine mobile numbers via real carrier SMS (TextBee).
class PhoneOtpVerificationDialog extends StatefulWidget {
  final String phoneNumber;
  final String? title;
  final String? subtitle;

  const PhoneOtpVerificationDialog({
    super.key,
    required this.phoneNumber,
    this.title,
    this.subtitle,
  });

  @override
  State<PhoneOtpVerificationDialog> createState() =>
      _PhoneOtpVerificationDialogState();
}

class _PhoneOtpVerificationDialogState
    extends State<PhoneOtpVerificationDialog> {
  final List<TextEditingController> _codeControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late Timer _timerCountdown;
  int _secondsRemaining = 60;
  bool _canResend = false;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _inputBg = Color(0xFFF9FAFB);

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _secondsRemaining = 60;
    _canResend = false;

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

  @override
  void dispose() {
    _timerCountdown.cancel();
    for (final c in _codeControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _getOTPCode() => _codeControllers.map((c) => c.text).join();

  void _handleOTPChange(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^\d]'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _codeControllers[i].text = digits[i];
      }
      final next = (digits.length < 6) ? digits.length : 5;
      FocusScope.of(context).requestFocus(_focusNodes[next]);
      setState(() {});
      if (_getOTPCode().length == 6 && !_isVerifying) {
        _verifyCode();
      }
      return;
    }

    setState(() {});

    if (value.length == 1) {
      if (index < 5) {
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      } else {
        _focusNodes[index].unfocus();
      }

      if (_getOTPCode().length == 6 && !_isVerifying) {
        _verifyCode();
      }
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }
  }

  void _clearFields() {
    for (final c in _codeControllers) {
      c.clear();
    }
    if (_focusNodes.isNotEmpty) {
      FocusScope.of(context).requestFocus(_focusNodes[0]);
    }
    setState(() => _errorMessage = null);
  }

  Future<void> _verifyCode() async {
    if (_isVerifying) return;
    final code = _getOTPCode();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of your SMS code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final isValid = await TextBeeOtpService().verifyOtp(
        phoneNumber: widget.phoneNumber,
        enteredCode: code,
      );

      if (!mounted) return;

      if (isValid) {
        _timerCountdown.cancel();
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isVerifying = false;
          _errorMessage =
              'Invalid or expired verification code. Please check your SMS and try again.';
        });
        _clearFields();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Verification error: $e';
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final success = await TextBeeOtpService().sendOtp(
      phoneNumber: widget.phoneNumber,
      onSuccess: (code) {
        debugPrint('✅ TextBee SMS OTP resent to: ${widget.phoneNumber}');
      },
      onError: (err) {
        debugPrint('⚠️ TextBee SMS resend error: $err');
      },
    );

    if (!mounted) return;

    setState(() {
      _isResending = false;
    });

    if (success) {
      _clearFields();
      _startCountdownTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'New 6-digit code dispatched to ${widget.phoneNumber}',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      setState(() {
        _errorMessage =
            'Failed to resend SMS code. Please check your signal and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 450;

    return Dialog(
      backgroundColor: Colors.white,
      elevation: 16,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 20 : 32,
            vertical: 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sms_outlined,
                  color: _primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                widget.title ?? 'Verify Phone Number',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _muted,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                      text: 'We sent a 6-digit SMS verification code to\n',
                    ),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 6 PIN Input Cells
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _buildDigitCell(i, isCompact)),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFFB91C1C),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Verify button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isVerifying
                      ? const AppShimmerLoader(color: Colors.white)
                      : Text(
                          'Verify & Continue',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Resend code row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _canResend
                        ? "Didn't receive code? "
                        : "Resend code in 0:${_secondsRemaining.toString().padLeft(2, '0')}",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_canResend)
                    GestureDetector(
                      onTap: _isResending ? null : _resendCode,
                      child: Text(
                        _isResending ? 'Sending...' : 'Resend SMS',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Cancel button
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Change Mobile Number',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDigitCell(int index, bool isCompact) {
    final hasValue = _codeControllers[index].text.isNotEmpty;
    final hasFocus = _focusNodes[index].hasFocus;
    final size = isCompact ? 44.0 : 50.0;

    return SizedBox(
      width: size,
      height: size + 6,
      child: TextField(
        controller: _codeControllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.plusJakartaSans(
          fontSize: isCompact ? 20 : 22,
          fontWeight: FontWeight.w800,
          color: _dark,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: hasFocus ? Colors.white : _inputBg,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasFocus ? _primary : _border,
              width: hasFocus ? 2 : 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasValue ? _primary.withValues(alpha: 0.5) : _border,
              width: hasValue ? 1.5 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 2),
          ),
        ),
        onChanged: (val) => _handleOTPChange(index, val),
      ),
    );
  }
}
