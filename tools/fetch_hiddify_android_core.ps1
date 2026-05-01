$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$libsDir = Join-Path $repoRoot "app/android/app/libs"
$tempDir = Join-Path $repoRoot ".codex-temp/hiddify-core-download"
$archivePath = Join-Path $tempDir "hiddify-lib-android.tar.gz"
$downloadUrl = "https://github.com/hiddify/hiddify-core/releases/download/v4.1.0/hiddify-lib-android.tar.gz"

New-Item -ItemType Directory -Force -Path $libsDir | Out-Null
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

Write-Host "Downloading hiddify Android core..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath

Write-Host "Extracting hiddify-core.aar..."
tar -xzf $archivePath -C $tempDir
Copy-Item -Force (Join-Path $tempDir "hiddify-core.aar") (Join-Path $libsDir "hiddify-core.aar")

Write-Host "Installed app/android/app/libs/hiddify-core.aar"
Write-Host "Rebuild the Android app so Gradle enables the embedded sing-box runner."
