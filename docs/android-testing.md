# Android Testing

## Current Local Limitation

This Windows workspace has Android SDK and two AVD profiles, but neither can run here:

- `Keli_Pixel_5_API_35` is `x86_64` and requires hardware virtualization. The emulator reports `x86_64 emulation currently requires hardware acceleration`.
- `Keli_Pixel_5_ARM_API_35` is `arm64`, but QEMU2 on an `x86_64` host does not support that system image.

So this machine can build Android APKs, but it cannot run a local Android emulator unless hardware virtualization is enabled for the host.

## No Physical Phone Options

1. Enable virtualization on the host, then run the `x86_64` AVD.
2. Use the GitHub Actions `Android Smoke` workflow from the Actions tab.
3. Use a cloud Android device service for the full VPN/browser test, such as Firebase Test Lab, BrowserStack, or Genymotion Cloud.

## Local APK Build

```powershell
powershell -ExecutionPolicy Bypass -File tools/fetch_hiddify_android_core.ps1
cd app
C:\Users\Administrator\develop\flutter\bin\flutter.bat build apk --debug
```

APK path:

```text
app/build/app/outputs/flutter-apk/app-debug.apk
```

## Smoke Coverage

The GitHub Actions smoke workflow checks:

- Flutter analyze and unit tests.
- Android debug APK build with `hiddify-core.aar`.
- APK contains `libhiddify-core.so`.
- App installs and launches in an Android emulator.
- `KeliVpnService` is present in the installed package.

Full VPN validation still needs a runnable Android environment because it requires Android VPN permission, a logged-in account, selecting a node, and verifying browser traffic.
