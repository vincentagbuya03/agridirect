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

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
    for (final node in _focusNodes) {
      node.addListener(_onFocusChange);
    }
    // Automatically focus the first input cell on dialog presentation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
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
    for (final node in _focusNodes) {
      node.removeListener(_onFocusChange);
      node.dispose();
    }
    for (final c in _codeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  String _getOTPCode() => _codeControllers.map((c) => c.text).join();

  void _handleOTPChange(int index, String value) {
    if (value.isEmpty) {
      setState(() {});
      return;
    }

    final digits = value.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.isEmpty) {
      _codeControllers[index].clear();
      setState(() {});
      return;
    }

    // 1. Full 6-digit paste (e.g. copied from SMS)
    if (digits.length >= 6) {
      for (int i = 0; i < 6; i++) {
        _codeControllers[i].text = digits[i];
      }
      _focusNodes[5].unfocus();
      setState(() {});
      if (!_isVerifying) {
        _verifyCode();
      }
      return;
    }

    // 2. Replacing single digit (field already had a digit, user typed a new one)
    if (digits.length == 2) {
      final newChar = digits[digits.length - 1];
      _codeControllers[index].text = newChar;
      setState(() {});
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
      if (_getOTPCode().length == 6 && !_isVerifying) {
        _verifyCode();
      }
      return;
    }

    // 3. Partial multi-digit entry
    if (digits.length > 2) {
      for (int i = 0; i < digits.length && (index + i) < 6; i++) {
        _codeControllers[index + i].text = digits[i];
      }
      final next = (index + digits.length < 6) ? (index + digits.length) : 5;
      _focusNodes[next].requestFocus();
      setState(() {});
      if (_getOTPCode().length == 6 && !_isVerifying) {
        _verifyCode();
      }
      return;
    }

    // 4. Standard single digit entry
    _codeControllers[index].text = digits;
    setState(() {});

    if (index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }

    if (_getOTPCode().length == 6 && !_isVerifying) {
      _verifyCode();
    }
  }

  void _clearFields({bool clearError = true}) {
    for (final c in _codeControllers) {
      c.clear();
    }
    if (_focusNodes.isNotEmpty) {
      FocusScope.of(context).requestFocus(_focusNodes[0]);
    }
    if (clearError) {
      setState(() => _errorMessage = null);
    } else {
      setState(() {});
    }
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

    FocusScope.of(context).unfocus();

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
        _clearFields(clearError: false);
        setState(() {
          _isVerifying = false;
          _errorMessage =
              'Invalid or expired verification code. Please check your SMS and try again.';
        });
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

              const SizedBox(height: 14),

              // Auto-verify status or helper hint
              if (_isVerifying)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Verifying code automatically...',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                  ],
                )
              else if (_errorMessage == null)
                Text(
                  'Code verifies automatically once all 6 digits are entered',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
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
    final size = isCompact ? 46.0 : 52.0;

    return Container(
      width: size,
      height: size + 8,
      decoration: BoxDecoration(
        color: hasFocus
            ? Colors.white
            : (hasValue ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasFocus
              ? _primary
              : (hasValue
                  ? _primary.withValues(alpha: 0.6)
                  : const Color(0xFFCBD5E1)),
          width: hasFocus ? 2.0 : 1.5,
        ),
        boxShadow: hasFocus
            ? [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.backspace ||
               event.physicalKey == PhysicalKeyboardKey.backspace)) {
            if (_codeControllers[index].text.isNotEmpty) {
              _codeControllers[index].clear();
              setState(() {});
              return KeyEventResult.handled;
            } else if (index > 0) {
              _codeControllers[index - 1].clear();
              _focusNodes[index - 1].requestFocus();
              setState(() {});
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Center(
          child: TextField(
            controller: _codeControllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            showCursor: true,
            cursorColor: _primary,
            cursorWidth: 2,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onTap: () {
              _codeControllers[index].selection = TextSelection(
                baseOffset: 0,
                extentOffset: _codeControllers[index].text.length,
              );
            },
            style: GoogleFonts.plusJakartaSans(
              fontSize: isCompact ? 20 : 22,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            onChanged: (val) => _handleOTPChange(index, val),
          ),
        ),
      ),
    );
  }
}
