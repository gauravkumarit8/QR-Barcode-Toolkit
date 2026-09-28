# Android setup checklist (do this right after `flutter create`)

`flutter create --org com.yourcompany --platforms=android .` generates `android/`,
but the template does not include several things this app needs. Edit
`android/app/src/main/AndroidManifest.xml` and the app-level gradle file.

## 1. Permissions (inside `<manifest>`, above `<application>`)
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
```
(INTERNET is usually already there; needed for ads.)

## 2. AdMob App ID — REQUIRED or the app crashes on launch
Inside `<application>`:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713"/>
```
That value is Google's official TEST app ID. Before a Play release, replace it
with your real App ID from the AdMob console, AND set `AdService.useTestAds = false`
in `lib/services/ad_service.dart` with your real banner unit ID.

## 3. Camera hardware flag (so devices without a camera aren't excluded oddly)
Inside `<manifest>`:
```xml
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

## 4. minSdk
Open `android/app/build.gradle` (or `build.gradle.kts`) and make sure minSdk is
at least 21 (mobile_scanner / google_mobile_ads need it). Recent Flutter
templates use `flutter.minSdkVersion`; if that is below 21, set it explicitly.

## 5. Application ID
Confirm `applicationId` matches the reverse-domain ID you want permanently on
Play (e.g. `com.yourcompany.qr_barcode_toolkit`). It cannot change after publish.

## 6. Verify
```bash
flutter pub get
flutter analyze
flutter build apk --debug
```
