import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth/textbee_otp_service.dart';
import '../services/auth/auth_service.dart';
import '../services/core/supabase_config.dart';

/// Professional Bottom Sheet Modal for Mobile Phone Verification & Updates
class PhoneVerificationDialog extends StatefulWidget {
  final String? initialPhone;
  final String title;
  final String subtitle;
  final Function(String verifiedPhone)? onVerified;

  const PhoneVerificationDialog({
    super.key,
    this.initialPhone,
    this.title = 'Update Mobile Number',
    this.subtitle = 'Verify ownership with a 6-digit SMS code sent directly to your SIM.',
    this.onVerified,
  });

  /// Opens as a modern, luxury bottom sheet modal
  static Future<bool> show(
    BuildContext context, {
    String? initialPhone,
    String title = 'Update Mobile Number',
    String subtitle = 'Verify ownership with a 6-digit SMS code sent directly to your SIM.',
    Function(String verifiedPhone)? onVerified,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PhoneVerificationDialog(
        initialPhone: initialPhone,
        title: title,
        subtitle: subtitle,
        onVerified: onVerified,
      ),
    );
    return result ?? false;
  }

  @override
  State<PhoneVerificationDialog> createState() =>
      _PhoneVerificationDialogState();
}

class _PhoneVerificationDialogState extends State<PhoneVerificationDialog> {
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _pinControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(6, (_) => FocusNode());
  final TextBeeOtpService _textBeeService = TextBeeOtpService();

  bool _isCodeSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  Timer? _timer;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      var phone = widget.initialPhone!.replaceAll(RegExp(r'[^\d]'), '');
      // Strip country code 63 or leading 0
      if (phone.startsWith('63') && phone.length > 2) {
        phone = phone.substring(2);
      }
      if (phone.startsWith('0') && phone.length > 1) {
        phone = phone.substring(1);
      }
      _phoneController.text = phone;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    for (var c in _pinControllers) {
      c.dispose();
    }
    for (var f in _pinFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendOtp() async {
    final rawDigits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '').trim();
    if (rawDigits.isEmpty || rawDigits.length < 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number (e.g. 912 345 6789)');
      return;
    }

    final fullNumber = '+63$rawDigits';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = SupabaseConfig.client.auth.currentUser;
    final isTaken = await AuthService.isPhoneAlreadyRegistered(
      fullNumber,
      excludeUserId: currentUser?.id,
    );

    if (isTaken) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'This mobile number is already linked to another account.';
      });
      return;
    }

    await _textBeeService.sendOtp(
      phoneNumber: fullNumber,
      onSuccess: (code) {
        if (!mounted) return;
        setState(() {
          _isCodeSent = true;
          _isLoading = false;
        });
        _startCountdown();
        _pinFocusNodes[0].requestFocus();
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = err;
        });
      },
    );
  }

  Future<void> _verifyOtp() async {
    final code = _pinControllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    final rawDigits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '').trim();
    final formatted = '+63$rawDigits';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isValid = _textBeeService.verifyOtp(
      phoneNumber: formatted,
      enteredCode: code,
    );

    if (isValid) {
      try {
        final user = SupabaseConfig.client.auth.currentUser;
        if (user != null) {
          await SupabaseConfig.client.auth.updateUser(
            UserAttributes(data: {'phone': formatted}),
          );
          await SupabaseConfig.client
              .from('users')
              .update({'phone': formatted})
              .eq('user_id', user.id);
        }

        if (widget.onVerified != null) {
          widget.onVerified!(formatted);
        }

        if (!mounted) return;
        Navigator.of(context).pop(true);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to save to profile: $e';
        });
      }
    } else {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid or expired SMS code. Please try again.';
      });
      for (var c in _pinControllers) {
        c.clear();
      }
      _pinFocusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x2A0F172A),
              blurRadius: 30,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Drag Handle Pill
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Icon(
                            _isCodeSent
                                ? Icons.mark_email_read_rounded
                                : Icons.phone_iphone_rounded,
                            color: const Color(0xFF059669),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isCodeSent ? 'Enter SMS Code' : widget.title,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _isCodeSent
                                    ? '6-digit PIN sent to +63 ${_phoneController.text}'
                                    : widget.subtitle,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: const Color(0xFF64748B),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF94A3B8)),
                          splashRadius: 20,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Error Banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFDC2626),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // STEP 1: Phone Input
                    if (!_isCodeSent) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Flag Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🇵🇭', style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '+63',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Clean Text Field
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                enabled: !_isLoading,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: 0.5,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10), // 9XXXXXXXXX
                                ],
                                decoration: InputDecoration(
                                  hintText: '9XX XXX XXXX',
                                  hintStyle: GoogleFonts.inter(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Send Button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _sendOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
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
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],

                    // STEP 2: 6 PIN Boxes
                    if (_isCodeSent) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: 46,
                            height: 54,
                            child: TextField(
                              controller: _pinControllers[index],
                              focusNode: _pinFocusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF059669),
                              ),
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: EdgeInsets.zero,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF059669),
                                    width: 2,
                                  ),
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

                      const SizedBox(height: 18),

                      // Timer / Resend Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isCodeSent = false;
                                _errorMessage = null;
                              });
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  'Change Number',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_secondsRemaining > 0)
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF059669)),
                                const SizedBox(width: 4),
                                Text(
                                  'Resend in ${_secondsRemaining}s',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            )
                          else
                            GestureDetector(
                              onTap: _isLoading ? null : _sendOtp,
                              child: Text(
                                'Resend SMS',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF059669),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Verify Button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Verify & Save Mobile Number',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
