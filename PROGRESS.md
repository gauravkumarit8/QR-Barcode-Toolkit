# QR & Barcode Toolkit — Build Progress

Track what's actually implemented vs. still a TODO stub. Update this file as
you build — check items off in your own Codespace and commit the change.

## Setup
- [x] devcontainer.json + setup.sh (Flutter + Android SDK bootstrap)
- [x] pubspec.yaml with core dependencies declared (incl. url_launcher)
- [x] Project skeleton (main.dart, 3 tabs, settings screen, service stubs)
- [x] GitHub Actions CI: debug APK on every push to main; signed release AAB on version tags / manual run (see "Release signing" below)
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
- [x] History refreshes automatically when items are added from Scan/Generate (change notifier in HistoryService)
- [ ] Search bar

## Settings / Pro
- [x] Basic screen shell
- [x] Pro purchase flow — one-time non-consumable `pro_unlock` via in_app_purchase, price shown from Play, calls ProService.setPro(true)
- [x] Restore purchases (with a "nothing found" message)
- [ ] Create the `pro_unlock` product in Play Console + license testers (see PLAY_CONSOLE_SETUP.md)
- [ ] Pro extras promised in the original spec (custom colors, logo, SVG/HD export) — NOT built; don't advertise them until they are
- [x] Theme selector (System / Light / Dark) — persisted, applies live app-wide
- [x] Auto-save toggle — persisted AND actually drives Scan behavior (auto-saves each detected code to History when on)
- [ ] Privacy Policy link — tile is wired to open a URL, but it points at a placeholder (`example.com`); replace once the policy is hosted
- [x] App version via package_info_plus
- [x] Contact support row (mailto) — placeholder address `support@example.com` still needs replacing

## Monetization / Compliance
- [x] AdMob SDK initialized only AFTER consent resolves (ad_service.dart) — uses Google TEST ad IDs
- [x] UMP consent flow implemented and gating ad requests (form shown only where required)
- [x] "Ad privacy settings" row in Settings, shown only where the region requires it
- [x] Single banner above the bottom nav on all 3 tabs; hidden for Pro, hidden until loaded, padded to reduce accidental taps
- [x] Pro flag (ProService) hides ads and lifts the 50-item history cap — purchase flow itself still TODO
- [ ] AndroidManifest edits (see ANDROID_SETUP.md — AdMob App ID is REQUIRED or app crashes on launch)
- [ ] Create real AdMob account, real app ID + banner unit ID, then set AdService.useTestAds = false
- [ ] Data Safety form filled in Play Console, matches actual permissions/SDKs
- [ ] Privacy Policy drafted and hosted
- [x] Scoped storage confirmed — Save PNG goes through image_gallery_saver /
      MediaStore, no broad WRITE_EXTERNAL_STORAGE requested
- [ ] Target SDK / API level pinned to current Play requirement

## Release signing (needed before any Play Store upload)
- [x] build.yaml split: pushes to main build a debug APK (no secrets); version tags (v*) or manual runs build a SIGNED release AAB with monotonic build number
- [x] Release safety checks in CI (warns on test ads / test AdMob app ID / example.com placeholders; errors on placeholder ad unit with real ads on)
- [x] Signing guide written (RELEASE_SIGNING.md) for both build.gradle.kts and build.gradle
- [ ] Generate the upload keystore with keytool and BACK IT UP outside the repo
- [ ] Add the signing block to android/app/build.gradle(.kts) after `flutter create` (snippet in RELEASE_SIGNING.md)
- [ ] Add the 4 GitHub secrets (ANDROID_KEYSTORE_BASE64, _KEYSTORE_PASSWORD, _KEY_PASSWORD, _KEY_ALIAS)
- [ ] Enroll in Play App Signing when creating the app in Play Console

## Store listing
- [ ] App icon
- [ ] Screenshots
- [ ] Store listing copy + keywords
- [ ] Privacy Policy URL added to Play Console listing
