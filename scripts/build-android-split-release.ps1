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
Write-Host "Building AgriDirect v$version (split per ABI + obfuscated)..." -ForegroundColor Cyan

Push-Location $projectRoot
try {
    flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols

    # ── 1. Copy arm64 as the GitHub Releases installer ──────────────────────
    $arm64Source = Join-Path $outputDir "app-arm64-v8a-release.apk"
    $githubInstaller = Join-Path $outputDir "AgriDirect-Installer.apk"

    if (Test-Path $arm64Source) {
        Copy-Item -LiteralPath $arm64Source -Destination $githubInstaller -Force
        Write-Host ""
        Write-Host "GitHub Release file ready:" -ForegroundColor Green
        Write-Host " -> AgriDirect-Installer.apk  (upload this to GitHub Releases)" -ForegroundColor Green
    } else {
        Write-Warning "arm64 APK not found at $arm64Source"
    }

    # ── 2. Show all output APKs ──────────────────────────────────────────────
    Write-Host ""
    Write-Host "All output APKs:" -ForegroundColor Cyan
    Get-ChildItem $outputDir -Filter "*.apk" | Sort-Object Name |
        ForEach-Object { Write-Host " - $($_.Name)  ($([math]::Round($_.Length / 1MB, 1)) MB)" }

    Write-Host ""
    Write-Host "NEXT STEP: Upload  AgriDirect-Installer.apk  to GitHub Releases:" -ForegroundColor Yellow
    Write-Host " https://github.com/vincentagbuya03/agridirect/releases/new" -ForegroundColor Yellow
}
finally {
    Pop-Location
}
