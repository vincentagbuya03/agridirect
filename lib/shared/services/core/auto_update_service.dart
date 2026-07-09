import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../styles/app_theme.dart';

class AutoUpdateService {
  static const String _githubReleasesUrl =
      'https://api.github.com/repos/vincentagbuya03/agridirect/releases/latest';

  /// Checks if a new version is available and prompts the user to update.
  Future<void> checkForUpdates(BuildContext context, {bool showFeedback = false}) async {
    // Only run this auto-update mechanism on Android devices.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      if (showFeedback && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Updates are only supported on Android devices.')),
        );
      }
      return;
    }

    if (showFeedback && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Checking for updates...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final response = await http.get(
        Uri.parse(_githubReleasesUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('AutoUpdateService: Failed to fetch GitHub release (${response.statusCode})');
        if (showFeedback && context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to check for updates: Server returned ${response.statusCode}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final String remoteVersionName = data['tag_name'] as String; // e.g., "v1.0.1" or "1.0.1"
      
      // Find the APK asset
      final assets = data['assets'] as List<dynamic>? ?? [];
      String? apkUrl;
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      if (apkUrl == null) {
        debugPrint('AutoUpdateService: No APK asset found in the latest GitHub release.');
        if (showFeedback && context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No update installation package found in the latest release.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersionName = packageInfo.version;

      debugPrint('AutoUpdateService: Current version=$currentVersionName, Remote version=$remoteVersionName');

      if (showFeedback && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (_isNewerVersion(currentVersionName, remoteVersionName)) {
        if (!context.mounted) return;
        _showUpdatePrompt(context, remoteVersionName.replaceAll(RegExp(r'^[vV]'), ''), apkUrl);
      } else {
        if (showFeedback && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Your app is up to date (v$currentVersionName)'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('AutoUpdateService Error: $e');
      if (showFeedback && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking for updates: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  bool _isNewerVersion(String currentVersion, String remoteVersion) {
    final currentClean = currentVersion.replaceAll(RegExp(r'[^0-9.]'), '');
    final remoteClean = remoteVersion.replaceAll(RegExp(r'[^0-9.]'), '');

    final currentParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final remoteParts = remoteClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = currentParts.length > remoteParts.length ? currentParts.length : remoteParts.length;
    while (currentParts.length < maxLen) {
      currentParts.add(0);
    }
    while (remoteParts.length < maxLen) {
      remoteParts.add(0);
    }

    for (var i = 0; i < maxLen; i++) {
      if (remoteParts[i] > currentParts[i]) return true;
      if (remoteParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  void _showUpdatePrompt(BuildContext context, String newVersion, String apkUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _UpdateDialog(newVersion: newVersion, apkUrl: apkUrl);
      },
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final String newVersion;
  final String apkUrl;

  const _UpdateDialog({required this.newVersion, required this.apkUrl});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  String _statusMessage = 'A new version of AgriDirect is available. Please update to continue.';
  double? _downloadProgress;
  bool _isDownloading = false;

  void _startUpdate() {
    setState(() {
      _isDownloading = true;
      _statusMessage = 'Downloading update...';
      _downloadProgress = 0.0;
    });

    try {
      OtaUpdate().execute(
        widget.apkUrl,
        destinationFilename: 'agridirect_update.apk',
      ).listen(
        (OtaEvent event) {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              setState(() {
                final progressStr = event.value;
                if (progressStr != null) {
                  _downloadProgress = double.tryParse(progressStr) != null
                      ? double.parse(progressStr) / 100.0
                      : null;
                }
              });
              break;
            case OtaStatus.INSTALLING:
              setState(() {
                _statusMessage = 'Installing update...';
                _downloadProgress = null;
              });
              break;
            default:
              setState(() {
                _statusMessage = 'Update failed or finished: ${event.status}';
                _isDownloading = false;
                _downloadProgress = null;
              });
              break;
          }
        },
        onError: (err) {
          setState(() {
            _statusMessage = 'Update failed: $err';
            _isDownloading = false;
            _downloadProgress = null;
          });
        },
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to start download: $e';
        _isDownloading = false;
        _downloadProgress = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.system_update_rounded, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Text(
            'Update Available',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New Version: v${widget.newVersion}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AppColors.textHeadline,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _statusMessage,
            style: GoogleFonts.inter(
              color: AppColors.textSubtle,
              height: 1.4,
            ),
          ),
          if (_downloadProgress != null) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _downloadProgress,
                minHeight: 8,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(_downloadProgress! * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!_isDownloading) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Later',
              style: GoogleFonts.inter(
                color: AppColors.textSubtle,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _startUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Update Now',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ] else if (_downloadProgress == null && _statusMessage.startsWith('Update failed')) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.inter(
                color: AppColors.textSubtle,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
