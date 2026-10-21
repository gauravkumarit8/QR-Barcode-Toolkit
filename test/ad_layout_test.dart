import 'package:flutter_test/flutter_test.dart';
import 'package:qr_barcode_toolkit/utils/ad_layout.dart';

void main() {
  group('AdLayout.adSlots', () {
    test('no ads for short lists', () {
      for (final n in [0, 1, 5, 8]) {
        expect(AdLayout.adSlots(n), 0, reason: 'n=$n');
        expect(AdLayout.totalCount(n), n, reason: 'n=$n');
      }
    });

    test('first ad appears once there are more than 8 items', () {
      expect(AdLayout.adSlots(9), 1);
      expect(AdLayout.totalCount(9), 10);
    });

    test('never more than two ads, however long the list', () {
      expect(AdLayout.adSlots(20), 2);
      expect(AdLayout.adSlots(500), 2);
    });

    test('maxAds and every can be changed', () {
      expect(AdLayout.adSlots(100, every: 10, maxAds: 5), 5);
      expect(AdLayout.adSlots(25, every: 10, maxAds: 5), 2);
    });
  });

  group('AdLayout row mapping', () {
    test('ads sit after the 8th and 16th real items', () {
      const n = 20;
      final adRows = [
        for (var i = 0; i < AdLayout.totalCount(n); i++)
          if (AdLayout.isAdIndex(i, n)) i,
      ];
      expect(adRows, [8, 17]);
    });

    test('an ad is never the first or the last row', () {
      for (var n = 0; n <= 80; n++) {
        final total = AdLayout.totalCount(n);
        if (total == 0) continue;
        expect(AdLayout.isAdIndex(0, n), isFalse, reason: 'n=$n first');
        expect(AdLayout.isAdIndex(total - 1, n), isFalse, reason: 'n=$n last');
      }
    });

    test('every real item is shown exactly once, in order', () {
      for (var n = 0; n <= 80; n++) {
        final total = AdLayout.totalCount(n);
        final shown = <int>[];
        var ads = 0;
        for (var row = 0; row < total; row++) {
          if (AdLayout.isAdIndex(row, n)) {
            ads++;
          } else {
            shown.add(AdLayout.itemIndex(row, n));
          }
        }
        expect(shown, [for (var i = 0; i < n; i++) i], reason: 'n=$n');
        expect(ads, AdLayout.adSlots(n), reason: 'n=$n');
      }
    });
  });
}
