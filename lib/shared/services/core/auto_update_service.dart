import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../router/app_router.dart';
import '../../styles/app_theme.dart';

enum UpdateType {
  none,
  optional,
  force,
}

class AppVersionInfo {
  final String platform;
  final String latestVersion;
  final int latestBuildNumber;
  final String minSupportedVersion;
  final int minSupportedBuildNumber;
  final String apkUrl;
  final List<String> releaseNotes;
  final bool isCritical;

  AppVersionInfo({
    required this.platform,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minSupportedVersion,
    required this.minSupportedBuildNumber,
    required this.apkUrl,
    required this.releaseNotes,
    required this.isCritical,
  });

  factory AppVersionInfo.fromSupabase(Map<String, dynamic> map) {
    List<String> notes = [];
    if (map['release_notes'] is List) {
      notes = (map['release_notes'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return AppVersionInfo(
      platform: map['platform']?.toString() ?? 'android',
      latestVersion: (map['latest_version']?.toString() ?? '1.0.0').replaceAll(RegExp(r'^[vV]'), ''),
      latestBuildNumber: (map['latest_build_number'] as num?)?.toInt() ?? 1,
      minSupportedVersion: (map['min_supported_version']?.toString() ?? '1.0.0').replaceAll(RegExp(r'^[vV]'), ''),
      minSupportedBuildNumber: (map['min_supported_build_number'] as num?)?.toInt() ?? 1,
      apkUrl: map['apk_url']?.toString() ?? '',
      releaseNotes: notes,
      isCritical: map['is_critical'] == true,
    );
  }

  factory AppVersionInfo.fromGitHub(Map<String, dynamic> data) {
    final String tagName = (data['tag_name'] as String? ?? '1.0.0').replaceAll(RegExp(r'^[vV]'), '');
    final assets = data['assets'] as List<dynamic>? ?? [];
    String apk = '';
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('.apk')) {
        apk = asset['browser_download_url'] as String? ?? '';
        break;
      }
    }

    List<String> notes = [];
    final body = data['body'] as String? ?? '';
    if (body.isNotEmpty) {
      notes = body
          .split('\n')
          .map((line) => line.replaceAll(RegExp(r'^[*\-#\s]+'), '').trim())
          .where((line) => line.isNotEmpty)
          .take(5)
          .toList();
    }

    return AppVersionInfo(
      platform: 'android',
      latestVersion: tagName,
      latestBuildNumber: 1,
      minSupportedVersion: '1.0.0',
      minSupportedBuildNumber: 1,
      apkUrl: apk,
      releaseNotes: notes,
      isCritical: false,
    );
  }
}

class AutoUpdateService {
  static const String _githubReleasesUrl =
      'https://api.github.com/repos/vincentagbuya03/agridirect/releases/latest';
  static const String _prefDismissedVersionKey = 'agridirect_update_dismissed_version';
  static const String _prefDismissedTimeKey = 'agridirect_update_dismissed_time';

