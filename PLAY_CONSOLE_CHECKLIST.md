# Play Console submission — exact answers

Fill these in order. Everything here matches what the app actually does and
what docs/privacy-policy.html discloses — don't improvise different answers
in the console, since a mismatch between your Data Safety form and your
privacy policy is a common rejection reason.

## 1. App access
"All functionality is available without special access" → **Yes**.
No login, no account, nothing gated. Select this and skip the rest of that section.

## 2. Ads
"Does your app contain ads?" → **Yes**.
It's a banner ad via AdMob, shown to free-tier users only.

## 3. Content rating questionnaire
Category: **Utility, Productivity, Communication, or Other** (pick "Utility" or
"Tools" if offered — matches the app's actual function).
Answer every content question (violence, sexual content, gambling, etc.) **No**
— this app has none of that. Expect a rating of "Everyone" / "3+" / "PEGI 3"
depending on region.

## 4. Target audience and content
- Target age group: **select the broad adult/general range, NOT "13 and
  under" or a children-specific range** — this app is not designed for
  or directed at children.
- "Is your app designed to be appealing to children?" → **No**.
- This matters for ads too: it determines whether you must treat ad
  requests as child-directed (you should answer this honestly based on
  who the app is actually for, not who might use it).

## 5. Data Safety form
Walk through each category Play asks about:

| Category | Collected? | Shared? | Notes |
|---|---|---|---|
| Location | No | No | App never requests location permission |
| Personal info (name, email, etc.) | No | No | No account/login exists |
| Financial info | No | No | Play Billing handles purchases; app never sees payment details |
| Photos/videos | No* | No | Camera is used live for scanning only — frames aren't saved or uploaded. Gallery picker only reads a photo the user explicitly chooses, to decode on-device; never stored/transmitted |
| App activity | **Yes** (device/advertising ID only, via AdMob) | **Yes** (with Google, for ad serving) | Declare this under "App info and performance" / "Device or other IDs" per AdMob's own disclosure requirements |
| Device or other IDs | **Yes** | **Yes** | Same as above — AdMob SDK |

Purpose for the "App activity"/"Device IDs" collection: **Advertising or marketing**.
Is data encrypted in transit? **Yes** (standard for Play Billing + AdMob SDKs).
Can users request data deletion? **Yes** — say "uninstalling the app removes
all locally stored data; no account or server-side data exists to delete."

*If Play's questionnaire doesn't have a clean way to say "camera used but
nothing stored," select "No" for Photos/videos collection and let the
Camera permission disclosure (declared separately, automatically, from your
manifest) cover the camera usage itself.

## 6. Store listing copy

**App name:** QR & Barcode Toolkit

**Short description** (max 80 characters):
```
Fast offline QR code & barcode scanner, generator, and history — no account.
```
(78 characters)

**Full description** (max 4000 characters) — draft, edit freely:
```
QR & Barcode Toolkit is a fast, simple scanner and generator that works
entirely offline — no account, no login, no data collection beyond
standard ad serving.

SCAN
• Instant camera scanning for QR codes and all common barcode formats
• Scan from your photo gallery instead of the live camera
• Auto zoom helps catch small or far-away codes
• Flashlight and camera flip for low light or hard angles
• Compare prices for scanned product barcodes
• A quick safety check warns you before opening suspicious links

GENERATE
• Create QR codes for plain text, URLs, phone numbers, and WiFi networks
  (scan to join a network automatically)
• Generate standard barcodes: Code128, EAN-13, UPC-A, Code39, ITF
• Save as an image or share directly

HISTORY
• Every scan and generated code saved locally on your device
• Search your history, mark favorites, or re-generate a past code
• Nothing leaves your device — no account, no cloud sync, no server

PRIVACY
• Camera access is used only for live scanning — frames are never saved
  or uploaded
• No location tracking, no account required
• One-time Pro upgrade removes ads and the free history limit — no
  subscription, no recurring charges

Free with ads. Upgrade to Pro once, anytime, to remove them.
```

**Category:** Tools (or Productivity)

**Contact email / website:** your real support email (same one used
elsewhere in the app)

## 7. Graphics
- **App icon**: `store_assets/play_store_icon_512.png` (512×512, generated — ready to upload)
- **Screenshots**: `store_assets/screenshot_1_scan.png`, `screenshot_2_generate.png`,
  `screenshot_3_history.png` (1080×1920, generated mockups — good enough to
  unblock closed testing; swap in real device screenshots before any public/
  production release, since these are stylized approximations, not actual
  captures)
- **Feature graphic** (1024×500, required for the full store listing, not
  strictly for closed testing): not yet made — ask if you want one.

## 8. Privacy policy URL
Paste the GitHub Pages URL from docs/HOSTING.md once hosted.

## 9. Closed testing track setup
- Create an email list or Google Group of testers (even just your own
  alternate email works to start)
- Upload the signed .aab (not .apk) built after release signing is wired up
- Play review for closed testing is typically much faster than production
  review, but still budget a day or two for the first submission
