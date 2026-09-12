# AgriDirect Build & Release Scripts

### 1. Build Release APK (Builds Universal + Compatible with All Phones)
```powershell
.\scripts\build-release.ps1
```
*(To build split APKs per-architecture: `.\scripts\build-release.ps1 -Split`)*

---

### 2. Publish New Version (Builds APKs + Updates Supabase Remote Config)
```powershell
.\scripts\publish-update.ps1 -Version "1.0.7" -Notes "Smaller download size, performance improvements and bug fixes"
```
*(Upload the generated `AgriDirect-Installer.apk` to [GitHub Releases](https://github.com/vincentagbuya03/agridirect/releases/new))*



.\scripts\publish-update.ps1 -Version "1.0.7" -Notes "Smaller download size, performance improvements and bug fixes"
