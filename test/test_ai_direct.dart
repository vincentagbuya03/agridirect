import 'package:agridirect/shared/services/ai/farmer_ai_verification_service.dart';

void main() {
  print('Testing Name Similarity:');
  final sim1 = FarmerAiVerificationService.computeNameSimilarity('Juan Dela Cruz', 'JUAN DELA CRUZ');
  assert(sim1 == 1.0, 'Expected 1.0, got $sim1');
  print('  ✓ Identical: $sim1');

  final sim2 = FarmerAiVerificationService.computeNameSimilarity('Juan Dela Cruz', 'Dela Cruz, Juan');
  assert(sim2 == 1.0, 'Expected 1.0, got $sim2');
  print('  ✓ Reversed: $sim2');

  final sim3 = FarmerAiVerificationService.computeNameSimilarity('Juan M. Dela Cruz', 'Juan Dela Cruz');
  assert(sim3 >= 0.85, 'Expected >= 0.85, got $sim3');
  print('  ✓ Middle initial: $sim3');

  print('\nTesting Auto-Approval:');
  final res1 = FarmerAiVerificationService.evaluate(
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

  print('  ✓ Passed result: isAutoApproved=${res1.isAutoApproved}, score=${res1.confidenceScore}');
  assert(res1.isAutoApproved == true);

  final res2 = FarmerAiVerificationService.evaluate(
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

  print('  ✓ Mismatched result: isAutoApproved=${res2.isAutoApproved}, score=${res2.confidenceScore}');
  assert(res2.isAutoApproved == false);

  print('\nTesting 1-to-1 Biometric Face Gating:');
  // 1. High Face Match (Same Person) -> Approved
  final resFaceApproved = FarmerAiVerificationService.evaluate(
    registeredFullName: 'Juan Dela Cruz',
    registeredDob: '1990-05-15',
    frontExtractedName: 'JUAN DELA CRUZ',
    backQrSubject: {
      'fName': 'JUAN',
      'lName': 'DELA CRUZ',
      'PCN': '1234567890123456',
      'DOB': '1990-05-15',
    },
    faceSelfieCaptured: true,
    idType: 'national_id',
    faceMatchSimilarity: 0.85, // 85% match
    faceFoundOnId: true,
  );
  print('  ✓ Face Match (85%): isAutoApproved=${resFaceApproved.isAutoApproved}, score=${resFaceApproved.confidenceScore}');
  assert(resFaceApproved.isAutoApproved == true, 'Expected approved for matching face');

  // 2. Low Face Match (Different Person / Impersonator) -> Strictly Rejected Auto-Approval
  final resFaceRejected = FarmerAiVerificationService.evaluate(
    registeredFullName: 'Juan Dela Cruz',
    registeredDob: '1990-05-15',
    frontExtractedName: 'JUAN DELA CRUZ',
    backQrSubject: {
      'fName': 'JUAN',
      'lName': 'DELA CRUZ',
      'PCN': '1234567890123456',
      'DOB': '1990-05-15',
    },
    faceSelfieCaptured: true,
    idType: 'national_id',
    faceMatchSimilarity: 0.32, // 32% match (different person)
    faceFoundOnId: true,
  );
  print('  ✓ Face Mismatch (32%): isAutoApproved=${resFaceRejected.isAutoApproved}, score=${resFaceRejected.confidenceScore}');
  print('    Flagged reasons: ${resFaceRejected.flaggedReasons}');
  assert(resFaceRejected.isAutoApproved == false, 'Expected NOT approved for mismatched face');
  assert(resFaceRejected.flaggedReasons.any((r) => r.contains('Biometric Face Mismatch')), 'Expected biometric face mismatch flag');

  print('\nAll 1-to-1 Biometric Face Match and Verification tests PASSED 100%!');
}
