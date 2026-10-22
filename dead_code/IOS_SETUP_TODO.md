# PharmaGuide iOS Setup Checklist

## Prerequisites (macOS Required)
- [ ] Access to macOS (physical Mac, VM, or cloud CI like GitHub Actions/Codemagic)
- [ ] Xcode 15+ installed
- [ ] CocoaPods installed (`sudo gem install cocoapods`)
- [ ] Apple Developer Account ($99/yr) for device testing & App Store
- [ ] Flutter SDK on macOS (`flutter doctor` shows ✓ iOS toolchain)

## 1. Project Initialization
- [ ] Run `flutter create --platforms=ios .` from project root on macOS
- [ ] Verify `ios/` folder created with `Runner.xcworkspace`
- [ ] Run `cd ios && pod install` to install CocoaPods dependencies

## 2. Firebase iOS Configuration
- [ ] Add iOS app in Firebase Console (same project as Android)
- [ ] Bundle ID: `com.yourcompany.pharmaguide` (match `ios/Runner/Info.plist` CFBundleIdentifier)
- [ ] Download `GoogleService-Info.plist`
- [ ] Place in `ios/Runner/GoogleService-Info.plist`
- [ ] Add to Xcode: drag into Runner target → "Copy items if needed" ✓
- [ ] Verify `GoogleService-Info.plist` included in `Copy Bundle Resources` build phase

## 3. Info.plist Permissions & Config
Edit `ios/Runner/Info.plist`:

- [ ] Camera permission:
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>PharmaGuide needs camera access to scan prescriptions</string>
  ```
- [ ] Photo library permission:
  ```xml
  <key>NSPhotoLibraryUsageDescription</key>
  <string>PharmaGuide needs photo access to select prescription images</string>
  ```
- [ ] Google Sign-In URL scheme (from `GoogleService-Info.plist` REVERSED_CLIENT_ID):
  ```xml
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID</string>
      </array>
    </dict>
  </array>
  ```
- [ ] Minimum deployment target: iOS 13.0+ (in Xcode project settings)
- [ ] App Transport Security (if needed for non-HTTPS):
  ```xml
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
  </dict>
  ```

## 4. CocoaPods Dependencies
Verify `ios/Podfile` includes:
- [ ] `Firebase/Core`, `Firebase/Auth`, `Firebase/Firestore`
- [ ] `GoogleSignIn`
- [ ] `GoogleMLKit/TextRecognition`
- [ ] `camera_avfoundation` (camera plugin iOS impl)
- [ ] `image_picker_ios` (image_picker plugin iOS impl)
- [ ] Run `pod install` after any Podfile changes
- [ ] Open `Runner.xcworkspace` (not .xcodeproj) in Xcode

## 5. Xcode Project Configuration
- [ ] Open `ios/Runner.xcworkspace` in Xcode
- [ ] Select Runner target → Signing & Capabilities:
  - [ ] Automatically manage signing ✓
  - [ ] Team: select your Apple Developer Team
  - [ ] Bundle Identifier: matches Firebase config
- [ ] Capabilities:
  - [ ] Push Notifications (if using FCM later)
  - [ ] Keychain Sharing (for Firebase Auth persistence)
- [ ] Build Settings:
  - [ ] iOS Deployment Target: 13.0
  - [ ] Swift Version: 5.0 (if any Swift code)

## 6. App Icons & Launch Screen
- [ ] Update `flutter_launcher_icons` in `pubspec.yaml`:
  ```yaml
  flutter_launcher_icons:
    android: true
    ios: true
    image_path: "assets/images/baseIcon.png"
  ```
- [ ] Run `flutter pub get && flutter pub run flutter_launcher_icons:main`
- [ ] Verify `ios/Runner/Assets.xcassets/AppIcon.appiconset/` populated
- [ ] Configure Launch Screen: `ios/Runner/LaunchScreen.storyboard` or `LaunchScreen.xib`

## 7. Platform-Specific Code Adjustments
- [ ] Check `google_sign_in` iOS setup matches [official guide](https://pub.dev/packages/google_sign_in#ios-integration)
- [ ] Verify `camera` plugin works on iOS (uses `camera_avfoundation`)
- [ ] Verify `image_picker` works on iOS (uses `image_picker_ios`)
- [ ] Test `google_mlkit_text_recognition` on iOS (downloads model on first use)
- [ ] Handle iOS-specific UI differences (Cupertino vs Material)

## 8. Build & Test
- [ ] `flutter clean && flutter pub get`
- [ ] `cd ios && pod install && cd ..`
- [ ] `flutter build ios --debug` (simulator)
- [ ] `flutter run -d ios` (on simulator)
- [ ] Test on physical device: `flutter run -d <device_id>`
- [ ] Test all features: Auth, Search, Scan (camera), Orders, Profile, Sync
- [ ] `flutter build ios --release` (for TestFlight/App Store)
- [ ] Archive in Xcode: Product → Archive → Distribute App

## 9. CI/CD Setup (Optional but Recommended)
- [ ] Codemagic: `codemagic.yaml` with iOS workflow
- [ ] GitHub Actions: `.github/workflows/ios.yml` with macOS runner
- [ ] Fastlane: `fastlane match` for certificates, `fastlane pilot` for TestFlight
- [ ] Automated builds on push/PR

## 10. App Store Preparation
- [ ] App Store Connect: create app record
- [ ] Screenshots (6.7", 6.5", 5.5", iPad)
- [ ] Privacy policy URL
- [ ] App description, keywords, category
- [ ] Age rating questionnaire
- [ ] Submit for Review

---

**Note**: Steps 1-8 require macOS. Steps 9-10 can be automated via CI/CD.
Run `flutter doctor` on macOS to verify iOS toolchain before starting.