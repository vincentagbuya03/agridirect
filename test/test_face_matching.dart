import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/shared/services/ai/farmer_ai_verification_service.dart';

void main() {
  group('Farmer AI Biometric Face Verification Gating Tests', () {
    test('Identical person with high face similarity (>= 65%) should AUTO-APPROVE', () {
      final result = FarmerAiVerificationService.evaluate(
        registeredFullName: 'JUAN SANTOS DELA CRUZ',
        registeredDob: '1985-06-15',
        frontExtractedName: 'JUAN SANTOS DELA CRUZ',
        frontExtractedDob: '1985-06-15',
        frontExtractedPcn: '1234-5678-9012-3456',
        backQrSubject: {
          'fName': 'JUAN',
          'mName': 'SANTOS',
          'lName': 'DELA CRUZ',
          'DOB': '1985-06-15',
          'PCN': '1234-5678-9012-3456',
        },
        faceSelfieCaptured: true,
        idType: 'national_id',
        faceMatchSimilarity: 0.88, // 88% Face Match
        faceFoundOnId: true,
      );

      expect(result.isAutoApproved, isTrue);
      expect(result.verificationMethod, equals('ai_auto_verified'));
      expect(result.confidenceScore, greaterThanOrEqualTo(0.85));
      expect(result.passedChecks.any((c) => c.contains('1-to-1 Biometric Face Match Confirmed')), isTrue);
    });

    test('Different person with low face similarity (< 65%) MUST FAIL AUTO-APPROVAL', () {
      final result = FarmerAiVerificationService.evaluate(
        registeredFullName: 'JUAN SANTOS DELA CRUZ',
        registeredDob: '1985-06-15',
        frontExtractedName: 'JUAN SANTOS DELA CRUZ',
        frontExtractedDob: '1985-06-15',
        frontExtractedPcn: '1234-5678-9012-3456',
        backQrSubject: {
          'fName': 'JUAN',
          'mName': 'SANTOS',
          'lName': 'DELA CRUZ',
          'DOB': '1985-06-15',
          'PCN': '1234-5678-9012-3456',
        },
        faceSelfieCaptured: true,
        idType: 'national_id',
        faceMatchSimilarity: 0.35, // 35% Face Match (Impersonator / Different Person)
        faceFoundOnId: true,
      );

      // Auto-approval must strictly be false!
      expect(result.isAutoApproved, isFalse);
      expect(result.verificationMethod, equals('manual_admin'));
      expect(result.flaggedReasons.any((r) => r.contains('Biometric Face Mismatch')), isTrue);
      expect(result.diagnostics['face_match_status'], equals('mismatch'));
    });

    test('Missing face on ID card portrait must prevent auto-approval', () {
      final result = FarmerAiVerificationService.evaluate(
        registeredFullName: 'JUAN SANTOS DELA CRUZ',
        registeredDob: '1985-06-15',
        frontExtractedName: 'JUAN SANTOS DELA CRUZ',
        frontExtractedDob: '1985-06-15',
        frontExtractedPcn: '1234-5678-9012-3456',
        backQrSubject: {
          'fName': 'JUAN',
          'mName': 'SANTOS',
          'lName': 'DELA CRUZ',
          'DOB': '1985-06-15',
          'PCN': '1234-5678-9012-3456',
        },
        faceSelfieCaptured: true,
        idType: 'national_id',
        faceMatchSimilarity: null,
        faceFoundOnId: false, // No face on ID
      );

      expect(result.isAutoApproved, isFalse);
      expect(result.verificationMethod, equals('manual_admin'));
      expect(result.flaggedReasons.any((r) => r.contains('No face detected on ID card portrait')), isTrue);
    });
  });
}
