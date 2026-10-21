import 'package:flutter_test/flutter_test.dart';
import 'package:qr_barcode_toolkit/services/ad_pacing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('passive ads wait until the second launch', () {
    test('rule', () {
      expect(AdPacing.passiveAdsAllowedFor(0), isFalse);
      expect(AdPacing.passiveAdsAllowedFor(1), isFalse);
      expect(AdPacing.passiveAdsAllowedFor(2), isTrue);
      expect(AdPacing.passiveAdsAllowedFor(10), isTrue);
    });

    test('launch counter increments and persists', () async {
      SharedPreferences.setMockInitialValues({});
      await AdPacing.loadAndCountLaunch();
      expect(AdPacing.launches, 1);
      expect(AdPacing.passiveAdsAllowed, isFalse);
      await AdPacing.loadAndCountLaunch();
      expect(AdPacing.launches, 2);
      expect(AdPacing.passiveAdsAllowed, isTrue);
    });
  });

  group('rewarded daily limit', () {
    final today = DateTime(2026, 10, 21, 15, 30);

    test('dayKey is zero padded', () {
      expect(AdPacing.dayKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(AdPacing.dayKey(DateTime(2026, 12, 31, 23, 59)), '2026-12-31');
    });

    test('a counter from another day does not count', () {
      expect(
        AdPacing.rewardedUsedToday(savedDay: '2026-10-20', savedCount: 5, now: today),
        0,
      );
      expect(AdPacing.rewardedUsedToday(savedDay: null, savedCount: 3, now: today), 0);
    });

    test("today's counter counts", () {
      expect(
        AdPacing.rewardedUsedToday(savedDay: '2026-10-21', savedCount: 3, now: today),
        3,
      );
    });

    test('available below the limit, not at it', () {
      expect(
        AdPacing.rewardedAvailable(savedDay: '2026-10-21', savedCount: 4, now: today),
        isTrue,
      );
      expect(
        AdPacing.rewardedAvailable(
          savedDay: '2026-10-21',
          savedCount: AdPacing.rewardedDailyLimit,
          now: today,
        ),
        isFalse,
      );
    });

    test('storage: records uses and reaches the limit', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await AdPacing.canOfferRewarded(), isTrue);
      for (var i = 0; i < AdPacing.rewardedDailyLimit; i++) {
        expect(await AdPacing.canOfferRewarded(), isTrue, reason: 'use $i');
        await AdPacing.recordRewardedUse();
      }
      expect(await AdPacing.canOfferRewarded(), isFalse);
    });
  });
}
