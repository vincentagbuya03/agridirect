param (
    [string]$Version,
    [string]$Notes = "Performance improvements and bug fixes",
    [switch]$Critical = $false,
    [switch]$BuildUniversal = $false,
    [switch]$SkipBuild = $false
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $projectRoot "build\app\outputs\flutter-apk"
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    throw "Could not find pubspec.yaml at $pubspecPath"
}

# 1. Update pubspec.yaml version if provided
$pubspecContent = Get-Content $pubspecPath -Raw
$versionMatch = [regex]::Match($pubspecContent, 'version:\s*(\d+\.\d+\.\d+)\+(\d+)')

if ($versionMatch.Success) {
    $currentVer = $versionMatch.Groups[1].Value
    $currentBuild = [int]$versionMatch.Groups[2].Value

    if ($Version) {
        $newVer = $Version.TrimStart('v', 'V')
        $newBuild = $currentBuild + 1
        $newVersionString = "$newVer+$newBuild"
        $pubspecContent = $pubspecContent -replace 'version:\s*\d+\.\d+\.\d+\+\d+', "version: $newVersionString"
        Set-Content -Path $pubspecPath -Value $pubspecContent -NoNewline
        Write-Host "Updated pubspec.yaml version to $newVersionString" -ForegroundColor Green
        $targetVer = $newVer
        $targetBuild = $newBuild
    } else {
        $targetVer = $currentVer
        $targetBuild = $currentBuild
    }
} else {
    $targetVer = "1.0.7"
    $targetBuild = 9
}

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " AgriDirect Release Manager v$targetVer+$targetBuild" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

