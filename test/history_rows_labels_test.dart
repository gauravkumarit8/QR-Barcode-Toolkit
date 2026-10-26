import 'package:flutter_test/flutter_test.dart';
import 'package:qr_barcode_toolkit/models/history_item.dart';
import 'package:qr_barcode_toolkit/utils/history_rows.dart';

const _es = DayLabels(
  today: 'Hoy',
  yesterday: 'Ayer',
  weekdays: ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'],
  months: ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'],
);

void main() {
  final now = DateTime(2026, 11, 3, 15, 0);

  test('translated words are used in day labels', () {
    expect(HistoryRows.dayLabel(DateTime(2026, 11, 3, 9), now, labels: _es), 'Hoy');
    expect(HistoryRows.dayLabel(DateTime(2026, 11, 2, 9), now, labels: _es), 'Ayer');
    expect(HistoryRows.dayLabel(DateTime(2026, 11, 1, 8), now, labels: _es), 'dom, 1 nov');
    expect(HistoryRows.dayLabel(DateTime(2025, 12, 20, 8), now, labels: _es), '20 dic 2025');
  });

  test('lists of the wrong size fall back to English words', () {
    const bad = DayLabels(weekdays: ['a'], months: ['b']);
    expect(HistoryRows.dayLabel(DateTime(2026, 11, 1, 8), now, labels: bad), 'Sun, 1 Nov');
  });

  test('build uses the labels for the headings', () {
    final items = [
      HistoryItem(id: 'a', type: 'scan', value: 'x', timestamp: DateTime(2026, 11, 3, 10)),
      HistoryItem(id: 'b', type: 'scan', value: 'y', timestamp: DateTime(2026, 11, 2, 10)),
    ];
    final rows = HistoryRows.build(items, now: now, labels: _es);
    final headers = [
      for (final r in rows)
        if (r.kind == HistoryRowKind.header) r.label,
    ];
    expect(headers, ['Hoy', 'Ayer']);
  });
}
