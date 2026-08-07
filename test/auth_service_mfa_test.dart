import 'package:agridirect/shared/services/auth/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthService MFA assurance checks', () {
    test('requires MFA when current level is below next AAL2 level', () {
      expect(
        AuthService.isMfaRequiredForAssuranceLevels(
          currentLevelName: 'aal1',
          nextLevelName: 'aal2',
        ),
        isTrue,
      );
    });

    test('does not require MFA after the session already reached AAL2', () {
      expect(
        AuthService.isMfaRequiredForAssuranceLevels(
          currentLevelName: 'aal2',
          nextLevelName: 'aal2',
        ),
        isFalse,
      );
    });

    test('allows MFA challenge only with pending MFA and an auth session', () {
      expect(
        AuthService.canOpenMfaChallenge(
          requiresMfa: true,
          hasAuthSession: true,
        ),
        isTrue,
      );

      expect(
        AuthService.canOpenMfaChallenge(
          requiresMfa: true,
          hasAuthSession: false,
        ),
        isFalse,
      );
    });
  });
}
