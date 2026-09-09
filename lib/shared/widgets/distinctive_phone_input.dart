import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth/auth_service.dart';
import '../services/core/supabase_config.dart';
import '../styles/app_theme.dart';

/// A custom, signature AgriDirect phone input widget designed to be unique ("not the same as others")
/// Features:
/// - Distinctive Philippine Flag 🇵🇭 + (+63) dial code pill badge
/// - Auto-spacing Philippine format (09XX XXX XXXX or 9XX XXX XXXX)
/// - Real-time carrier detection pill (Globe / TM, Smart / TNT, Dito)
/// - Debounced uniqueness check against Supabase ensuring no duplicate accounts
/// - Immediate format guidance if digits do not start with 9
/// - Rich visual states: Neutral, Checking (spinner), Available (green badge), Duplicate (crimson error)
class DistinctivePhoneInput extends StatefulWidget {
  final String? initialPhone;
  final String? label;
  final String? helperText;
  final bool autofocus;
  final bool enabled;
  final TextEditingController? controller;
  final Function(String formattedE164, bool isValidAndUnique)? onChanged;

  const DistinctivePhoneInput({
    super.key,
    this.initialPhone,
    this.label = 'Philippine Mobile Number',
    this.helperText,
    this.autofocus = false,
    this.enabled = true,
    this.controller,
    this.onChanged,
  });

  @override
  State<DistinctivePhoneInput> createState() => _DistinctivePhoneInputState();
}

class _DistinctivePhoneInputState extends State<DistinctivePhoneInput> {
  late TextEditingController _effectiveController;
  final FocusNode _focusNode = FocusNode();

  Timer? _debounceTimer;
  bool _isChecking = false;
  PhoneAvailabilityResult? _availabilityResult;
  String _lastCheckedInput = '';
  bool _isFocused = false;
  String? _formatGuidance;

