$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$flutterOutputDir = Join-Path $projectRoot "build\app\outputs\flutter-apk"
$splitOutputDir = Join-Path $projectRoot "build\app\outputs\apk\release"
$webOutputDir = Join-Path $projectRoot "build\web"
$canonicalUniversalApkName = "AgriDirect-Installer.apk"

Push-Location $projectRoot
try {
    flutter build web --release

    if (-not (Test-Path $webOutputDir)) {
        throw "Expected Flutter web output at $webOutputDir"
    }

    Get-ChildItem -LiteralPath $webOutputDir -Filter "*.apk" -File -ErrorAction SilentlyContinue |
        Remove-Item -Force

    $universalSource = @(
        Get-ChildItem -LiteralPath $flutterOutputDir -Filter "AgriDirect-Installer-v*-release.apk" -File -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath $flutterOutputDir -Filter "app-release.apk" -File -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath $projectRoot -Filter $canonicalUniversalApkName -File -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath (Join-Path $projectRoot "web") -Filter $canonicalUniversalApkName -File -ErrorAction SilentlyContinue
    ) |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $universalSource) {
        throw "Universal APK not found. Build it first, then rerun this script."
    }

    Copy-Item -LiteralPath $universalSource -Destination (Join-Path $webOutputDir $canonicalUniversalApkName) -Force

    if (Test-Path $splitOutputDir) {
        Get-ChildItem -LiteralPath $splitOutputDir -Filter "*.apk" -File -ErrorAction SilentlyContinue |
            ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $webOutputDir $_.Name) -Force
            }
    }

    Write-Host ""
    Write-Host "Prepared Vercel static output:"
    Get-ChildItem -LiteralPath $webOutputDir -Filter "*.apk" -File |
        Sort-Object Name |
        ForEach-Object { Write-Host " - $($_.Name)" }
}
finally {
    Pop-Location
}
