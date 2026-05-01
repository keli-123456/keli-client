param(
    [switch]$BuildAndroid,
    [switch]$BuildWindows,
    [switch]$SkipPubGet,
    [switch]$StaticOnly,
    [switch]$SkipStatic
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$AppDir = Join-Path $RepoRoot 'app'

if (-not (Test-Path $AppDir)) {
    throw "Flutter app directory not found: $AppDir"
}

if (-not $SkipStatic) {
    $androidBridgeCheck = Join-Path $PSScriptRoot 'verify-android-bridge.ps1'
    if (-not (Test-Path $androidBridgeCheck)) {
        throw "Android bridge verifier not found: $androidBridgeCheck"
    }
    & $androidBridgeCheck
    if (-not $?) {
        throw 'Android bridge verifier failed'
    }
}

if ($StaticOnly) {
    return
}

Push-Location $AppDir
try {
    if (-not $SkipPubGet) {
        flutter pub get
    }

    flutter analyze lib test
    flutter test --reporter expanded

    if ($BuildAndroid) {
        flutter build apk --debug
    }

    if ($BuildWindows) {
        flutter config --enable-windows-desktop
        flutter build windows --debug
    }
}
finally {
    Pop-Location
}