  @override
  void initState() {
    super.initState();
    _effectiveController = widget.controller ?? TextEditingController();

    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      final formatted = _formatRawToDisplay(widget.initialPhone!);
      _effectiveController.text = formatted;
      _triggerAvailabilityCheck(formatted, immediate: true);
    }

    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.dispose();
    if (widget.controller == null) {
      _effectiveController.dispose();
    }
    super.dispose();
  }

  String _formatRawToDisplay(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('63')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return _applyMask(digits);
  }

  String _applyMask(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length <= 3) return digits;
    if (digits.length <= 6) {
      return '${digits.substring(0, 3)} ${digits.substring(3)}';
    }
    final end = digits.length > 10 ? 10 : digits.length;
    return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6, end)}';
  }

  void _onTextChanged(String value) {
    final cleanDigits = value.replaceAll(RegExp(r'[^\d]'), '');

    // Format guidance
    String? guidance;
    if (cleanDigits.isNotEmpty && !cleanDigits.startsWith('9')) {
      guidance = 'Philippine mobile numbers start with 9 (e.g. 917 123 4567)';
    } else if (cleanDigits.isNotEmpty && cleanDigits.length < 10) {
      guidance = 'Enter ${10 - cleanDigits.length} more digit${(10 - cleanDigits.length) > 1 ? "s" : ""}';
    }

    // Debounced check
    _debounceTimer?.cancel();
    if (cleanDigits.length < 10 || !cleanDigits.startsWith('9')) {
      if (_formatGuidance != guidance || _availabilityResult != null || _isChecking) {
        setState(() {
          _isChecking = false;
          _availabilityResult = null;
          _formatGuidance = guidance;
        });
      }
      if (_lastCheckedInput.isNotEmpty) {
        _lastCheckedInput = '';
        widget.onChanged?.call('', false);
      }
      return;
    }

    if (_formatGuidance != null) {
      setState(() {
        _formatGuidance = null;
      });
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _triggerAvailabilityCheck(cleanDigits);
    });
  }

  Future<void> _triggerAvailabilityCheck(String digits, {bool immediate = false}) async {
    final clean = digits.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.length < 10 || !clean.startsWith('9')) return;
    if (clean == _lastCheckedInput && _availabilityResult != null) return;

    _lastCheckedInput = clean;
    if (mounted) {
      setState(() => _isChecking = true);
    }

    final currentUser = SupabaseConfig.client.auth.currentUser;
    final formattedForCheck = '+63$clean';

    final result = await AuthService.checkPhoneAvailability(
      formattedForCheck,
      excludeUserId: currentUser?.id,
    );

    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _availabilityResult = result;
    });

    if (widget.onChanged != null) {
      widget.onChanged!(result.normalizedE164, result.isAvailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = _effectiveController.text.replaceAll(RegExp(r'[^\d]'), '');
    final carrier = _availabilityResult?.carrier ??
        (digits.startsWith('9') ? AuthService.detectPhilippineCarrier('+63$digits') : null);

    final hasError = _availabilityResult != null && !_availabilityResult!.isAvailable;
    final isSuccess = _availabilityResult != null && _availabilityResult!.isAvailable;
    final isInvalidStart = digits.isNotEmpty && !digits.startsWith('9');

    Color borderColor = const Color(0xFFCBD5E1);
    if (hasError || isInvalidStart) {
      borderColor = const Color(0xFFEF4444);
    } else if (isSuccess) {
      borderColor = AppColors.primary;
    } else if (_isFocused) {
      borderColor = AppColors.primary;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasError || isInvalidStart)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          isInvalidStart ? 'Invalid' : 'Taken',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      )
                    else if (isSuccess)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          'Available',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ),
                    if (carrier != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cell_tower_rounded, size: 11, color: Color(0xFF059669)),
                            const SizedBox(width: 4),
                            Text(
                              carrier,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Main bespoke input container
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 56,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: widget.enabled ? Colors.white : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: _isFocused || hasError || isSuccess || isInvalidStart ? 1.8 : 1.2,
              ),
              boxShadow: [
                if (_isFocused && !hasError && !isInvalidStart)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                else if (hasError || isInvalidStart)
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              children: [
                // Distinctive Country Badge (+63 Philippines)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD1FAE5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🇵🇭', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 4),
                      Text(
                        '+63',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF047857),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider
                Container(
                  height: 24,
                  width: 1,
                  color: const Color(0xFFE2E8F0),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),

                // Phone number input field (full visibility for all 10 digits)
                Expanded(
                  child: TextField(
                    controller: _effectiveController,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.phone,
                    cursorColor: const Color(0xFF059669),
                    inputFormatters: [
                      PhilippinePhoneInputFormatter(),
                    ],
                    onChanged: _onTextChanged,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                      letterSpacing: 0.3,
                    ),
                    decoration: InputDecoration(
                      hintText: '917 123 4567',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.3,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),

                // Right Status Indicator (compact 24px icon)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildStatusIndicator(isSuccess, hasError, isInvalidStart, digits.length),
                ),
              ],
            ),
          ),

          // Dynamic feedback below field
          const SizedBox(height: 6),
          if (_isChecking) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Checking phone availability...',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ] else if (isInvalidStart) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Philippine mobile numbers start with 9 (e.g. 917 123 4567)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (hasError) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _availabilityResult?.message ?? 'This mobile number is already in use.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isSuccess) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF059669)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Unique number verified — ready to link to your account',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_formatGuidance != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                _formatGuidance!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ] else if (widget.helperText != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                widget.helperText!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(bool isSuccess, bool hasError, bool isInvalidStart, int currentLength) {
    if (_isChecking) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: Color(0xFF059669),
        ),
      );
    }

    if (hasError || isInvalidStart) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: const Center(
          child: Icon(Icons.close_rounded, size: 15, color: Color(0xFFDC2626)),
        ),
      );
    }

    if (isSuccess) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: const Center(
          child: Icon(Icons.check_rounded, size: 15, color: Color(0xFF059669)),
        ),
      );
    }

    if (currentLength > 0) {
      return Text(
        '$currentLength/10',
        style: GoogleFonts.inter(
          fontSize: 11,
          color: const Color(0xFF94A3B8),
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Standard Philippine Phone Number Formatter:
/// Formats as: 9XX XXX XXXX (up to 10 digits).
/// Automatically strips leading '0' when user begins typing '09...' because
/// the '+63' country code prefix is already fixed on the UI.
/// Formats inside the IME pipeline without re-assigning controller value,
/// preventing the Android keyboard from dismissing while typing.
class PhilippinePhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    var digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    String formatted = '';
    if (digits.isEmpty) {
      formatted = '';
    } else if (digits.length <= 3) {
      formatted = digits;
    } else if (digits.length <= 6) {
      formatted = '${digits.substring(0, 3)} ${digits.substring(3)}';
    } else {
      final end = digits.length > 10 ? 10 : digits.length;
      formatted = '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6, end)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
