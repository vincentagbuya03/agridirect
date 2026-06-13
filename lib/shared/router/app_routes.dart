/// Route name constants for type-safe navigation.
class AppRoutes {
  // Shared
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
  static const String productDetails = '/product-details';

  // Mobile-specific
  static const String farmerRegister = '/farmer-register';
  static const String completeProfile = '/complete-profile';
  static const String addProduct = '/add-product';
  static const String editProduct = '/edit-product';
  static const String myDetails = '/my-details';
  static const String farmersMap = '/farmers-map';
  static const String customerOrders = '/customer-orders';
  static const String addressBook = '/address-book';
  static const String favorites = '/favorites';
  static const String farmerFollowers = '/farmer-followers';
  static const String helpCenter = '/help-center';
  static const String appSettings = '/app-settings';

  // Web-specific
  static const String webWelcome = '/web-welcome';
  static const String marketplace = '/marketplace';
  static const String shop = '/shop';
  static const String community = '/community';
  static const String profile = '/profile';
  static const String cart = '/cart';
  static const String preorders = '/preorders';
  static const String farmerProfileBase = '/farm';
  static const String farmerDashboard = '/farmer-dashboard';
  static const String webFarmerRegister = '/web-farmer-register';

  static String farmerProfile(String farmerId) =>
      '$farmerProfileBase/$farmerId';

  /// Converts a route path to the active tab index used by web screens.
  static int webTabIndex(String location) {
    if (location.startsWith(shop)) return 1;
    if (location.startsWith(community)) return 2;
    if (location.startsWith(profile)) return 3;
    if (location.startsWith(cart)) return 4;
    return 0;
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
      case 4:
        return cart;
      default:
        return isFarmer ? farmerDashboard : marketplace;
    }
  }
}
