$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$flutterApkDir = Join-Path $projectRoot "build\app\outputs\flutter-apk"
$splitApkDir = Join-Path $projectRoot "build\app\outputs\apk\release"
$webDir = Join-Path $projectRoot "web"
$universalWebName = "agridirect-android-universal-release.apk"

if (-not (Test-Path $webDir)) {
    throw "Web directory not found at $webDir"
}

$universalSource = Get-ChildItem -LiteralPath $flutterApkDir -Filter "AgriDirect-Installer-*.apk" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $universalSource) {
    throw "Universal APK not found in $flutterApkDir. Build the APK first."
}

Copy-Item -LiteralPath $universalSource.FullName -Destination (Join-Path $webDir $universalWebName) -Force

if (Test-Path $splitApkDir) {
    Get-ChildItem -LiteralPath $splitApkDir -Filter "*.apk" -File -ErrorAction SilentlyContinue |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $webDir $_.Name) -Force
        }
}

Write-Host ""
Write-Host "APK files published to web/:"
Get-ChildItem -LiteralPath $webDir -Filter "*.apk" -File |
    Sort-Object Name |
    ForEach-Object { Write-Host " - $($_.Name)" }
