import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase Phone Auth & Free SMS OTP Service
/// Provides 10,000 FREE real SMS OTP verifications per month.
class FirebaseOtpService {
  static final FirebaseOtpService _instance = FirebaseOtpService._internal();
  factory FirebaseOtpService() => _instance;
  FirebaseOtpService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Format phone numbers to E.164 standard (+639xxxxxxxxx)
  static String formatPhoneNumber(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('09') && cleaned.length == 11) {
      cleaned = '+63${cleaned.substring(1)}';
    } else if (cleaned.startsWith('9') && cleaned.length == 10) {
      cleaned = '+63$cleaned';
    } else if (cleaned.startsWith('63') && !cleaned.startsWith('+')) {
      cleaned = '+$cleaned';
    } else if (!cleaned.startsWith('+') && cleaned.isNotEmpty) {
      cleaned = '+$cleaned';
    }
    return cleaned;
  }

  /// Sends a REAL SMS OTP to the given phone number via Firebase
  /// Calls [onCodeSent] with the `verificationId` when the SMS is dispatched.
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String errorMessage) onError,
    Function(PhoneAuthCredential credential)? onAutoVerified,
    int? resendToken,
  }) async {
    try {
      final formattedPhone = formatPhoneNumber(phoneNumber);
      debugPrint('🔥 Firebase: Sending SMS OTP to $formattedPhone');

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        forceResendingToken: resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('🔥 Firebase: Auto verification completed');
          if (onAutoVerified != null) {
            onAutoVerified(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('🔥 Firebase: Verification failed - ${e.code}: ${e.message}');
          onError(e.message ?? 'Verification failed (${e.code})');
        },
        codeSent: (String verificationId, int? newResendToken) {
          debugPrint('🔥 Firebase: Code sent successfully. ID: $verificationId');
          onCodeSent(verificationId, newResendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('🔥 Firebase: Auto retrieval timeout for $verificationId');
        },
      );
    } catch (e) {
      debugPrint('❌ Error starting Firebase phone verification: $e');
      onError(e.toString());
    }
  }

  /// Verifies the SMS code entered by the user
  Future<UserCredential?> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      debugPrint('🔥 Firebase: Verifying SMS code $smsCode for ID: $verificationId');
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );

      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint('🎉 Firebase: User successfully authenticated: ${userCredential.user?.uid}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase verification error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected error verifying Firebase OTP: $e');
      rethrow;
    }
  }

  /// Sign out from Firebase Auth
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