Push-Location $projectRoot
try {
    # 2. Run Release Build unless -SkipBuild is passed
    if (-not $SkipBuild) {
        Write-Host "Building release APKs with split-per-abi & obfuscation..." -ForegroundColor Yellow
        flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols
    } else {
        Write-Host "Skipping flutter build as requested (-SkipBuild)..." -ForegroundColor Yellow
    }

    # Auto-rename / copy app-arm64-v8a-release.apk to AgriDirect-Installer.apk
    $arm64Source = Join-Path $outputDir "app-arm64-v8a-release.apk"
    $githubInstaller = Join-Path $outputDir "AgriDirect-Installer.apk"
    $versionedInstaller = Join-Path $outputDir "AgriDirect-v$targetVer.apk"

    if (Test-Path $arm64Source) {
        Copy-Item -LiteralPath $arm64Source -Destination $githubInstaller -Force
        Copy-Item -LiteralPath $arm64Source -Destination $versionedInstaller -Force
        Write-Host "[OK] Auto-renamed app-arm64-v8a-release.apk -> AgriDirect-Installer.apk" -ForegroundColor Green
        Write-Host "[OK] Created $versionedInstaller" -ForegroundColor Green

        # Copy to web directory for web direct-downloads
        $webDir = Join-Path $projectRoot "web"
        if (Test-Path $webDir) {
            Copy-Item -LiteralPath $arm64Source -Destination (Join-Path $webDir "AgriDirect-Installer.apk") -Force
            Copy-Item -LiteralPath $arm64Source -Destination (Join-Path $webDir "app-release.apk") -Force
            Write-Host "[OK] Copied installer to web/AgriDirect-Installer.apk and web/app-release.apk" -ForegroundColor Green
        }
    }

    # Optional Universal build only if requested with -BuildUniversal
    if ($BuildUniversal -and (-not $SkipBuild)) {
        Write-Host "Building Universal APK (android-arm + android-arm64)..." -ForegroundColor Yellow
        flutter build apk --release --target-platform android-arm,android-arm64 --obfuscate --split-debug-info=build/app/outputs/symbols
        $universalSource = Join-Path $outputDir "app-release.apk"
        $universalInstaller = Join-Path $outputDir "AgriDirect-Universal-Installer.apk"
        if (Test-Path $universalSource) {
            Copy-Item -LiteralPath $universalSource -Destination $universalInstaller -Force
        }
    }

    Write-Host ""
    Write-Host "APK output files:" -ForegroundColor Green
    if (Test-Path $outputDir) {
        $apkFiles = Get-ChildItem -Path $outputDir -Filter "*.apk" | Sort-Object Name
        foreach ($apk in $apkFiles) {
            $sizeMB = [math]::Round($apk.Length / 1048576, 1)
            Write-Host " -> $($apk.Name) ($sizeMB MB)" -ForegroundColor Yellow
        }
    }

    # 3. Update Supabase Remote Config
    Write-Host ""
    Write-Host "Updating Supabase remote version config..." -ForegroundColor Cyan

    $supabaseUrl = "https://ywfppgarzyksacgbesme.supabase.co"
    $supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3ZnBwZ2Fyenlrc2FjZ2Jlc21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3NzEzMjcsImV4cCI6MjA4NzM0NzMyN30.aX1HIacJsHV8gU-9tGONnDpucE9vePWOrJbgMR4fSzs"

    $notesArray = $Notes -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    if ($notesArray.Count -eq 0) {
        $notesArray = @($Notes)
    }

    $apkUrl = "https://github.com/vincentagbuya03/agridirect/releases/download/v$targetVer/AgriDirect-Installer.apk"

    $headers = @{
        "apikey" = $supabaseKey
        "Authorization" = "Bearer $supabaseKey"
        "Content-Type" = "application/json"
    }

    $updated = $false

    # Try RPC call (security definer bypasses RLS)
    $rpcPayload = @{
        "p_platform" = "android"
        "p_latest_version" = $targetVer
        "p_latest_build_number" = [int]$targetBuild
        "p_apk_url" = $apkUrl
        "p_release_notes" = $notesArray
        "p_is_critical" = [bool]$Critical
    } | ConvertTo-Json

    try {
        $rpcRes = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/publish_app_version" -Method Post -Headers $headers -Body $rpcPayload
        if ($rpcRes) {
            Write-Host "[OK] Supabase app_versions updated to v$targetVer (Build $targetBuild) via RPC!" -ForegroundColor Green
            $updated = $true
        }
    } catch {
        Write-Warning "RPC publish_app_version error: $_"
    }

    if (-not $updated) {
        $patchBody = @{
            "latest_version" = $targetVer
            "latest_build_number" = [int]$targetBuild
            "apk_url" = $apkUrl
            "release_notes" = $notesArray
            "is_critical" = [bool]$Critical
            "updated_at" = (Get-Date).ToUniversalTime().ToString("o")
        } | ConvertTo-Json

        $patchHeaders = @{
            "apikey" = $supabaseKey
            "Authorization" = "Bearer $supabaseKey"
            "Content-Type" = "application/json"
            "Prefer" = "return=representation"
        }

        try {
            $patchRes = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/app_versions?platform=eq.android" -Method Patch -Headers $patchHeaders -Body $patchBody
            if ($patchRes -and $patchRes.Count -gt 0) {
                Write-Host "[OK] Supabase app_versions updated via direct PATCH!" -ForegroundColor Green
                $updated = $true
            } else {
                Write-Warning "RLS note: Direct PATCH returned 0 updated rows."
            }
        } catch {
            Write-Warning "Direct Supabase PATCH error: $_"
        }
    }

    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host " RELEASE READY FOR v$targetVer" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "1. Upload AgriDirect-Installer.apk from:" -ForegroundColor White
    Write-Host "   $outputDir" -ForegroundColor Yellow
    Write-Host "2. To GitHub Releases:" -ForegroundColor White
    Write-Host "   https://github.com/vincentagbuya03/agridirect/releases/new" -ForegroundColor Yellow
    Write-Host "   (Tag: v$targetVer)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Existing users will automatically see the Update Popup on their phones!" -ForegroundColor Green
}
finally {
    Pop-Location
}
