/// Route name constants for type-safe navigation.
class AppRoutes {
  // ── Shared ──
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String onboarding = '/onboarding';
  static const String faceCapture = '/face-capture';
  static const String admin = '/admin';
  static const String preorderDetails = '/preorder-details';
  static const String authCallback = '/auth/callback';
  static const String resetPassword = '/reset-password';
  static const String resetPasswordWithCode = '/reset-password-code';
  static const String messages = '/messages';
  static const String customerMessages = '/customer-messages';
  static const String farmerMessages = '/farmer-messages';
  static const String loading = '/loading';

  // ── Mobile-specific ──
  static const String farmerRegister = '/farmer-register';
  static const String googleCompleteProfile = '/google-complete-profile';
  static const String addProduct = '/add-product';
  static const String myDetails = '/my-details';
  static const String farmersMap = '/farmers-map';

  // ── Web-specific ──
  static const String webWelcome = '/web-welcome';
  static const String marketplace = '/marketplace'; // consumer home / index 0
  static const String shop = '/shop'; // index 1
  static const String community = '/community'; // index 2
  static const String profile = '/profile'; // index 3 (auth required)
  static const String farmerDashboard =
      '/farmer-dashboard'; // farmer home / index 0
  static const String webFarmerRegister = '/web-farmer-register';

  // ── Web tab helpers ──

  /// Converts a route path to the active tab index used by web screens.
  static int webTabIndex(String location) {
    if (location.startsWith(shop)) return 1;
    if (location.startsWith(community)) return 2;
    if (location.startsWith(profile)) return 3;
    return 0; // marketplace / farmerDashboard / home all → 0
  }

  /// Converts a tab index back to the appropriate route path.
  static String webTabRoute(int index, {bool isFarmer = false}) {
    switch (index) {
      case 1:
        return shop;
      case 2:
        return community;
      case 3:
        return profile;
      default:
        return isFarmer ? farmerDashboard : marketplace;
    }
  }
}
