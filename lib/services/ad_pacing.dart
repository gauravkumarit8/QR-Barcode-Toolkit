import 'package:shared_preferences/shared_preferences.dart';

/// Rules that keep ads from feeling pushy. The decisions are plain functions
/// so they can be unit tested; the small storage layer below only saves two
/// counters on the device (no accounts, no network).
///
/// - Passive ads (the banner and the native ad in History) stay off during
///   the very first launch, so a new user sees the app, not an ad.
/// - A user can unlock a Pro export by watching a rewarded ad only a few
///   times per day.
class AdPacing {
  /// Passive ads start from the 2nd app launch.
  static const int minLaunchesBeforePassiveAds = 2;

  /// Rewarded unlocks per calendar day (device local time).
  static const int rewardedDailyLimit = 5;

  static const _launchKey = 'ad_launch_count_v1';
  static const _rewardedDayKey = 'ad_rewarded_day_v1';
  static const _rewardedCountKey = 'ad_rewarded_count_v1';

  /// Launch count including the current one. Set by [loadAndCountLaunch].
  static int launches = 0;

  static bool passiveAdsAllowedFor(int launchCount) =>
      launchCount >= minLaunchesBeforePassiveAds;

  static bool get passiveAdsAllowed => passiveAdsAllowedFor(launches);

  /// `2026-10-21`-style key for the device's local day.
  static String dayKey(DateTime now) {
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// How many rewarded unlocks were used today. The saved counter only counts
  /// if it belongs to today; a new day starts again from zero.
  static int rewardedUsedToday({
    required String? savedDay,
    required int savedCount,
    required DateTime now,
  }) =>
      savedDay == dayKey(now) ? savedCount : 0;

  static bool rewardedAvailable({
    required String? savedDay,
    required int savedCount,
    required DateTime now,
    int limit = rewardedDailyLimit,
  }) =>
      rewardedUsedToday(savedDay: savedDay, savedCount: savedCount, now: now) < limit;

  // ----------------------------------------------------------------- storage

  /// Call once at startup, before the first screen is built.
  static Future<void> loadAndCountLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    launches = (prefs.getInt(_launchKey) ?? 0) + 1;
    await prefs.setInt(_launchKey, launches);
  }

  static Future<bool> canOfferRewarded() async {
    final prefs = await SharedPreferences.getInstance();
    return rewardedAvailable(
      savedDay: prefs.getString(_rewardedDayKey),
      savedCount: prefs.getInt(_rewardedCountKey) ?? 0,
      now: DateTime.now(),
    );
  }

  static Future<void> recordRewardedUse() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final used = rewardedUsedToday(
      savedDay: prefs.getString(_rewardedDayKey),
      savedCount: prefs.getInt(_rewardedCountKey) ?? 0,
      now: now,
    );
    await prefs.setString(_rewardedDayKey, dayKey(now));
    await prefs.setInt(_rewardedCountKey, used + 1);
  }
}
