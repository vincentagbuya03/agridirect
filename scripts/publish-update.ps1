param (
    [string]$Version,
    [string]$Notes = "Performance improvements and bug fixes",
    [switch]$Critical = $false
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $projectRoot "build\app\outputs\flutter-apk"
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    throw "Could not find pubspec.yaml at $pubspecPath"
}

# ── 1. Update pubspec.yaml version if provided ──────────────────────────────
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
    $targetVer = "1.0.4"
    $targetBuild = 4
}

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " Building AgriDirect v$targetVer+$targetBuild (Split-per-ABI)" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# ── 2. Run Release Build ──────────────────────────────────────────────────
Push-Location $projectRoot
try {
    flutter build apk --release --split-per-abi

    Write-Host ""
    Write-Host "Build finished! APK outputs:" -ForegroundColor Green
    Get-ChildItem $outputDir -Filter "*.apk" | Sort-Object Name |
        ForEach-Object { Write-Host " -> $($_.FullName) ($([math]::Round($_.Length / 1MB, 1)) MB)" -ForegroundColor Yellow }

    # ── 3. Update Supabase Remote Config ──────────────────────────────────
    Write-Host ""
    Write-Host "Updating Supabase remote version config..." -ForegroundColor Cyan

    $supabaseUrl = "https://ywfppgarzyksacgbesme.supabase.co"
    $supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3ZnBwZ2Fyenlrc2FjZ2Jlc21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3NzEzMjcsImV4cCI6MjA4NzM0NzMyN30.aX1HIacJsHV8gU-9tGONnDpucE9vePWOrJbgMR4fSzs"

    $notesArray = $Notes -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    if ($notesArray.Count -eq 0) {
        $notesArray = @($Notes)
    }

    $apkUrlTemplate = "https://github.com/vincentagbuya03/agridirect/releases/download/v$targetVer/app-{abi}-release.apk"

    $headers = @{
        "apikey" = $supabaseKey
        "Authorization" = "Bearer $supabaseKey"
        "Content-Type" = "application/json"
        "Prefer" = "resolution=merge-duplicates"
    }

    $body = @{
        "platform" = "android"
        "latest_version" = $targetVer
        "latest_build_number" = $targetBuild
        "apk_url" = $apkUrlTemplate
        "release_notes" = $notesArray
        "is_critical" = [bool]$Critical
        "updated_at" = (Get-Date).ToUniversalTime().ToString("o")
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/app_versions?platform=eq.android" -Method Patch -Headers $headers -Body $body
        Write-Host "Supabase app_versions updated successfully!" -ForegroundColor Green
    } catch {
        Write-Warning "Direct Supabase REST update returned: $_"
    }

    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host " RELEASE READY FOR v$targetVer" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "1. Upload the split APKs from:" -ForegroundColor White
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
