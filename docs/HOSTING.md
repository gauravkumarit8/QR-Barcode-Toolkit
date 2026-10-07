# Hosting (GitHub Pages) — landing page + privacy policy

docs/index.html (the app's landing page) and docs/privacy-policy.html are
both ready to go — placeholders are filled in (date, contact email).

## One-time setup
1. Push these files (commands given alongside this).
2. On GitHub: your repo → **Settings → Pages**.
3. Under "Build and deployment" → Source: **Deploy from a branch**.
4. Branch: **main**, folder: **/docs**. Save.
5. Wait ~1 minute. Live at:
   - Landing page: `https://gauravkumarit8.github.io/QR-Barcode-Toolkit/`
   - Privacy policy: `https://gauravkumarit8.github.io/QR-Barcode-Toolkit/privacy-policy.html`

Both URLs are already wired into the app (Settings → Privacy Policy /
Contact support) and into PLAY_CONSOLE_CHECKLIST.md — nothing else to update
once Pages is turned on.

## About the "Get it on Google Play" button
index.html links to:
`https://play.google.com/store/apps/details?id=com.grv.qr_barcode_toolkit`

This is built from the app's real, already-locked-in package name — not a
meaningless placeholder. It won't resolve to a real listing until the app
is actually published on Play, but once it is, this link works with no
edit needed. If you'd rather it point somewhere else until launch (e.g. a
"coming soon" page), search index.html for that URL and swap it.

## Editing later
Any edit to files under docs/ on main updates the live site automatically
within about a minute.
