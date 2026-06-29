import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper class to handle downloading the APK file on both Web and Mobile.
/// Uses a hidden iframe on Web to bypass Android's default-browser redirect
/// (e.g. Chrome redirecting to Brave) and download the file silently.
class ApkDownloader {
  static const String apkUrl =
      'https://github.com/vincentagbuya03/agridirect/releases/latest/download/AgriDirect-Installer.apk';

  static Future<void> download() async {
    if (kIsWeb) {
      try {
        js.context.callMethod('eval', [
          """
          var iframe = document.createElement('iframe');
          iframe.style.display = 'none';
          iframe.src = '/download-apk';
          document.body.appendChild(iframe);
          setTimeout(function() {
            if (document.body.contains(iframe)) {
              document.body.removeChild(iframe);
            }
          }, 5000);
          """
        ]);
      } catch (e) {
        // Fallback to url_launcher if JS evaluation fails
        final uri = Uri.parse(apkUrl);
        await launchUrl(uri, webOnlyWindowName: '_self');
      }
    } else {
      final uri = Uri.parse(apkUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
