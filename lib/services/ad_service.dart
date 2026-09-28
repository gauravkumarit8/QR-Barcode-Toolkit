import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Wraps Google Mobile Ads (AdMob) initialization and consent.
///
/// Play Store / GDPR / US-state-privacy compliance:
/// the UMP (User Messaging Platform) consent flow runs FIRST. Ads are only
/// initialized and requested if UMP says [ConsentInformation.canRequestAds].
class AdService {
  /// KEEP TRUE until you have a real AdMob account and are making a release
  /// build. Clicking your own real ads can get an AdMob account banned.
  static const bool useTestAds = true;

  // Google's official Android test banner unit.
  static const _testBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';
  // TODO: replace with your real banner ad unit ID from the AdMob console.
  static const _prodBannerUnitId = 'REPLACE_WITH_YOUR_BANNER_AD_UNIT_ID';

  static String get bannerUnitId =>
      useTestAds ? _testBannerUnitId : _prodBannerUnitId;

  /// True once consent is resolved and the Mobile Ads SDK is initialized.
  static final ValueNotifier<bool> adsReady = ValueNotifier(false);

  static bool _started = false;

  /// Call once, after the first frame (the consent form needs an Activity).
  static Future<void> init() async {
    if (_started) return;
    _started = true;

    final consentDone = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        // Shows the consent form only if the user's region requires it.
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (!consentDone.isCompleted) consentDone.complete();
        });
      },
      (FormError error) {
        // Consent info failed to update (e.g. offline). Fall through and let
        // canRequestAds() decide based on any previously stored consent.
        if (!consentDone.isCompleted) consentDone.complete();
      },
    );

    await consentDone.future;

    if (await ConsentInformation.instance.canRequestAds()) {
      await MobileAds.instance.initialize();
      adsReady.value = true;
    }
  }

  /// Whether the app must offer a "Privacy settings" entry (required in
  /// some regions so users can change their consent choice later).
  static Future<bool> privacyOptionsRequired() async {
    final status =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  static void showPrivacyOptions() {
    ConsentForm.showPrivacyOptionsForm((FormError? error) {});
  }
}
