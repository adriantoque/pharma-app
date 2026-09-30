# PharmaGuide

A pharmacy companion app with a medicine directory and first-aid guidance.

## Current state

Email/password sign-up and sign-in plus Google sign-in are working. Signing in
lands on a placeholder screen; the medicine directory and first-aid guidance
features have not been built yet.

## Running

```bash
flutter pub get
flutter run                 # Android device or emulator
flutter run -d chrome       # web
```

## Before a store release

1. **Register your release keystore's fingerprints in Firebase.** Google
   sign-in fails at runtime with a developer error unless the SHA-1 and SHA-256
   of the signing key are added under *Project settings → Your apps → Android
   app → Google services*. Play App Signing means the key that reaches users is
   not your upload key, so register both.
2. **Create a release keystore and configure signing:**

   ```bash
   keytool -genkey -v -keystore ~/pharmaguide-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias pharmaguide
   ```

   Then copy `android/key.properties.example` to `android/key.properties` and
   fill it in. Both that file and the keystore are already git-ignored. Without
   it, `flutter build apk --release` falls back to the debug key.

3. **Add the Android OAuth client** to `google-services.json`. It currently
   contains only the Web client (`client_type: 3`); Android also wants a
   `client_type: 1` entry.

## Layout

```
lib/
  app.dart                 MaterialApp.router host
  main.dart                provider graph, owned router
  bootstrap/               Firebase init + failure screen
  core/theme/              shared ThemeData
  routing/app_router.dart  createAppRouter() + redirect guard
  features/
    auth/                  presentation / data
```

`features/auth` holds everything that exists so far. When you add a feature,
mirror the shape already used there: a `data/models` + `data/repositories`
pair behind an abstract repository, a single `ChangeNotifier` in
`presentation/providers`, and screens in `presentation/screens`. Register new
providers in `main.dart` and add routes in `app_router.dart`.

Auth state lives in a single `AuthProvider`. The router reads it through
`context.read` and listens to it directly, so there is no separate bridge
object to keep in sync.

## Tests

```bash
flutter analyze
flutter test
```
