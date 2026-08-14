# Android Release and OTA Update Guide

This guide explains how AgriDirect checks for Android app updates and how to release a new APK version safely.

## How the Update Flow Works

AgriDirect uses the Flutter package `ota_update` for Android OTA installation.

The update check starts from:

- `lib/shared/services/core/auto_update_service.dart`
- `lib/mobile/screens/profile/app_settings_screen.dart`

When the user taps **Check for Updates**, the app:

1. Calls the latest GitHub release API:

   ```text
   https://api.github.com/repos/vincentagbuya03/agridirect/releases/latest
   ```

2. Reads the release tag name, for example `v1.0.3`.
3. Finds the first release asset ending in `.apk`.
4. Reads the installed app version using `package_info_plus`.
5. Compares the installed version with the GitHub release tag.
6. If the GitHub release is newer, it shows the update dialog.
7. Downloads the APK using `OtaUpdate().execute(...)`.
8. Hands the downloaded APK to Android Package Installer.
9. Android installs the APK only if the APK is valid, signed correctly, and has a higher `versionCode`.

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

## Version Rules

Android uses two version values from `pubspec.yaml`:

```yaml
version: 1.0.3+3
```

The part before `+` is the user-visible version:

```text
1.0.3
```

The part after `+` is Android `versionCode`:

```text
3
```

Every APK update must increase the build number after `+`. If the installed app is `1.0.2+2`, the next update should be something like:

```yaml
version: 1.0.3+3
```

Do not release `1.0.3+2` over `1.0.2+2`. Android will reject it because the `versionCode` did not increase.

## Release Checklist

### 1. Update the Version

Edit `pubspec.yaml`:

```yaml
version: 1.0.3+3
```

Use this pattern:

- Patch release: `1.0.2+2` to `1.0.3+3`
- Minor release: `1.0.2+2` to `1.1.0+3`
- Hotfix after `1.0.3+3`: `1.0.4+4`

### 2. Verify the App

Run analysis before building:

```powershell
& 'C:\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze
```

If you changed Android config, also run an Android build check:

```powershell
cd android
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$env:GRADLE_USER_HOME='c:\Users\Nick Vincent Agbuya\Documents\Flutter Project\agridirect\.gradle-user-home'
.\gradlew.bat :app:assembleDebug
cd ..
```

### 3. Build the Release APK

For the normal GitHub release APK, run:

```powershell
.\scripts\build-android-universal-release.ps1
```

This runs:

```powershell
flutter build apk --release
```

Then it copies the newest universal APK to:

```text
web/AgriDirect-Installer.apk
```

You can upload that APK to GitHub Releases.

There is also a split-per-ABI script:

```powershell
.\scripts\build-android-split-release.ps1
```

Only use the split build if you intentionally want architecture-specific APKs. For the simplest OTA flow, prefer the universal APK.

### 4. Create or Update the GitHub Release

Go to:

```text
https://github.com/vincentagbuya03/agridirect/releases/new
```

Set the tag to match the visible version:

```text
v1.0.3
```

Attach the APK asset:

```text
AgriDirect-Installer.apk
```

Publish the release.

The app checks the latest GitHub release tag, so the latest release must be the version you want users to install.

### 5. Test the OTA Update

Install the previous version on a real Android device.

Example:

```text
Installed app: 1.0.2+2
GitHub release: v1.0.3
Uploaded APK: 1.0.3+3
```

Then open:

```text
Account & Security > Check for Updates
```

Expected result:

1. The app shows **Update Available**.
2. The APK downloads.
3. Android asks permission to install or opens the installer.
4. The app installs successfully.
5. After reopening, the installed app version is the new version.

## Common Problems

### Download Finishes but App Does Not Update

Most likely causes:

- The APK has the same or lower `versionCode`.
- The APK was signed with a different signing key.
- Android install permission was denied.
- The GitHub release asset is old and was not replaced after rebuilding.

Fix:

1. Confirm `pubspec.yaml` has a higher build number after `+`.
2. Rebuild the APK.
3. Re-upload the new APK to GitHub Releases.
4. Try the update again.

### App Keeps Showing the Same Update

Most likely causes:

- The installed app version did not actually change.
- The GitHub release tag is higher than the app version inside the APK.
- The uploaded APK was built before updating `pubspec.yaml`.

Fix:

1. Confirm `pubspec.yaml` version.
2. Rebuild the APK after changing the version.
3. Upload the rebuilt APK.
4. Install and check again.

### Android Says App Not Installed

Most likely causes:

- The new APK has a lower or equal `versionCode`.
- The package name changed.
- The signing key changed.

The package name currently comes from:

```text
android/app/build.gradle.kts
applicationId = "com.example.agridirect"
```

Do not change `applicationId` unless you intentionally want Android to treat it as a different app.

## Quick Release Summary

1. Update `pubspec.yaml`, for example `version: 1.0.3+3`.
2. Run `dart analyze`.
3. Build with `.\scripts\build-android-universal-release.ps1`.
4. Create GitHub release tag `v1.0.3`.
5. Upload `web/AgriDirect-Installer.apk`.
6. Test from an older installed Android version.

