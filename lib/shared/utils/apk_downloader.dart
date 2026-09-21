import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'js_helper.dart';

/// Helper class to handle downloading the APK file on both Web and Mobile.
/// Uses a hidden iframe on Web to bypass Android's default-browser redirect
/// (e.g. Chrome redirecting to Brave) and download the file silently.
class ApkDownloader {
  static const String apkUrl =
      'https://github.com/vincentagbuya03/agridirect/releases/latest/download/AgriDirect-Installer.apk';
  static const String fallbackUrl = 'https://www.agridirect.site/download-apk';
  static const String packageName = 'com.example.agridirect';

  static Future<void> download() async {
    final uri = Uri.parse(apkUrl);
    if (kIsWeb) {
      try {
        evalJs("""
          var iframe = document.createElement('iframe');
          iframe.style.display = 'none';
          iframe.src = '$apkUrl';
          document.body.appendChild(iframe);
          setTimeout(function() {
            if (document.body.contains(iframe)) {
              document.body.removeChild(iframe);
            }
          }, 60000);
          """);
      } catch (e) {
        // Fallback to url_launcher if JS evaluation fails
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Opens the native app via deep link or Android Intent URL without leaving the user on a blank page.
  /// If the app is not installed, automatically falls back to downloading the APK installer.
  static Future<void> openAppOrDownload({String? targetRoute}) async {
    final path = targetRoute ?? (kIsWeb ? Uri.base.path : '');
    final query = (kIsWeb && Uri.base.query.isNotEmpty) ? '?${Uri.base.query}' : '';
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    final appSchemeUrl = 'agridirect://$cleanPath$query';
    final encodedFallback = Uri.encodeComponent(fallbackUrl);
    final intentUrl =
        'intent://$cleanPath$query#Intent;scheme=agridirect;package=$packageName;S.browser_fallback_url=$encodedFallback;end';

    if (kIsWeb) {
      try {
        evalJs("""
          (function() {
            var isAndroid = /Android/i.test(navigator.userAgent);
            var isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent);
            var intentUrl = '$intentUrl';
            var appSchemeUrl = '$appSchemeUrl';
            var fallbackUrl = '$fallbackUrl';
            var start = Date.now();

            if (isAndroid) {
              // Android Chrome, Brave, Samsung Internet natively interpret intent: URIs.
              // If installed: launches the app directly into the requested screen.
              // If not installed: seamlessly falls back to S.browser_fallback_url (never leaves a blank page).
              window.location.href = intentUrl;
              setTimeout(function() {
                if (document.visibilityState !== 'hidden' && (Date.now() - start < 2500)) {
                  window.location.href = fallbackUrl;
                }
              }, 1200);
            } else if (isIOS) {
              window.location.href = appSchemeUrl;
              setTimeout(function() {
                if (document.visibilityState !== 'hidden' && (Date.now() - start < 2500)) {
                  window.location.href = fallbackUrl;
                }
              }, 1200);
            } else {
              window.location.href = fallbackUrl;
            }
          })();
        """);
        return;
      } catch (e) {
        debugPrint('Failed to execute JS app launcher: $e');
      }
    }

    // Native mobile / fallback
    try {
      final uri = Uri.parse(appSchemeUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await download();
      }
    } catch (_) {
      await download();
    }
  }
}
