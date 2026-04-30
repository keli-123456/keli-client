# App

This folder is reserved for the Flutter application.

Initial app modules:

- `auth`
- `dashboard`
- `nodes`
- `store`
- `settings`
- `logs`
- `shared/api`
- `shared/store`
- `shared/core`

State management recommendation:

- Riverpod for app state and dependency injection
- Dio or a similar typed HTTP client
- Secure storage for `auth_data`

Do not put platform-specific proxy control directly in UI screens. Call the
platform bridge through a small core manager interface.

## Bootstrap Platform Files

This repository currently contains the Flutter source code and project
metadata. After installing Flutter, run this from this directory to generate
Windows and Android platform folders:

```powershell
flutter create --platforms=windows,android .
flutter pub get
flutter run -d windows
```

The current UI uses mock API/core implementations. Real `keliboard` API wiring
should replace `MockKeliApi`, and real sing-box lifecycle control should replace
`MockCoreManager`.
