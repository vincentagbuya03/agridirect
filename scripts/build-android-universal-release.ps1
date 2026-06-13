$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$flutterOutputDir = Join-Path $projectRoot "build\app\outputs\flutter-apk"
$webDir = Join-Path $projectRoot "web"
$canonicalApkName = "AgriDirect-Installer.apk"

Push-Location $projectRoot
try {
    flutter build apk --release

    $universalSource = @(
        Get-ChildItem -LiteralPath $flutterOutputDir -Filter "AgriDirect-Installer-v*-release.apk" -File -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath $flutterOutputDir -Filter "app-release.apk" -File -ErrorAction SilentlyContinue
    ) |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $universalSource) {
        throw "Universal APK not found in $flutterOutputDir after the release build."
    }

    Copy-Item -LiteralPath $universalSource.FullName -Destination (Join-Path $webDir $canonicalApkName) -Force

    Write-Host ""
    Write-Host "Universal APK ready:"
    Write-Host " - Build output: $($universalSource.Name)"
    Write-Host " - Web download: $canonicalApkName"
}
finally {
    Pop-Location
}
