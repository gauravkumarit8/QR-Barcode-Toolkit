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
- [x] Scan frame overlay with real corner markers (CustomPainter, not a plain rectangle)
- [x] Result card actions: Copy / Open / Share / Save to History — all functional
- [x] Torch toggle, auto-detect switch, flip camera button — wired to MobileScannerController
- [x] Fixed: ML Kit barcode model wasn't bundled — added install-time dependency meta-data to AndroidManifest.xml + an 8s in-app hint if nothing's detected (needs internet once per device; sideloaded APKs still download on first Scan tab use, Play Store installs pre-fetch at install time)
- [x] Heuristic link warning before opening (lib/utils/link_safety.dart) — flags URL
      shorteners, raw IP-address hosts, punycode/lookalike domains, and userinfo@host
      disguise tricks; shown as a red banner in the Open confirmation, button becomes
      "Open anyway". This is NOT a real reputation/phishing check (no network call
      by design) — it only catches a few common red flags on-device.

## Generate tab
- [x] Type selector chips (v1 trimmed to Text / URL / WiFi / Phone / Barcode)
- [x] Live QR preview via qr_flutter
- [x] Save PNG — captures the preview via RepaintBoundary, saves through
      image_gallery_saver (MediaStore-backed, scoped storage compliant)
- [x] Share — shares the generated PNG + text via share_plus; now waits for the frame to paint before capturing and tells the user explicitly if the image couldn't be attached (was silently falling back to text-only before)
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
- [x] Search bar — inline field at the top of History; filters by content, or by the words "scanned" / "generated"; "no matches" state
- [x] Fixed swipe-to-delete: row is removed from the list synchronously (a Dismissible left in the tree throws in debug)

## Settings / Pro
- [x] Basic screen shell
- [x] Pro purchase flow — one-time non-consumable `pro_unlock` via in_app_purchase, price shown from Play, calls ProService.setPro(true)
- [x] Restore purchases (with a "nothing found" message)
- [ ] Create the `pro_unlock` product in Play Console + license testers (see PLAY_CONSOLE_SETUP.md)
- [ ] Pro extras promised in the original spec (custom colors, logo, SVG/HD export) — NOT built; don't advertise them until they are
- [x] Theme selector (System / Light / Dark) — persisted, applies live app-wide
- [x] Auto-save toggle — persisted AND actually drives Scan behavior (auto-saves each detected code to History when on)
- [x] Privacy Policy link — now points at a named placeholder (YOUR_GITHUB_USERNAME...) instead of example.com; real policy drafted at docs/privacy-policy.html, hosting steps in docs/HOSTING.md — fill 3 placeholders in the HTML, enable GitHub Pages, then update the URL constant in settings_screen.dart
- [x] App version via package_info_plus
- [x] Contact support row (mailto) — placeholder address `support@example.com` still needs replacing

## Monetization / Compliance
- [x] AdMob SDK initialized only AFTER consent resolves (ad_service.dart) — uses Google TEST ad IDs
- [x] UMP consent flow implemented and gating ad requests (form shown only where required)
- [x] "Ad privacy settings" row in Settings, shown only where the region requires it
- [x] Single banner above the bottom nav on all 3 tabs; hidden for Pro, hidden until loaded, padded to reduce accidental taps
- [x] Pro flag (ProService) hides ads and lifts the 50-item history cap — purchase flow itself still TODO
- [x] AndroidManifest.xml provided directly in the scaffold (android/app/src/main/AndroidManifest.xml) — includes the AdMob App ID, camera permission + feature flag, INTERNET, and url_launcher package-visibility queries for Android 11+
- [ ] Create real AdMob account, real app ID + banner unit ID, then set AdService.useTestAds = false
- [x] Fixed: DropdownButtonFormField used `initialValue` (wrong, compile error) — corrected to `value` in Generate screen's WiFi encryption + barcode format dropdowns
- [x] Fixed: swapped `image_gallery_saver` (unmaintained, no Android namespace → fails Gradle build on AGP 8+) for `gal` (maintained, scoped-storage compliant)
- [ ] Data Safety form filled in Play Console, matches actual permissions/SDKs
- [x] Privacy Policy drafted (docs/privacy-policy.html) — accurate to actual data handling (camera local-only, AdMob + UMP consent, Play Billing, local-only history). Hosting is a 5-minute manual step (docs/HOSTING.md), not yet done
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

## Lessons from competitor review research

Sourced from real reviews on two popular Play Store QR/barcode scanner apps
(DOSA Apps' "QR scanner - Barcode reader", 10M+ downloads; Simple Design's
"QR Scanner: Barcode Scanner", 100M+ downloads). Each item below is a
complaint found in their actual reviews, with what it means for us.

- **"Ads only, could not scan and proceed"** — our banner ad is structurally
  separate from the Scan camera view (lives below the tab content in
  main.dart's Column, never inside ScanScreen's Stack) — this failure mode
  isn't architecturally possible here. No change needed, but worth knowing
  why it's safe.
- **App too slow to load when scanning under time pressure** (reviewer
  described missing a discount code at checkout) — worth testing our actual
  cold-start-to-first-detection time on a real device once building works;
  not yet measured.
- **[x] Ad overlapping the scan box / ad button same color + bigger than
  real buttons, described as "deceitful"** — added an explicit small "Advertisement"
  label above the banner (banner_ad_widget.dart). Structurally the ad was
  already isolated from any button; the label adds clarity on top of that.
- **[x] Scanned something, got nothing useful, had to search elsewhere** —
  added a "Search online" action on non-URL scan results (opens a browser
  search for the scanned text). Opt-in, only fires on tap, so it doesn't
  compromise offline-first — no network call unless the user asks for one.
- **[ ] Ad impersonating a subscription / "predatory free trial" charge**
  (likely a 3rd-party ad creative, not the app's own pricing, but the app
  still absorbed the bad reviews) — mitigation documented in
  PLAY_CONSOLE_SETUP.md: restrict AdMob's max ad content rating + blocking
  controls. Can't eliminate this risk, only reduce it.
- **[x] "Report an ad" path in-app** — added to Settings, separate from
  general "Contact support", with a pre-filled mailto subject/body prompting
  for a description/screenshot.
