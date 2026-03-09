# App Icon Setup Guide

## Your App Icon (SVG)

The app icon has been created as an SVG file at:

```
assets/icon/app_icon.svg
```

This is a green eco-themed icon with leaves, perfect for the AgriDirect brand.

## Next Steps: Convert SVG to PNG

Since `flutter_launcher_icons` requires PNG format, you need to convert the SVG to PNG (1024x1024 or larger) for auto-resizing to all platforms.

### Option 1: Online Converter (Easiest)

1. Go to https://cloudconvert.com/svg-to-png
2. Upload `assets/icon/app_icon.svg`
3. Download the PNG as `assets/icon/app_icon.png` (1024x1024)

### Option 2: Inkscape (Local)

```bash
inkscape assets/icon/app_icon.svg -w 1024 -h 1024 -o assets/icon/app_icon.png
```

### Option 3: VS Code Extension

- Install "SVG to PNG" extension from the marketplace
- Right-click the SVG file and convert to PNG

## After Converting to PNG:

1. Add `flutter_launcher_icons` back to `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  image_path: "assets/icon/app_icon.png"
  android: true
  ios: true
```

2. Run:

```bash
flutter pub get
dart run flutter_launcher_icons
```

This will automatically generate icons for:

- ✅ Android (all resolutions)
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS

## Manual Alternative

If you prefer to set icons manually:

- **Android**: Place PNG in `android/app/src/main/res/mipmap-*/ic_launcher.png`
- **iOS**: Use Xcode to update `Assets.xcassets/AppIcon.appiconset/`
- **Web**: Update `web/favicon.png`
