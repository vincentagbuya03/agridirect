import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth/textbee_otp_service.dart';
import '../services/auth/auth_service.dart';
import '../services/core/supabase_config.dart';

/// Professional inline widget for phone number input + 6-digit SMS OTP verification
class PhoneVerificationInputWidget extends StatefulWidget {
  final String? initialPhone;
  final Function(String verifiedPhoneNumber) onVerified;
  final Function(bool isVerified)? onVerificationStateChanged;

  const PhoneVerificationInputWidget({
    super.key,
    this.initialPhone,
    required this.onVerified,
    this.onVerificationStateChanged,
  });

  @override
  State<PhoneVerificationInputWidget> createState() =>
      _PhoneVerificationInputWidgetState();
}

class _PhoneVerificationInputWidgetState
    extends State<PhoneVerificationInputWidget> {
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _pinControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isCodeSent = false;
  bool _isVerified = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _verifiedPhoneNumber = '';

  Timer? _timer;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      var phone = widget.initialPhone!.replaceAll(RegExp(r'[^\d]'), '');
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

  final TextBeeOtpService _textBeeService = TextBeeOtpService();

  Future<void> _sendOtp() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty || rawPhone.length < 10) {
      setState(() => _errorMessage = 'Please enter a valid 11-digit mobile number (e.g. 09123456789)');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = SupabaseConfig.client.auth.currentUser;
    final isTaken = await AuthService.isPhoneAlreadyRegistered(
      rawPhone,
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

    // TextBee Free SMS Gateway (Direct SIM text from your paired Android phone)
    await _textBeeService.sendOtp(
      phoneNumber: rawPhone,
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
        debugPrint('TextBee error: $err');
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isValid = _textBeeService.verifyOtp(
      phoneNumber: _phoneController.text.trim(),
      enteredCode: code,
    );

    if (isValid) {
      if (!mounted) return;
      _markAsVerified();
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

  void _markAsVerified() {
    final formatted = TextBeeOtpService.formatE164(_phoneController.text.trim());
    setState(() {
      _isVerified = true;
      _isLoading = false;
      _errorMessage = null;
      _verifiedPhoneNumber = formatted;
    });
    widget.onVerified(formatted);
    if (widget.onVerificationStateChanged != null) {
      widget.onVerificationStateChanged!(true);
    }
  }

  void _resetToEdit() {
    setState(() {
      _isCodeSent = false;
      _isVerified = false;
      _errorMessage = null;
      for (var c in _pinControllers) {
        c.clear();
      }
    });
    if (widget.onVerificationStateChanged != null) {
      widget.onVerificationStateChanged!(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerified) {
      return _buildVerifiedCard();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _errorMessage != null
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.phone_iphone_rounded,
                  color: Color(0xFF059669),
                  size: 17,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Phone Verification',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Required',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _isCodeSent
                ? 'Enter the 6-digit SMS code sent to ${_phoneController.text.trim()}:'
                : 'Enter your Philippine mobile number to receive a one-time SMS verification code.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // State 1: Clean Phone Input Field & Send Button
          if (!_isCodeSent) ...[
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              enabled: !_isLoading,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
                letterSpacing: 0.5,
              ),
              decoration: InputDecoration(
                hintText: '9XX XXX XXXX',
                hintStyle: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF94A3B8)),
                prefixIcon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🇵🇭', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        '+63',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(height: 20, width: 1, color: const Color(0xFFCBD5E1)),
                    ],
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Clean Dedicated "Send Verification Code" Action Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendOtp,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.sms_outlined, size: 18, color: Colors.white),
                label: Text(
                  _isLoading ? 'Sending SMS...' : 'Send SMS Verification Code',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ] else ...[
            // State 2: 6 Individual Digit PIN Boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 44,
                  height: 52,
                  child: TextField(
                    controller: _pinControllers[index],
                    focusNode: _pinFocusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    enabled: !_isLoading,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(1),
                    ],
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF059669), width: 2),
                      ),
                    ),
                    onChanged: (val) {
                      if (val.isNotEmpty) {
                        if (index < 5) {
                          _pinFocusNodes[index + 1].requestFocus();
                        } else {
                          _pinFocusNodes[index].unfocus();
                          _verifyOtp();
                        }
                      } else {
                        if (index > 0) {
                          _pinFocusNodes[index - 1].requestFocus();
                        }
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),

            // Resend & Change Phone Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: _resetToEdit,
                  child: Text(
                    'Change Number',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                InkWell(
                  onTap: _secondsRemaining == 0 ? _sendOtp : null,
                  child: Text(
                    _secondsRemaining > 0
                        ? 'Resend in ${_secondsRemaining}s'
                        : 'Resend SMS Code',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _secondsRemaining == 0
                          ? const Color(0xFF059669)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Inline Error Message
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFDC2626),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// State 3: Verified Badge Card
  Widget _buildVerifiedCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF059669),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verified Mobile Number',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF047857),
                  ),
                ),
                Text(
                  _verifiedPhoneNumber,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _resetToEdit,
            child: Text(
              'Change',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF059669),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
