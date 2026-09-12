import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'js_helper.dart';

/// Helper class to handle downloading the APK file on both Web and Mobile.
/// Uses a hidden iframe on Web to bypass Android's default-browser redirect
/// (e.g. Chrome redirecting to Brave) and download the file silently.
class ApkDownloader {
  static const String apkUrl =
      'https://github.com/vincentagbuya03/agridirect/releases/latest/download/AgriDirect-Installer.apk';

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
}
