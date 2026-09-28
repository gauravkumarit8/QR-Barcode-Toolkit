import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'pro_service.dart';

/// One-time "Pro" unlock via Google Play Billing (non-consumable product).
///
/// The product ID below must exist in Play Console → Monetize → In-app
/// products, as a one-time (managed) product, with status Active.
///
/// Trade-off (deliberate, for a low-maintenance app): purchases are trusted
/// on-device with no server-side receipt verification. That means no backend
/// to run, at the cost of being easier to bypass on a rooted device.
class PurchaseService {
  static const proProductId = 'pro_unlock';

  static final ValueNotifier<ProductDetails?> product = ValueNotifier(null);
  static final ValueNotifier<bool> busy = ValueNotifier(false);

  /// One-shot user-facing message (the Settings screen shows it and clears it).
  static final ValueNotifier<String?> message = ValueNotifier(null);

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Call once at startup. The purchase stream MUST be listened to from app
  /// launch so purchases that complete later (pending payments, or ones made
  /// outside the app) are delivered and acknowledged.
  static void init() {
    _sub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (_) {
        busy.value = false;
        message.value = 'Purchase service error. Please try again.';
      },
    );
  }

  /// Fetches the product (and localized price) from Google Play.
  static Future<void> loadProduct() async {
    if (product.value != null) return;
    try {
      if (!await _iap.isAvailable()) return;
      final response = await _iap.queryProductDetails({proProductId});
      if (response.productDetails.isNotEmpty) {
        product.value = response.productDetails.first;
      }
    } catch (_) {
      // Leave product null; the UI shows the buy button as unavailable.
    }
  }

  static Future<void> buyPro() async {
    final details = product.value;
    if (details == null || busy.value) return;
    busy.value = true;
    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
      if (!started) busy.value = false;
    } catch (_) {
      busy.value = false;
      message.value = 'Could not start the purchase. Please try again.';
    }
  }

  static Future<void> restore() async {
    if (busy.value) return;
    busy.value = true;
    try {
      await _iap.restorePurchases();
      // Restored purchases arrive through the purchase stream. If none do,
      // tell the user instead of leaving them wondering.
      await Future.delayed(const Duration(seconds: 6));
      if (!ProService.isPro.value) {
        message.value = 'No previous Pro purchase found on this Google account.';
      }
    } catch (_) {
      message.value = 'Could not restore purchases. Please try again.';
    } finally {
      busy.value = false;
    }
  }

  static Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID == proProductId) {
        switch (p.status) {
          case PurchaseStatus.pending:
            busy.value = true;
            break;
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            await ProService.setPro(true);
            busy.value = false;
            message.value = 'Pro unlocked. Thank you!';
            break;
          case PurchaseStatus.error:
            busy.value = false;
            message.value = p.error?.message ?? 'Purchase failed.';
            break;
          case PurchaseStatus.canceled:
            busy.value = false;
            break;
        }
      }
      // Must be called for every finished purchase; on Android this
      // acknowledges it. Unacknowledged purchases are auto-refunded by
      // Google after 3 days.
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }
}
