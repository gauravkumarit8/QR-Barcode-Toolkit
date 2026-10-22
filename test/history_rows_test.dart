import 'package:flutter_test/flutter_test.dart';
import 'package:qr_barcode_toolkit/models/history_item.dart';
import 'package:qr_barcode_toolkit/utils/history_rows.dart';

final _now = DateTime(2026, 11, 3, 15, 0); // a Tuesday

HistoryItem _item(int n, DateTime when) =>
    HistoryItem(id: 'id$n', type: 'scan', value: 'v$n', timestamp: when);

String _describe(HistoryRow r) => switch (r.kind) {
      HistoryRowKind.header => 'H:${r.label}',
      HistoryRowKind.item => 'i${r.itemIndex}',
      HistoryRowKind.ad => 'AD',
    };

void main() {
  group('dayLabel', () {
    test('today and yesterday, including late and early times', () {
      expect(HistoryRows.dayLabel(DateTime(2026, 11, 3, 0, 0), _now), 'Today');
      expect(HistoryRows.dayLabel(DateTime(2026, 11, 3, 23, 59), _now), 'Today');
      expect(HistoryRows.dayLabel(DateTime(2026, 11, 2, 0, 0), _now), 'Yesterday');
      expect(HistoryRows.dayLabel(DateTime(2026, 11, 2, 23, 59), _now), 'Yesterday');
    });

    test('earlier this year shows weekday and date', () {
      expect(HistoryRows.dayLabel(DateTime(2026, 11, 1, 8), _now), 'Sun, 1 Nov');
      expect(HistoryRows.dayLabel(DateTime(2026, 10, 15, 8), _now), 'Thu, 15 Oct');
    });

    test('a previous year shows the year', () {
      expect(HistoryRows.dayLabel(DateTime(2025, 12, 20, 8), _now), '20 Dec 2025');
    });

    test('a time in the future is shown by date, not as "Today"', () {
      expect(HistoryRows.dayLabel(DateTime(2026, 11, 5, 8), _now), 'Thu, 5 Nov');
    });
  });

  group('build — day headings', () {
    test('groups consecutive items by day', () {
      final items = [
        _item(0, DateTime(2026, 11, 3, 10)),
        _item(1, DateTime(2026, 11, 3, 9)),
        _item(2, DateTime(2026, 11, 2, 22)),
        _item(3, DateTime(2026, 11, 1, 8)),
        _item(4, DateTime(2026, 10, 15, 8)),
        _item(5, DateTime(2025, 12, 20, 8)),
      ];
      expect(
        HistoryRows.build(items, now: _now).map(_describe).toList(),
        [
          'H:Today', 'i0', 'i1',
          'H:Yesterday', 'i2',
          'H:Sun, 1 Nov', 'i3',
          'H:Thu, 15 Oct', 'i4',
          'H:20 Dec 2025', 'i5',
        ],
      );
    });

    test('an empty list has no rows', () {
      expect(HistoryRows.build(const [], now: _now), isEmpty);
    });
  });

  group('build — ads', () {
    List<HistoryItem> today(int n) => [
          for (var i = 0; i < n; i++)
            _item(i, DateTime(2026, 11, 3, 12).subtract(Duration(minutes: i))),
        ];

    test('no ads when switched off', () {
      final rows = HistoryRows.build(today(30), now: _now);
      expect(rows.any((r) => r.kind == HistoryRowKind.ad), isFalse);
    });

    test('no ad for a short list', () {
      final rows = HistoryRows.build(today(8), now: _now, showAds: true);
      expect(rows.any((r) => r.kind == HistoryRowKind.ad), isFalse);
    });

    test('the first ad needs a 9th item to come before', () {
      final rows = HistoryRows.build(today(9), now: _now, showAds: true);
      final tags = rows.map(_describe).toList();
      expect(tags.where((t) => t == 'AD').length, 1);
      expect(tags.indexOf('AD'), 9); // header + 8 items, then the ad
      expect(tags.last, 'i8');
    });

    test('two ads at most, after the 8th and 16th item', () {
      final rows = HistoryRows.build(today(40), now: _now, showAds: true);
      final adRows = [
        for (var i = 0; i < rows.length; i++)
          if (rows[i].kind == HistoryRowKind.ad) i,
      ];
      expect(adRows, [9, 18]);
    });

    test('an ad is never first or last', () {
      for (var n = 0; n <= 50; n++) {
        final rows = HistoryRows.build(today(n), now: _now, showAds: true);
        if (rows.isEmpty) continue;
        expect(rows.first.kind, isNot(HistoryRowKind.ad), reason: 'n=$n');
        expect(rows.last.kind, isNot(HistoryRowKind.ad), reason: 'n=$n');
      }
    });

    test('an ad lands before a new day heading, not between a heading and its item', () {
      final items = [
        ...today(8),
        _item(8, DateTime(2026, 11, 2, 12)), // the next day
      ];
      final tags = HistoryRows.build(items, now: _now, showAds: true).map(_describe).toList();
      expect(tags.sublist(tags.length - 3), ['AD', 'H:Yesterday', 'i8']);
    });

    test('every item appears exactly once, in order', () {
      final rows = HistoryRows.build(today(33), now: _now, showAds: true);
      final shown = [
        for (final r in rows)
          if (r.kind == HistoryRowKind.item) r.itemIndex,
      ];
      expect(shown, [for (var i = 0; i < 33; i++) i]);
    });
  });
}
