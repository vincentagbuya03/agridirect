import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/auth/textbee_otp_service.dart';
import '../../../shared/services/integration/email_service.dart';
import '../../../shared/services/auth/otp_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/router/app_routes.dart';
import 'web_complete_profile_screen.dart';

/// Web OTP Verification Screen — Supports both SMS (TextBee) and Email OTP.
class WebOTPVerificationScreen extends StatefulWidget {
  final String userId;
  final String email;
  final String name;
  final String password;
  final String? phoneNumber;
  final VoidCallback onVerificationSuccess;
  final int initialSecondsRemaining;

  const WebOTPVerificationScreen({
    super.key,
    required this.userId,
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
  int _resendCooldown = 60;

  static const Color _primary = Color(0xFF16A34A);

  bool get _isPhone =>
      widget.phoneNumber != null && widget.phoneNumber!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
    for (final node in _focusNodes) {
      node.addListener(_onFocusChange);
    }
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
    _secondsRemaining = widget.initialSecondsRemaining;
    _resendCooldown = 60;
    _canResend = false;

    _timerCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
        if (_resendCooldown > 0) {
          _resendCooldown--;
          if (_resendCooldown <= 0) {
            _canResend = true;
          }
        }
        if (_secondsRemaining <= 0) {
          timer.cancel();
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

    // 1. Full 6-digit paste
    if (digits.length >= 6) {
      for (int i = 0; i < 6; i++) {
        _codeControllers[i].text = digits[i];
      }
      _focusNodes[5].unfocus();
      setState(() {});
      if (!_isVerifying) {
        _verifyOTP();
      }
      return;
    }

    // 2. Replacing single digit
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
        _verifyOTP();
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
        _verifyOTP();
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
      _verifyOTP();
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
      if (_isPhone) {
        final isValid = await TextBeeOtpService().verifyOtp(
          phoneNumber: widget.phoneNumber!,
          enteredCode: otp,
        );
        if (!isValid) {
          _clearFields(clearError: false);
          setState(() {
            _errorMessage = 'Invalid or expired SMS code. Please try again.';
            _isVerifying = false;
          });
          return;
        }

        // Mark user profile as verified in database
        try {
          await SupabaseConfig.client
              .from('users')
              .update({
                'email_verified': true,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', widget.userId);
        } catch (dbErr) {
          debugPrint('Notice: updating user verification status in DB: $dbErr');
        }
      } else {
        final result = await OTPService().verifyOTP(
          userId: widget.userId,
          code: otp,
        );

        if (result['success'] != true) {
          _clearFields(clearError: false);
          setState(() {
            _errorMessage = result['message'] ?? 'Invalid or expired code.';
            _isVerifying = false;
          });
          return;
        }
      }

      _timerCountdown.cancel();

      final loggedIn = await AuthService().login(
        email: widget.email,
        password: widget.password,
      );

      if (!mounted) return;

      if (loggedIn) {
        if (_isPhone) {
          widget.onVerificationSuccess();
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WebCompleteProfileScreen(
                userId: widget.userId,
                email: widget.email,
                name: widget.name,
                onComplete: widget.onVerificationSuccess,
                onFinalizeSuccess: widget.onVerificationSuccess,
              ),
            ),
          );
        }
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
      if (_isPhone) {
        final ok = await TextBeeOtpService().sendOtp(
          phoneNumber: widget.phoneNumber!,
          onSuccess: (code) {
            debugPrint('TextBee SMS code resent: $code');
          },
          onError: (err) {
            debugPrint('TextBee error: $err');
          },
        );
        if (ok) {
          _clearFields();
          _startCountdownTimer();
          _showSnackBar('New SMS code sent to ${widget.phoneNumber}');
        } else {
          setState(
            () => _errorMessage =
                'SMS dispatch failed. Please check carrier signal.',
          );
        }
      } else {
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
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  void _clearFields({bool clearError = true}) {
    for (var c in _codeControllers) {
      c.clear();
    }
    FocusScope.of(context).requestFocus(_focusNodes[0]);
    if (clearError) {
      setState(() => _errorMessage = null);
    } else {
      setState(() {});
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    for (var n in _focusNodes) {
      n.removeListener(_onFocusChange);
      n.dispose();
    }
    for (var c in _codeControllers) {
      c.dispose();
    }
    _timerCountdown.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 1100;
    final destination = _isPhone ? (widget.phoneNumber ?? '') : widget.email;

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
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _isPhone
                                ? Icons.sms_rounded
                                : Icons.mark_email_read_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          _isPhone ? 'Check Your SMS' : 'Check Your Email',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _isPhone
                              ? 'A 6-digit SMS verification code has been sent directly to your phone SIM card.'
                              : 'We sent a 6-digit confirmation code to your registered email address.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15.5,
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 460),
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              context.go(AppRoutes.login);
                            }
                          },
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            size: 16,
                            color: _primary,
                          ),
                          label: Text(
                            'Back to Sign In / Register',
                            style: GoogleFonts.inter(
                              color: _primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Enter Verification Code',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'A 6-digit code was sent to $destination',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          6,
                          (i) => _buildDigitCell(i),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Color(0xFFDC2626),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFDC2626),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 18),
                      Text(
                        _isVerifying
                            ? 'Verifying code...'
                            : 'The code will verify automatically once all 6 digits are entered.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Code expires in: ${_formatTime(_secondsRemaining)}',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_canResend)
                        TextButton.icon(
                          onPressed: _resendOTP,
                          icon: const Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: _primary,
                          ),
                          label: Text(
                            'Resend Code',
                            style: GoogleFonts.inter(
                              color: _primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        )
                      else
                        Text(
                          'Resend code in ${_resendCooldown}s',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 13,
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

  Widget _buildDigitCell(int index) {
    final hasValue = _codeControllers[index].text.isNotEmpty;
    final hasFocus = _focusNodes[index].hasFocus;

    return Container(
      width: 52,
      height: 60,
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
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
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
            onChanged: (v) => _handleOTPChange(index, v),
          ),
        ),
      ),
    );
  }
}
