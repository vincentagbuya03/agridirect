import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

/// Enables path-based URLs for web builds.
/// No-op for non-web platforms.
void configureUrlStrategy() {
  if (kIsWeb) {
    usePathUrlStrategy();
  }
}
