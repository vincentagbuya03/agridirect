import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/shared/services/ai/farmer_ai_verification_service.dart';

void main() {
  group('FarmerAiVerificationService - Name Matching', () {
    test('Identical name returns 1.0 similarity', () {
      final sim = FarmerAiVerificationService.computeNameSimilarity(
        'Juan Dela Cruz',
        'JUAN DELA CRUZ',
      );
      expect(sim, 1.0);
    });

    test('Token-reversed name (Last, First) scores 1.0 similarity', () {
      final sim = FarmerAiVerificationService.computeNameSimilarity(
        'Juan Dela Cruz',
        'Dela Cruz, Juan',
      );
      expect(sim, 1.0);
    });

    test('Middle initial difference scores high similarity (>= 0.85)', () {
      final sim = FarmerAiVerificationService.computeNameSimilarity(
        'Juan M. Dela Cruz',
        'Juan Dela Cruz',
      );
      expect(sim, greaterThanOrEqualTo(0.85));
    });

    test('Completely different names score low similarity (< 0.5)', () {
      final sim = FarmerAiVerificationService.computeNameSimilarity(
        'Juan Dela Cruz',
        'Rodrigo Santos Gomez',
      );
      expect(sim, lessThan(0.5));
    });
  });

  group('FarmerAiVerificationService - Auto-Approval Decision', () {
    test('Valid PhilSys ID with matching Name, PCN, DOB, and Face passes auto-approval', () {
      final result = FarmerAiVerificationService.evaluate(
        registeredFullName: 'Juan Dela Cruz',
        registeredDob: '1990-05-15',
        frontExtractedName: 'JUAN DELA CRUZ',
        frontExtractedDob: '05/15/1990',
        frontExtractedPcn: '1234-5678-9012-3456',
        backQrSubject: {
          'fName': 'JUAN',
          'lName': 'DELA CRUZ',
          'PCN': '1234567890123456',
          'DOB': '1990-05-15',
        },
        faceSelfieCaptured: true,
        idType: 'national_id',
      );

      expect(result.isAutoApproved, isTrue);
      expect(result.confidenceScore, greaterThanOrEqualTo(0.85));
      expect(result.verificationMethod, 'ai_auto_verified');
      expect(result.flaggedReasons, isEmpty);
    });

    test('Flagged for admin review when face selfie is missing', () {
      final result = FarmerAiVerificationService.evaluate(
        registeredFullName: 'Juan Dela Cruz',
        registeredDob: '1990-05-15',
        frontExtractedName: 'JUAN DELA CRUZ',
        backQrSubject: {
          'fName': 'JUAN',
          'lName': 'DELA CRUZ',
          'PCN': '1234567890123456',
        },
        faceSelfieCaptured: false, // Missing selfie
        idType: 'national_id',
      );

      expect(result.isAutoApproved, isFalse);
      expect(result.verificationMethod, 'manual_admin');
      expect(result.flaggedReasons.any((r) => r.contains('selfie')), isTrue);
    });

    test('Flagged for admin review when name completely mismatches', () {
      final result = FarmerAiVerificationService.evaluate(
        registeredFullName: 'Maria Clara',
        registeredDob: '1990-05-15',
        frontExtractedName: 'JUAN DELA CRUZ',
        backQrSubject: {
          'fName': 'JUAN',
          'lName': 'DELA CRUZ',
          'PCN': '1234567890123456',
        },
        faceSelfieCaptured: true,
        idType: 'national_id',
      );

      expect(result.isAutoApproved, isFalse);
      expect(result.verificationMethod, 'manual_admin');
      expect(result.flaggedReasons.any((r) => r.contains('Name mismatch')), isTrue);
    });
  });
}
