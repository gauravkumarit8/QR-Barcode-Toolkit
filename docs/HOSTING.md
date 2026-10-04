# Hosting the Privacy Policy (free, via GitHub Pages)

This repo's `docs/privacy-policy.html` becomes a real public URL with zero
extra services — GitHub Pages serves files straight from your repo for free.

## One-time setup
1. Fill in the three placeholders in `docs/privacy-policy.html` first:
   - `<!-- REPLACE_DATE -->` — today's date
   - `<!-- REPLACE_DEVELOPER_NAME -->` — your name or company name
   - `<!-- REPLACE_SUPPORT_EMAIL -->` (appears twice) — your real support email
2. Commit and push (instructions below).
3. On GitHub: your repo → **Settings → Pages**.
4. Under "Build and deployment" → Source: **Deploy from a branch**.
5. Branch: **main**, folder: **/docs**. Save.
6. Wait ~1 minute, then your policy is live at:
   `https://<your-github-username>.github.io/<repo-name>/privacy-policy.html`

## Then update the app and Play Console
- Replace the placeholder URL in `lib/screens/settings_screen.dart`
  (search for `example.com`) with the real URL above.
- Paste the same URL into Play Console when you submit: App content →
  Privacy policy.

## Editing later
Any edit to `docs/privacy-policy.html` on `main` updates the live page
automatically within about a minute — no redeploy step needed.
