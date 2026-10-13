# PharmaGuide

A pharmacy counter app: a medicine directory, point-of-sale, order approval and
reporting, with Firebase auth and offline support.

## Current state

Sign-in is email/password plus Google, with an offline guest mode and a
three-role split (admin, staff, guest). The app is two workspaces:

- **Staff shell** (three tabs): **Home** dashboard (sync status, pending
  orders, expiring/out-of-stock tiles, new order), **Medicine** search, and
  **Orders** (approve or reject pending orders, plus order history). Staff also
  get New Sale + cart, ML Kit OCR scanning, notifications and profile/appearance.
- **Admin workspace** (no bottom bar): inventory, reports and user management.

Reports read real order history and the live catalogue. Profit is an estimate
because the price list has no cost price: it is shown as revenue times a fixed
22% margin, and the screen says so beside the number.

Reading and writing are separated. The Orders and Reports screens subscribe to
repository streams, so they stay live without a manual refresh.

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
  core/
    navigation/            AppShell (bottom bar) and destination list
    theme/                 shared ThemeData, theme-mode provider
    widgets/               shared widgets (offline banners, pagination)
  routing/app_router.dart  createAppRouter() + role redirect guard
  features/
    auth/                  sign-in doors, session, roles
    dashboard/             Home tab, notifications, expiring meds
    search/                medicine catalogue + provider
    sales/                 New Sale and cart
    orders/                Orders tab, history, repository
    reports/               sales, low stock and expiry reports
    inventory/             stock and expiry management (admin)
    admin/                 admin workspace, users
    scan/                  ML Kit OCR + camera
    finder/                feature finder
    profile/               profile and appearance
```

Each feature follows the same shape: a `data/models` + `data/repositories` pair
behind an abstract repository, a `ChangeNotifier` in `presentation/providers`,
and screens in `presentation/screens`. Register new providers in `main.dart`
and add routes in `app_router.dart`.

Auth state lives in a single `AuthProvider`. The router reads it through
`context.read` and listens to it directly, so there is no separate bridge
object to keep in sync.

## Tests

```bash
flutter analyze
flutter test
```
