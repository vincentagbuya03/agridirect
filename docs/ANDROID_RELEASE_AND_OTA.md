# Android Release and In-App Update Guide

This guide explains how AgriDirect checks for app updates and how to release a new APK version safely.

---

## How the Update Flow Works

AgriDirect uses **Supabase Remote Config** backed by `public.app_versions` with an automatic fallback to GitHub Releases. In-app downloads and installations are handled by `ota_update` with browser fallback support.

The update check runs automatically on app launch from:
- `lib/main.dart`
- `lib/shared/services/core/auto_update_service.dart`
- `lib/mobile/screens/profile/app_settings_screen.dart` (Manual check)

### Update Decision Matrix

```
Installed App Version vs Remote Config
  │
  ├─> Installed >= Remote Latest  ──> "Your app is up to date"
  │
  ├─> Installed < Min Supported OR is_critical = true ──> Force Update
  │   - Non-dismissible modal
  │   - "Later" button is hidden
  │   - Must update to continue
  │
  └─> Installed < Remote Latest (and >= Min Supported) ──> Optional Update
      - Shows "What's New" release notes
      - "Update Now" or "Later"
      - Tapping "Later" snoozes optional prompt for 24 hours
```

---

## Supabase Remote Config (`app_versions`)

Version parameters can be updated instantly in the `app_versions` table:

```sql
UPDATE public.app_versions
SET
    latest_version = '1.0.4',
    latest_build_number = 4,
    min_supported_version = '1.0.0',
    min_supported_build_number = 1,
    apk_url = 'https://github.com/vincentagbuya03/agridirect/releases/download/v1.0.4/AgriDirect-Installer.apk',
    release_notes = ARRAY[
        'Added real-time chat audio calls',
        'Direct shop order tracking improvements',
        'Bug fixes and performance upgrades'
    ],
    is_critical = false,
    updated_at = now()
WHERE platform = 'android';
```

---

## Android OTA Requirements

The OTA installer needs these Android files configured:
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/xml/filepaths.xml`

The manifest must include:
```xml
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
```

Inside `<application>`, it must include the OTA provider and install receiver:
```xml
<provider
    android:name="sk.fourq.otaupdate.OtaUpdateFileProvider"
    android:authorities="${applicationId}.ota_update_provider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/filepaths" />
</provider>

<receiver
    android:name="sk.fourq.otaupdate.InstallResultReceiver"
    android:exported="false">
    <intent-filter>
        <action android:name="${applicationId}.ACTION_INSTALL_COMPLETE" />
    </intent-filter>
</receiver>
```

`filepaths.xml` must contain:
```xml
<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <files-path name="internal_apk_storage" path="ota_update/"/>
</paths>
```

---

## Version Rules

Android uses two version values from `pubspec.yaml`:

```yaml
version: 1.0.4+4
```

- Before `+`: user-visible version (`1.0.4`)
- After `+`: Android `versionCode` (`4`)

> [!IMPORTANT]
> Every new APK update must increment the build number after `+`. Android will reject installs if `versionCode` did not increase.

---

## Step-by-Step Release Checklist

### 1. Update the Version
Edit `pubspec.yaml`:
```yaml
version: 1.0.4+4
```

### 2. Verify Code
```powershell
& 'C:\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze
```

### 3. Build the Universal Release APK
Run the release build script:
```powershell
.\scripts\build-android-universal-release.ps1
```
This generates:
```text
web/AgriDirect-Installer.apk
```

### 4. Publish to GitHub Releases
1. Go to `https://github.com/vincentagbuya03/agridirect/releases/new`
2. Set Tag: `v1.0.4`
3. Title: `AgriDirect v1.0.4`
4. Attach: `web/AgriDirect-Installer.apk`
5. Publish release.

### 5. Update Supabase `app_versions`
Update the row in Supabase SQL editor or Table Editor to `latest_version = '1.0.4'`, `latest_build_number = 4`, `apk_url`, and `release_notes`.
Users currently on older builds will immediately receive the in-app update prompt!
