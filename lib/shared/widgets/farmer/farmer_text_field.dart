import 'package:flutter/material.dart';
import '../../styles/farmer_theme.dart';

/// Accessible, 54px+ text field with clear contrast borders, large typography,
/// and prominent icon prefixes for farmer usability.
class FarmerTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const FarmerTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FarmerTheme.body.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: FarmerTheme.textHeadline,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: FarmerTheme.body.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: FarmerTheme.textHeadline,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: FarmerTheme.bodyMuted.copyWith(
              fontSize: 15,
              color: const Color(0xFF64748B),
            ),
            prefixIcon: Icon(
              prefixIcon,
              color: FarmerTheme.primaryAction,
              size: 22,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            errorText: errorText,
            errorStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FarmerTheme.buttonBorderRadius),
              borderSide: const BorderSide(
                color: FarmerTheme.borderCrisp,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FarmerTheme.buttonBorderRadius),
              borderSide: const BorderSide(
                color: FarmerTheme.borderFocused,
                width: 2.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FarmerTheme.buttonBorderRadius),
              borderSide: const BorderSide(
                color: FarmerTheme.statusError,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FarmerTheme.buttonBorderRadius),
              borderSide: const BorderSide(
                color: FarmerTheme.statusError,
                width: 2.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
