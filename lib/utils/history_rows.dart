import '../models/history_item.dart';

enum HistoryRowKind { header, item, ad }

/// One row of the History list: a day heading, a saved item, or an ad slot.
class HistoryRow {
  final HistoryRowKind kind;

  /// The heading text, for [HistoryRowKind.header].
  final String? label;

  /// Position in the items list, for [HistoryRowKind.item].
  final int? itemIndex;

  const HistoryRow._(this.kind, {this.label, this.itemIndex});
  const HistoryRow.header(String label) : this._(HistoryRowKind.header, label: label);
  const HistoryRow.item(int index) : this._(HistoryRowKind.item, itemIndex: index);
  const HistoryRow.ad() : this._(HistoryRowKind.ad);
}

/// Turns a newest-first list of history items into the rows the list shows:
/// a heading for each day ("Today", "Yesterday", "Sun, 1 Nov", ...), with an
/// optional native ad row between items.
///
/// Pure Dart so the grouping and ad placement can be unit tested.
class HistoryRows {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "Today", "Yesterday", "Sun, 1 Nov" (this year) or "20 Dec 2025".
  static String dayLabel(DateTime when, DateTime now) {
    final d = when.toLocal();
    final n = now.toLocal();
    // Compare calendar days with UTC dates so a daylight-saving change never
    // makes a day 23 or 25 hours long.
    final days = DateTime.utc(n.year, n.month, n.day)
        .difference(DateTime.utc(d.year, d.month, d.day))
        .inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    final base = '${d.day} ${_months[d.month - 1]}';
    if (d.year == n.year) return '${_weekdays[d.weekday - 1]}, $base';
    return '$base ${d.year}';
  }

  /// [items] must already be sorted newest first.
  ///
  /// With [showAds], an ad row goes in after every [adEvery] items, at most
  /// [maxAds] times. An ad is always followed by more content, so it is never
  /// the first or the last row.
  static List<HistoryRow> build(
    List<HistoryItem> items, {
    required DateTime now,
    bool showAds = false,
    int adEvery = 8,
    int maxAds = 2,
  }) {
    final rows = <HistoryRow>[];
    String? lastLabel;
    var itemsSinceAd = 0;
    var adsPlaced = 0;

    for (var i = 0; i < items.length; i++) {
      if (showAds && adsPlaced < maxAds && itemsSinceAd >= adEvery) {
        rows.add(const HistoryRow.ad());
        adsPlaced++;
        itemsSinceAd = 0;
      }
      final label = dayLabel(items[i].timestamp, now);
      if (label != lastLabel) {
        rows.add(HistoryRow.header(label));
        lastLabel = label;
      }
      rows.add(HistoryRow.item(i));
      itemsSinceAd++;
    }
    return rows;
  }
}
