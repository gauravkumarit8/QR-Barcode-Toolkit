/// Wraps Google Mobile Ads (AdMob) initialization and banner loading.
///
/// IMPORTANT (Play Store / GDPR / US privacy law compliance):
/// The UMP (User Messaging Platform) consent flow MUST run and be resolved
/// BEFORE requesting any ads for EEA/UK/California users. Do not call
/// MobileAds.instance.initialize() or load a banner until consent has been
/// gathered — wire this up before shipping any monetized build.
class AdService {
  // TODO:
  // 1. Initialize ConsentInformation / ConsentForm (google_mobile_ads UMP APIs)
  // 2. Only after consent resolved -> MobileAds.instance.initialize()
  // 3. Expose a loadBannerAd() used by Scan/Generate/History screens
  // 4. Gate ad display entirely off if user has purchased Pro
}
