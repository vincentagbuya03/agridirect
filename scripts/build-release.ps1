param (
    [switch]$Split = $false
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $projectRoot "build\app\outputs\flutter-apk"
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    throw "Could not find pubspec.yaml at $pubspecPath"
}

$versionLine = Select-String -Path $pubspecPath -Pattern '^version:\s*(.+)' | Select-Object -First 1
if (-not $versionLine) {
    throw "Could not find a version entry in pubspec.yaml"
}

$version = $versionLine.Matches[0].Groups[1].Value.Trim()
Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " Building AgriDirect v$version Release" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

Push-Location $projectRoot
try {
    if ($Split) {
        Write-Host "Building Split APKs (per-ABI: arm64, armeabi-v7a, x86_64)..." -ForegroundColor Yellow
        flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols

        $arm64Source = Join-Path $outputDir "app-arm64-v8a-release.apk"
        $githubInstaller = Join-Path $outputDir "AgriDirect-Installer.apk"
        if (Test-Path $arm64Source) {
            Copy-Item -LiteralPath $arm64Source -Destination $githubInstaller -Force
            Write-Host "✔ Auto-renamed app-arm64-v8a-release.apk -> AgriDirect-Installer.apk" -ForegroundColor Green
        }
    } else {
        Write-Host "Building Universal APK (compatible with 100% of Android phones)..." -ForegroundColor Yellow
        flutter build apk --release --target-platform android-arm,android-arm64 --obfuscate --split-debug-info=build/app/outputs/symbols

        $universalSource = Join-Path $outputDir "app-release.apk"
        $githubInstaller = Join-Path $outputDir "AgriDirect-Installer.apk"

        if (Test-Path $universalSource) {
            Copy-Item -LiteralPath $universalSource -Destination $githubInstaller -Force
        }
    }

    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host " BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "Output APKs in build/app/outputs/flutter-apk/:" -ForegroundColor Cyan
    Get-ChildItem $outputDir -Filter "*.apk" | Sort-Object Name |
        ForEach-Object {
            $size = [math]::Round($_.Length / 1MB, 1)
            Write-Host " -> $($_.Name) ($size MB)" -ForegroundColor Yellow
        }

    Write-Host ""
    Write-Host "Upload to GitHub Releases:" -ForegroundColor White
    Write-Host " https://github.com/vincentagbuya03/agridirect/releases/new" -ForegroundColor Yellow
}
finally {
    Pop-Location
}
