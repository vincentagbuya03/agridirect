// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

/// Web implementation of [evalJs] utilizing `dart:js`.
void evalJs(String code) {
  try {
    js.context.callMethod('eval', [code]);
  } catch (e) {
    // Silent fail/logging in web context
  }
}

/// Web implementation to expose Dart callback for web notification click.
void registerNotificationCallback(void Function(String linkType, String linkId) callback) {
  js.context['onWebNotificationClick'] = callback;
}