  /// Main entry point to check for updates.
  /// [showFeedback] set to true when manually invoked (e.g. from Settings screen).
  Future<void> checkForUpdates(BuildContext context, {bool showFeedback = false}) async {
    // Web Update Handling
    if (kIsWeb) {
      await _handleWebUpdateCheck(context, showFeedback: showFeedback);
      return;
    }

    // Android Update Handling
    if (defaultTargetPlatform != TargetPlatform.android) {
      if (showFeedback && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto-updates are only supported on Android and Web.')),
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
      final versionInfo = await _fetchRemoteVersionInfo(platform: 'android');
      if (versionInfo == null) {
        if (showFeedback && context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to connect to update server.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version.replaceAll(RegExp(r'^[vV]'), '');
      final int currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      final updateType = _determineUpdateType(
        currentVersion: currentVersion,
        currentBuild: currentBuild,
        info: versionInfo,
      );

      debugPrint(
        'AutoUpdateService: Current=$currentVersion+$currentBuild, Latest=${versionInfo.latestVersion}+${versionInfo.latestBuildNumber}, Status=$updateType',
      );

      if (showFeedback && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (updateType == UpdateType.none) {
        if (showFeedback && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Your app is up to date (v$currentVersion+$currentBuild)'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        return;
      }

      // Check snooze for optional updates when in background mode
      if (updateType == UpdateType.optional && !showFeedback) {
        final isSnoozed = await _isUpdateSnoozed(versionInfo.latestVersion);
        if (isSnoozed) {
          debugPrint('AutoUpdateService: Update v${versionInfo.latestVersion} is snoozed.');
          return;
        }
      }

      if (!context.mounted) return;

      _showUpdatePrompt(
        context: context,
        versionInfo: versionInfo,
        currentVersion: currentVersion,
        isForced: updateType == UpdateType.force,
      );
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

  /// Web platform version checker
  Future<void> _handleWebUpdateCheck(BuildContext context, {required bool showFeedback}) async {
    try {
      final info = await _fetchRemoteVersionInfo(platform: 'web');
      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version.replaceAll(RegExp(r'^[vV]'), '');
      final int currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (info != null) {
        final updateType = _determineUpdateType(
          currentVersion: currentVersion,
          currentBuild: currentBuild,
          info: info,
        );

        if (updateType != UpdateType.none) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.cloud_download_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'A new web update (v${info.latestVersion}) is available!',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.primary,
              duration: const Duration(days: 1), // Stay until acted on
              action: SnackBarAction(
                label: 'Reload Now',
                textColor: Colors.amberAccent,
                onPressed: () {
                  launchUrl(Uri.base, webOnlyWindowName: '_self');
                },
              ),
            ),
          );
          return;
        }
      }

      if (showFeedback && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AgriDirect Web is up to date (v$currentVersion)'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Web Update Check Error: $e');
      if (showFeedback && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking web updates: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Fetches remote version config from Supabase, with GitHub Releases fallback.
  Future<AppVersionInfo?> _fetchRemoteVersionInfo({required String platform}) async {
    // 1. Try Supabase app_versions table
    try {
      final response = await Supabase.instance.client
          .from('app_versions')
          .select()
          .eq('platform', platform)
          .maybeSingle();

      if (response is Map<String, dynamic>) {
        final info = AppVersionInfo.fromSupabase(response);
        if (info.latestVersion.isNotEmpty) {
          return info;
        }
      }
    } catch (e) {
      debugPrint('AutoUpdateService: Supabase version query failed ($e), trying fallback...');
    }

    // 2. Fallback to GitHub Releases (Android only)
    if (platform == 'android') {
      try {
        final res = await http.get(
          Uri.parse(_githubReleasesUrl),
          headers: {'Accept': 'application/vnd.github.v3+json'},
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          return AppVersionInfo.fromGitHub(data);
        }
      } catch (e) {
        debugPrint('AutoUpdateService: GitHub fallback failed: $e');
      }
    }

    return null;
  }

  /// Compares local version with remote version info.
  UpdateType _determineUpdateType({
    required String currentVersion,
    required int currentBuild,
    required AppVersionInfo info,
  }) {
    // 1. Check if below minimum supported version (Force Update)
    if (info.isCritical) {
      final cmpLatest = _compareSemVer(currentVersion, info.latestVersion);
      if (cmpLatest < 0 || (cmpLatest == 0 && currentBuild < info.latestBuildNumber)) {
        return UpdateType.force;
      }
    }

    final cmpMin = _compareSemVer(currentVersion, info.minSupportedVersion);
    if (cmpMin < 0 || (cmpMin == 0 && currentBuild < info.minSupportedBuildNumber)) {
      return UpdateType.force;
    }

    // 2. Check if newer version is available (Optional Update)
    final cmpLatest = _compareSemVer(currentVersion, info.latestVersion);
    if (cmpLatest < 0 || (cmpLatest == 0 && currentBuild < info.latestBuildNumber)) {
      return UpdateType.optional;
    }

    return UpdateType.none;
  }

  /// Returns -1 if v1 < v2, 1 if v1 > v2, 0 if v1 == v2
  int _compareSemVer(String v1, String v2) {
    final clean1 = v1.replaceAll(RegExp(r'[^0-9.]'), '');
    final clean2 = v2.replaceAll(RegExp(r'[^0-9.]'), '');

    final parts1 = clean1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = clean2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;
    while (parts1.length < maxLen) {
      parts1.add(0);
    }
    while (parts2.length < maxLen) {
      parts2.add(0);
    }

    for (var i = 0; i < maxLen; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }
    return 0;
  }

  /// Checks if the user dismissed this update version within the last 24 hours
  Future<bool> _isUpdateSnoozed(String remoteVersion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedVersion = prefs.getString(_prefDismissedVersionKey);
      final dismissedTimeStr = prefs.getString(_prefDismissedTimeKey);

      if (dismissedVersion == remoteVersion && dismissedTimeStr != null) {
        final dismissedTime = DateTime.tryParse(dismissedTimeStr);
        if (dismissedTime != null) {
          final difference = DateTime.now().difference(dismissedTime);
          if (difference.inHours < 24) {
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  /// Snoozes this version for 24 hours
  static Future<void> snoozeUpdate(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefDismissedVersionKey, version);
      await prefs.setString(_prefDismissedTimeKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  void _showUpdatePrompt({
    required BuildContext context,
    required AppVersionInfo versionInfo,
    required String currentVersion,
    required bool isForced,
  }) {
    final targetContext = appNavigatorKey.currentContext ?? context;
    if (!targetContext.mounted) return;

    showDialog(
      context: targetContext,
      barrierDismissible: !isForced,
      builder: (dialogContext) {
        return PopScope(
          canPop: !isForced,
          child: _UpdateDialog(
            versionInfo: versionInfo,
            currentVersion: currentVersion,
            isForced: isForced,
          ),
        );
      },
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final AppVersionInfo versionInfo;
  final String currentVersion;
  final bool isForced;

  const _UpdateDialog({
    required this.versionInfo,
    required this.currentVersion,
    required this.isForced,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  String _statusMessage = '';
  double? _downloadProgress;
  bool _isDownloading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _statusMessage = widget.isForced
        ? 'A mandatory update is required to continue using AgriDirect securely.'
        : 'A new version of AgriDirect is available with improvements and new features.';
  }

  Future<void> _launchBrowserDownload() async {
    final apkUrl = widget.versionInfo.apkUrl;
    if (apkUrl.isEmpty) return;

    final uri = Uri.tryParse(apkUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _startUpdate() {
    final apkUrl = widget.versionInfo.apkUrl;
    if (apkUrl.isEmpty) {
      setState(() {
        _statusMessage = 'No APK package URL configured for this release.';
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _hasError = false;
      _statusMessage = 'Downloading update package...';
      _downloadProgress = 0.0;
    });

    try {
      OtaUpdate().execute(
        apkUrl,
        destinationFilename: 'agridirect_update.apk',
        usePackageInstaller: true,
      ).listen(
        (OtaEvent event) {
          if (!mounted) return;
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
                final progressStr = event.value;
                _downloadProgress = progressStr == null
                    ? null
                    : (double.tryParse(progressStr) ?? 0) / 100.0;
              });
              break;
            case OtaStatus.INSTALLATION_DONE:
              setState(() {
                _statusMessage = 'Update installed. Restarting AgriDirect...';
                _isDownloading = false;
                _downloadProgress = null;
              });
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              setState(() {
                _statusMessage =
                    'Install permission was not granted. Please allow AgriDirect to install unknown apps or download via browser.';
                _isDownloading = false;
                _hasError = true;
                _downloadProgress = null;
              });
              break;
            case OtaStatus.INSTALLATION_ERROR:
              setState(() {
                _statusMessage =
                    'Installation failed. Please verify the APK package or try downloading directly in browser.';
                _isDownloading = false;
                _hasError = true;
                _downloadProgress = null;
              });
              break;
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.ALREADY_RUNNING_ERROR:
            case OtaStatus.CANCELED:
              setState(() {
                final details = event.value?.trim();
                _statusMessage = details == null || details.isEmpty
                    ? 'Download failed (${event.status.name})'
                    : 'Download failed: $details';
                _isDownloading = false;
                _hasError = true;
                _downloadProgress = null;
              });
              break;
          }
        },
        onError: (err) {
          if (!mounted) return;
          setState(() {
            _statusMessage = 'Update encountered an error: $err';
            _isDownloading = false;
            _hasError = true;
            _downloadProgress = null;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to initiate update: $e';
        _isDownloading = false;
        _hasError = true;
        _downloadProgress = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final newVer = widget.versionInfo.latestVersion;
    final notes = widget.versionInfo.releaseNotes;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(16, 16, 20, 20),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.isForced
                  ? AppColors.error.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              widget.isForced ? Icons.warning_amber_rounded : Icons.system_update_rounded,
              color: widget.isForced ? AppColors.error : AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isForced ? 'Mandatory Update' : 'Update Available',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeadline,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'v$newVer (Current: v${widget.currentVersion})',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _statusMessage,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _hasError ? AppColors.error : AppColors.textSubtle,
                  height: 1.45,
                ),
              ),

              // Release Notes / What's New
              if (!_isDownloading && notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  "What's New:",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeadline,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: notes.map((note) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 4, right: 8),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                note,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF334155),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              // Download Progress Bar
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
        ),
      ),
      actions: [
        if (!_isDownloading) ...[
          if (!widget.isForced)
            TextButton(
              onPressed: () {
                AutoUpdateService.snoozeUpdate(widget.versionInfo.latestVersion);
                Navigator.of(context, rootNavigator: true).pop();
              },
              child: Text(
                'Later',
                style: GoogleFonts.inter(
                  color: AppColors.textSubtle,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_hasError && widget.versionInfo.apkUrl.isNotEmpty)
            OutlinedButton.icon(
              onPressed: _launchBrowserDownload,
              icon: const Icon(Icons.open_in_browser_rounded, size: 18),
              label: Text(
                'Browser Download',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ElevatedButton(
            onPressed: _startUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isForced ? AppColors.error : AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              _hasError ? 'Retry' : 'Update Now',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ] else if (_downloadProgress == null && _hasError) ...[
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
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
