import 'package:flutter/material.dart';
import 'distinctive_phone_input.dart';

/// Legacy adapter for PhoneVerificationInputWidget that delegates directly
/// to DistinctivePhoneInput with zero OTP and instant uniqueness checking.
class PhoneVerificationInputWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return DistinctivePhoneInput(
      initialPhone: initialPhone,
      onChanged: (formattedE164, isValidAndUnique) {
        onVerificationStateChanged?.call(isValidAndUnique);
        if (isValidAndUnique && formattedE164.isNotEmpty) {
          onVerified(formattedE164);
        }
      },
    );
  }
}
