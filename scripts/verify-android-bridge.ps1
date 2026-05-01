param()

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$AppDir = Join-Path $RepoRoot 'app'

$ManifestPath = Join-Path $AppDir 'android\app\src\main\AndroidManifest.xml'
$MainActivityPath = Join-Path $AppDir 'android\app\src\main\kotlin\com\keli\keli_client\MainActivity.kt'
$VpnServicePath = Join-Path $AppDir 'android\app\src\main\kotlin\com\keli\keli_client\KeliVpnService.kt'
$RunnerPath = Join-Path $AppDir 'android\app\src\main\kotlin\com\keli\keli_client\KeliSingBoxRunner.kt'
$CoreManagerPath = Join-Path $AppDir 'lib\src\services\core_manager.dart'

function Assert-FileContains {
    param(
        [string]$Path,
        [string]$Needle,
        [string]$Description
    )

    if (-not (Test-Path $Path)) {
        throw "missing file for ${Description}: $Path"
    }

    $text = Get-Content -Path $Path -Raw
    if (-not $text.Contains($Needle)) {
        throw "Android bridge contract failed: $Description ($Needle)"
    }
}

Assert-FileContains $ManifestPath 'android:name=".KeliVpnService"' 'VPN service registration'
Assert-FileContains $ManifestPath 'android.permission.BIND_VPN_SERVICE' 'VPN service permission'
Assert-FileContains $ManifestPath 'android.net.VpnService' 'VPN service intent filter'
Assert-FileContains $ManifestPath 'android:foregroundServiceType="specialUse"' 'Android 14 foreground service type'
Assert-FileContains $ManifestPath 'android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE' 'Android 14 special-use subtype'

$coreChannel = 'com.keli.keli_client/core'
Assert-FileContains $MainActivityPath $coreChannel 'native core method channel'
Assert-FileContains $CoreManagerPath $coreChannel 'Dart core method channel'

foreach ($method in @('"prepare"', '"applyConfig"', '"connect"', '"disconnect"', '"status"')) {
    Assert-FileContains $MainActivityPath $method "native method handler $method"
}

foreach ($method in @("'prepare'", "'applyConfig'", "'connect'", "'disconnect'", "'status'")) {
    Assert-FileContains $CoreManagerPath $method "Dart method call $method"
}

Assert-FileContains $VpnServicePath 'ACTION_START = "com.keli.keli_client.START_VPN"' 'VPN start action'
Assert-FileContains $VpnServicePath 'ACTION_STOP = "com.keli.keli_client.STOP_VPN"' 'VPN stop action'
Assert-FileContains $VpnServicePath 'KEY_STATUS = "status"' 'VPN status preference'
Assert-FileContains $VpnServicePath 'KEY_RUNNING = "running"' 'VPN running preference'
Assert-FileContains $VpnServicePath 'onRevoke()' 'VPN permission revoke handler'
Assert-FileContains $VpnServicePath 'startForeground(' 'VPN foreground startup'

Assert-FileContains $RunnerPath 'HiddifySingBoxRunner' 'embedded Android core runner bridge'
Assert-FileContains $RunnerPath 'missing-core' 'missing Android core status'
Assert-FileContains $CoreManagerPath 'bool get supportsLatencyTesting => false' 'Android latency support marker'

Write-Host 'Android bridge contract verified.'
