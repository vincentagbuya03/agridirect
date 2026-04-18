import 'package:shared_preferences/shared_preferences.dart';

/// Service to track whether the user has completed the onboarding flow.
class OnboardingService {
  static const String _onboardingKey = 'onboarding_complete';

  /// Returns true if onboarding has already been completed.
  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  /// Mark onboarding as completed so it won't show again.
  static Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }

  /// Reset onboarding (useful for testing).
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingKey);
  }
}
