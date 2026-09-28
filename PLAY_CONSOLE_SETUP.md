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
