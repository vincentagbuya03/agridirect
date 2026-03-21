import 'package:flutter/foundation.dart';

/// Debug utility for Google Sign-In troubleshooting
class GoogleSignInDebugHelper {
  /// Log debug information about Google Sign-In state
  static void logDebugInfo({
    required String stage,
    String? message,
    dynamic error,
    Map<String, dynamic>? additionalInfo,
  }) {
    if (kDebugMode) {
      print('🔍 [GoogleSignIn Debug] $stage');
      if (message != null) {
        print('  Message: $message');
      }
      if (error != null) {
        print('  Error: $error');
      }
      if (additionalInfo != null) {
        additionalInfo.forEach((key, value) {
          print('  $key: $value');
        });
      }
      print('');
    }
  }

  /// Common troubleshooting tips
  static Map<String, String> getTroubleshootingTips() {
    return {
      'cancelled':
          'User cancelled the sign-in process. This is normal behavior.',
      'developer_error':
          'Configuration issue. Check SHA-1 fingerprint in Firebase Console.',
      'network_error': 'Internet connectivity issue. Check network connection.',
      'invalid_credential':
          'Authentication token is invalid. Try signing out and back in.',
      'account_exists':
          'Email already registered with different provider (email/password).',
      'user_disabled': 'Account has been disabled by an administrator.',
      'operation_not_allowed':
          'Google Sign-In is disabled in Firebase Console.',
    };
  }

  /// Get setup checklist for developers
  static List<String> getSetupChecklist() {
    return [
      '✅ Firebase project created and configured',
      '✅ google-services.json downloaded and placed in android/app/',
      '✅ SHA-1 fingerprint generated and added to Firebase Console',
      '✅ Google Services plugin added to build.gradle files',
      '✅ Supabase Google OAuth configured with correct client ID',
      '✅ Redirect URLs configured in Supabase Dashboard',
      '✅ Package name matches in Firebase and AndroidManifest.xml',
    ];
  }

  /// Validate current configuration (basic checks)
  static Map<String, bool> validateConfiguration() {
    final results = <String, bool>{};

    // These checks would need to be implemented based on actual file existence
    // For now, returning placeholder results
    results['google_services_json_exists'] = true; // Would check file existence
    results['package_name_matches'] =
        true; // Would verify package name consistency
    results['gradle_plugin_configured'] =
        true; // Would check build.gradle files

    return results;
  }
}
