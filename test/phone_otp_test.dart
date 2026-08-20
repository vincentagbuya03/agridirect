import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agridirect/shared/services/core/supabase_config.dart';
import 'package:agridirect/shared/services/auth/otp_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  });

  test('Test Supabase Phone OTP Flow for 639122354762 with code 123456', () async {
    final otpService = OTPService();
    const testPhone = '639122354762';
    const testOtp = '123456';

    print('🚀 [TEST 1] Sending Phone OTP to $testPhone...');
    final sendResult = await otpService.sendPhoneOTP(testPhone);
    print('👉 Send Result: $sendResult');
    expect(sendResult['success'], true, reason: 'Failed to send OTP: ${sendResult['message']}');

    print('🚀 [TEST 2] Verifying OTP code $testOtp for $testPhone...');
    final verifyResult = await otpService.verifyPhoneOTP(
      phoneNumber: testPhone,
      otpCode: testOtp,
    );
    print('👉 Verify Result: $verifyResult');

    expect(verifyResult['success'], true, reason: 'Failed to verify OTP: ${verifyResult['message']}');
    expect(verifyResult['user'], isNotNull);
    print('🎉 SUCCESS: User authenticated with ID: ${(verifyResult['user'] as User).id}');
  });
}
