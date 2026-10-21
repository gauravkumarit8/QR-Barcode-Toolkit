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
  // Google's official Android test rewarded and native units.
  static const _testRewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const _testNativeUnitId = 'ca-app-pub-3940256099942544/2247696110';
  // TODO: replace with your real banner ad unit ID from the AdMob console.
  static const _prodBannerUnitId = 'REPLACE_WITH_YOUR_BANNER_AD_UNIT_ID';
  // TODO: create a Rewarded ad unit and a Native ad unit in AdMob, then paste
  // their IDs here before setting useTestAds to false.
  static const _prodRewardedUnitId = 'REPLACE_WITH_YOUR_REWARDED_AD_UNIT_ID';
  static const _prodNativeUnitId = 'REPLACE_WITH_YOUR_NATIVE_AD_UNIT_ID';

  static String get bannerUnitId =>
      useTestAds ? _testBannerUnitId : _prodBannerUnitId;

  static String get rewardedUnitId =>
      useTestAds ? _testRewardedUnitId : _prodRewardedUnitId;

  static String get nativeUnitId =>
      useTestAds ? _testNativeUnitId : _prodNativeUnitId;

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
