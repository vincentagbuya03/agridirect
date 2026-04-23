$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$universalOutputDir = Join-Path $projectRoot "build\app\outputs\flutter-apk"
$splitOutputDir = Join-Path $projectRoot "build\app\outputs\apk\release"
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    throw "Could not find pubspec.yaml at $pubspecPath"
}

$versionLine = Select-String -Path $pubspecPath -Pattern '^version:\s*([^\+]+)' | Select-Object -First 1
if (-not $versionLine) {
    throw "Could not find a version entry in pubspec.yaml"
}

$version = $versionLine.Matches[0].Groups[1].Value.Trim()

Push-Location $projectRoot
try {
    flutter build apk --release --split-per-abi

    $staleFlutterApkFiles = @(
        "app-arm64-v8a-release.apk",
        "app-arm64-v8a-release.apk.sha1",
        "app-armeabi-v7a-release.apk",
        "app-armeabi-v7a-release.apk.sha1",
        "app-x86_64-release.apk",
        "app-x86_64-release.apk.sha1"
    )

    foreach ($staleFile in $staleFlutterApkFiles) {
        $stalePath = Join-Path $universalOutputDir $staleFile
        if (Test-Path $stalePath) {
            Remove-Item -LiteralPath $stalePath -Force
        }
    }

    $renameMap = @{
        "app-arm64-v8a-release.apk"   = "AgriDirect-Installer-arm64-v8a-v$version.apk"
        "app-armeabi-v7a-release.apk" = "AgriDirect-Installer-armeabi-v7a-v$version.apk"
        "app-x86_64-release.apk"      = "AgriDirect-Installer-x86_64-v$version.apk"
    }

    foreach ($sourceName in $renameMap.Keys) {
        $sourcePath = Join-Path $splitOutputDir $sourceName
        if (Test-Path $sourcePath) {
            $targetPath = Join-Path $splitOutputDir $renameMap[$sourceName]
            if (Test-Path $targetPath) {
                Remove-Item -LiteralPath $targetPath -Force
            }
            Rename-Item -LiteralPath $sourcePath -NewName $renameMap[$sourceName]
        }
    }

    Write-Host ""
    Write-Host "Renamed APK outputs:"
    @(
        if (Test-Path $universalOutputDir) {
            Get-ChildItem $universalOutputDir -Filter "AgriDirect-Installer-*.apk"
        }
        if (Test-Path $splitOutputDir) {
            Get-ChildItem $splitOutputDir -Filter "AgriDirect-Installer-*.apk"
        }
    ) |
        Sort-Object Name |
        ForEach-Object { Write-Host " - $($_.Name)" }
}
finally {
    Pop-Location
}
