import 'package:flutter/foundation.dart';

/// Helper utility for generating share links across platforms.
class ShareUtil {
  /// Production web domain
  static const String webDomain = 'https://agridirect-app.vercel.app';

  /// Custom URI scheme that directly launches the installed Android APK / iOS App
  static const String appScheme = 'agridirect://';

  /// Gets the base URL for generating share links.
  /// On web, uses current origin or web domain.
  /// On native mobile app, returns the web domain by default for universal compatibility.
  static String get baseDomain {
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        if (origin.isNotEmpty && origin.startsWith('http')) {
          return origin;
        }
      } catch (_) {}
    }
    return webDomain;
  }

  /// Builds a link specifically designed to launch the installed APK directly.
  static String buildAppLink(String routeWithParams) {
    // Remove leading slash if present for clean scheme formatting (agridirect://path)
    final cleanRoute = routeWithParams.startsWith('/') 
        ? routeWithParams.substring(1) 
        : routeWithParams;
    return '$appScheme$cleanRoute';
  }
}
