# heavenrock_registry

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Android Google Sign-In setup

Android requires native OAuth configuration in addition to Firebase web auth.

1. In Firebase Console, open your Android app (`com.example.heavenrock_registry`) and add SHA-1 and SHA-256 fingerprints for your debug/release keystores.
2. In Firebase Authentication, enable Google as a sign-in provider.
3. Download a fresh `google-services.json` and replace `android/app/google-services.json`.
4. Verify the new `google-services.json` includes non-empty `oauth_client` entries and `services.appinvite_service.other_platform_oauth_client` with a `client_type: 3` Web Client ID.
5. Run the app with the Web Client ID passed to Flutter:

```bash
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=216680883540-apdshmsar7hhhvo9tfhjvr66a4hdokb9.apps.googleusercontent.com
```

Without the Web Client ID and OAuth clients in `google-services.json`, Google Sign-In on Android cannot securely exchange tokens with Firebase Auth.
//flutter run -d 00008110-001545200C05801E --dart-define=GOOGLE_WEB_CLIENT_ID=216680883540-apdshmsar7hhhvo9tfhjvr66a4hdokb9.apps.googleusercontent.com
//flutter run -d 9F832C20-6CB5-42D4-80F9-3555F259E7C2 --dart-define=GOOGLE_WEB_CLIENT_ID=216680883540-apdshmsar7hhhvo9tfhjvr66a4hdokb9.apps.googleusercontent.com