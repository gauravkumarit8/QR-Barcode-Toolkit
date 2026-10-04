# Play Console setup for the Pro purchase

The app code expects one product. Nothing works until it exists in Play Console.

1. **Create the app** in Play Console (package name must match `applicationId`).
2. **Monetize → Products → In-app products → Create product**
   - Product ID: `pro_unlock`  (must match `PurchaseService.proProductId` exactly)
   - Type: one-time (managed) product, NOT a subscription
   - Set name, description, price, then **Activate** it.
3. **Upload a signed build** (AAB) to at least the Internal testing track.
   Billing only works for apps that have been uploaded to Play; a sideloaded
   debug APK will show the buy button as "Unavailable".
4. **Add license testers**: Play Console → Settings → License testing. Add your
   Google account so test purchases are free and instantly refundable.
5. Install the app from the Internal testing link (not adb) and test:
   buy → Pro unlocks and ads disappear → uninstall/reinstall → Restore purchases.
6. No manual manifest edit is needed for billing; the plugin adds the
   `com.android.vending.BILLING` permission automatically.

Also decide your Pro copy honestly: the Settings text only promises what is
implemented today (ads removed, unlimited history). Don't advertise custom
colors / logo / SVG export in the store listing until they exist.

## Restrict ad content (do this — real complaint on competitor apps)

Reviews on both reference scanner apps describe ads that looked like a
real subscription offer or app button, leading to confused/angry users and
unexpected charges — almost certainly a third-party ad creative, not
something the app itself built, but the app still took the reputational
damage. AdMob lets you reduce this risk directly:

1. AdMob console → **Settings → Content settings** (or **Ad content rating**)
2. Set **maximum ad content rating** to the lowest tier (e.g. "G" / family
   content) — this blocks the more aggressive and scam-adjacent ad creatives
   that tend to cluster in higher-tolerance tiers.
3. AdMob console → **Blocking controls** → review and block categories like
   "Dating" or anything subscription/trial-trap adjacent if they appear.
4. If a bad ad does get reported (Settings → Feedback in-app, once that
   exists — see PROGRESS.md), block its advertiser from Blocking controls.

This doesn't eliminate the risk, but it's the main lever available and
costs nothing to set up.
