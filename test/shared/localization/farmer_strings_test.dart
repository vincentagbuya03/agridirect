import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/shared/localization/farmer_strings.dart';

void main() {
  group('FarmerStrings verification', () {
    test('all core keys have both en and fil translations', () {
      final keys = [
        'complete_profile',
        'complete_profile_sub',
        'phone_step_title',
        'password_step_title',
        'create_account_cta',
        'logout_sign_in_later',
        'switch_to_farmer',
        'switch_to_consumer',
        'farmer_mode_badge',
        'consumer_mode_badge',
        'verified_badge',
        'passwords_mismatch',
        'phone_required',
        'password_required',
      ];

      for (final key in keys) {
        final en = FarmerStrings.get(key, lang: 'en');
        final fil = FarmerStrings.get(key, lang: 'fil');

        expect(en.isNotEmpty, true, reason: 'Key $key missing English');
        expect(fil.isNotEmpty, true, reason: 'Key $key missing Filipino');
        expect(en != fil, true, reason: 'Key $key should have distinct English and Filipino translations');
      }
    });

    test('fallback returns key or English if unknown language', () {
      expect(FarmerStrings.get('complete_profile', lang: 'es'), 'Complete Your Profile');
      expect(FarmerStrings.get('unknown_key', lang: 'fil'), 'unknown_key');
    });
  });
}
