# QR & Barcode Toolkit — Build Progress

Track what's actually implemented vs. still a TODO stub. Update this file as
you build — check items off in your own Codespace and commit the change.

## Setup
- [x] devcontainer.json + setup.sh (Flutter + Android SDK bootstrap)
- [x] pubspec.yaml with core dependencies declared (incl. url_launcher)
- [x] Project skeleton (main.dart, 3 tabs, settings screen, service stubs)
- [x] GitHub Actions CI: builds release APK on push to main, uploads as artifact
      (unsigned — uses debug signing by default; fine for internal testing,
      NOT for Play Store upload — see "Release signing" below)
- [ ] `flutter doctor` clean on Codespace
- [ ] Package ID finalized (`com.yourcompany.qrbarcodetoolkit` placeholder still in build.gradle)

## Scan tab
- [x] Camera permission gated behind in-app rationale dialog (not requested on launch)
- [x] MobileScanner wired up, detects + shows raw value
- [x] Scan frame overlay (simple bordered box; corner-marker styling still TODO)
- [x] Result card actions: Copy / Open / Share / Save to History — all functional
- [x] Torch toggle, auto-detect switch, flip camera button — wired to MobileScannerController
- [ ] Phishing/malicious URL warning before opening scanned links (currently just a
      generic "open this link?" confirmation — no actual safety check yet)
- [ ] Scan frame corner markers (currently a plain rounded rectangle)

## Generate tab
- [x] Type selector chips (v1 trimmed to Text / URL / WiFi / Phone / Barcode)
- [x] Live QR preview via qr_flutter
- [x] Save PNG — captures the preview via RepaintBoundary, saves through
      image_gallery_saver (MediaStore-backed, scoped storage compliant)
- [x] Share — shares the generated PNG + text via share_plus
- [x] Save to History — functional
- [x] Per-type input forms — Text, URL, Phone (tel: prefix), WiFi (SSID/password/
      encryption dropdown building a proper WIFI: string) all have their own fields now
- [x] Barcode format rendering — Code128/EAN-13/UPC-A/Code39/ITF via barcode_widget,
      with an errorBuilder so an invalid value (e.g. wrong digit count for EAN-13)
      shows a message instead of crashing
- [ ] Size/margin sliders, color picker + logo (Pro-gated, v2)

## History tab
- [x] Empty state UI
- [x] HistoryService: real persistence via shared_preferences (JSON-encoded list)
- [x] Free-tier item cap (50 items, oldest dropped first) — Pro-bypass still TODO
- [x] List rendering from real data, newest first
- [x] Swipe to delete (Dismissible)
- [x] Detail view (Copy / Open / Share / Delete) — functional
- [x] "Re-generate" button — wired via a shared ValueNotifier held in RootShell;
      tapping it switches to the Generate tab with the value prefilled as Text type
- [ ] Search bar

## Settings / Pro
- [x] Basic screen shell
- [ ] Pro purchase flow (Remove Ads, one-time IAP)
- [ ] Restore purchases
- [ ] Dark mode toggle wired to actual theme (currently follows system only)
- [ ] Auto-save toggle persisted
- [ ] Privacy Policy link (needs hosted GitHub Pages URL)
- [ ] App version via package_info_plus

## Monetization / Compliance
- [ ] AdMob SDK initialized (ad_service.dart is a stub)
- [ ] UMP consent flow implemented and gating ad requests
- [ ] Banner ad placements added to Scan/Generate/History (hidden after Pro purchase)
- [ ] Data Safety form filled in Play Console, matches actual permissions/SDKs
- [ ] Privacy Policy drafted and hosted
- [x] Scoped storage confirmed — Save PNG goes through image_gallery_saver /
      MediaStore, no broad WRITE_EXTERNAL_STORAGE requested
- [ ] Target SDK / API level pinned to current Play requirement

## Release signing (needed before any Play Store upload)
- [ ] Generate an upload keystore (`keytool -genkey -v -keystore ...`)
- [ ] Add `key.properties` (gitignored) + reference it in `android/app/build.gradle`
- [ ] Update build.yaml to inject signing secrets via GitHub Actions secrets
      before producing a Play-uploadable APK/AAB (current CI build is debug-signed)
- [ ] Switch `flutter build apk` → `flutter build appbundle` for Play Store (AAB required)

## Store listing
- [ ] App icon
- [ ] Screenshots
- [ ] Store listing copy + keywords
- [ ] Privacy Policy URL added to Play Console listing
