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
        evalJs(
          """
          var a = document.createElement('a');
          a.href = '$apkUrl';
          a.download = 'AgriDirect-Installer.apk';
          a.target = '_blank';
          document.body.appendChild(a);
          a.click();
          setTimeout(function() {
            if (document.body.contains(a)) {
              document.body.removeChild(a);
            }
          }, 1000);
          """
        );
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
