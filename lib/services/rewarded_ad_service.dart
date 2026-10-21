import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';
import 'pro_service.dart';

/// Loads one rewarded ad in the background so it is ready when the user
/// chooses "Watch a short ad to unlock". Rewarded ads only ever play when the
/// user asks for them, which is why they are the least intrusive format.
class RewardedAdService {
  /// True while a fresh ad is loaded and ready to show.
  static final ValueNotifier<bool> ready = ValueNotifier(false);

  static RewardedAd? _ad;
  static DateTime? _loadedAt;
  static bool _loading = false;
  static int _failures = 0;
  static Timer? _retryTimer;

  static const _maxRetries = 4;

  /// AdMob stops serving a cached rewarded ad after about an hour, so an ad
  /// older than this is treated as not available.
  static const _maxAge = Duration(minutes: 50);

  static bool get isAvailable {
    final loadedAt = _loadedAt;
    return _ad != null &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < _maxAge;
  }

  /// Safe to call any time; does nothing unless ads are ready, the user is
  /// not Pro, and no ad is already loaded or loading.
  static void preload() {
    if (_loading || isAvailable) return;
    if (!AdService.adsReady.value || ProService.isPro.value) return;

    _discard(); // drop a stale ad, if any
    _loading = true;
    RewardedAd.load(
      adUnitId: AdService.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _failures = 0;
          _ad = ad;
          _loadedAt = DateTime.now();
          ready.value = true;
        },
        onAdFailedToLoad: (error) {
          _loading = false;
          _failures++;
          ready.value = false;
          _scheduleRetry();
        },
      ),
    );
  }

  /// 30s, 60s, 120s, 240s, then stop. Another preload happens after each ad
  /// is shown, so one failed load never disables rewarded ads for good.
  static void _scheduleRetry() {
    if (_failures > _maxRetries) return;
    final seconds = math.min(30 * (1 << (_failures - 1)), 300);
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), preload);
  }

  static void _discard() {
    _ad?.dispose();
    _ad = null;
    _loadedAt = null;
    ready.value = false;
  }

  /// Shows the ad and returns true only if the user earned the reward
  /// (watched it to the end). Returns false if no ad is available, it failed
  /// to show, or the user closed it early.
  static Future<bool> showAndWait() async {
    final ad = _ad;
    if (ad == null || !isAvailable) {
      _discard();
      preload();
      return false;
    }
    // The ad is single use: take it out before showing.
    _ad = null;
    _loadedAt = null;
    ready.value = false;

    final done = Completer<bool>();
    var earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(earned);
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
        preload();
      },
    );

    try {
      await ad.show(onUserEarnedReward: (adWithoutView, reward) => earned = true);
    } catch (_) {
      ad.dispose();
      if (!done.isCompleted) done.complete(false);
      preload();
    }
    return done.future;
  }
}
