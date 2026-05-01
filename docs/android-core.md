# Android Core

Keli Client uses Android `VpnService` for mobile full-device proxying. The Flutter layer always requests Android sing-box config with `platform=android`, writes it to the app files directory, then starts the native VPN service.

The real mobile runner is enabled when this file exists:

```text
app/android/app/libs/hiddify-core.aar
```

Fetch it with:

```powershell
powershell -ExecutionPolicy Bypass -File tools/fetch_hiddify_android_core.ps1
```

After the AAR is present, Gradle automatically includes `src/hiddifyCore/kotlin` and packages the native `libhiddify-core.so` files. Without the AAR, Android builds still compile, but connect fails explicitly with `missing-core` so the UI does not claim a fake VPN connection.

The AAR is intentionally ignored by Git because it is large and should be refreshed from the upstream release when bumping the mobile core.
