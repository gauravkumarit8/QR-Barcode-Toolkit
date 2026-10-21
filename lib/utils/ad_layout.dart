import 'dart:math' as math;

/// Works out where native ads go inside a list of real items, so the list
/// builder can ask "is this row an ad, and if not, which item is it?".
///
/// Ads go between items only (never first, never last), at most [maxAds] per
/// list, and only once there are more than [every] items.
class AdLayout {
  /// How many ad rows a list of [itemCount] items gets.
  static int adSlots(int itemCount, {int every = 8, int maxAds = 2}) {
    if (itemCount <= every) return 0;
    return math.min(maxAds, (itemCount - 1) ~/ every);
  }

  /// Total rows: real items plus ad rows.
  static int totalCount(int itemCount, {int every = 8, int maxAds = 2}) =>
      itemCount + adSlots(itemCount, every: every, maxAds: maxAds);

  /// True when row [index] is an ad row.
  static bool isAdIndex(int index, int itemCount, {int every = 8, int maxAds = 2}) {
    final slots = adSlots(itemCount, every: every, maxAds: maxAds);
    if (slots == 0) return false;
    final group = every + 1;
    return index % group == every && index ~/ group < slots;
  }

  /// For a row that is not an ad, the index of the real item it shows.
  static int itemIndex(int index, int itemCount, {int every = 8, int maxAds = 2}) {
    final slots = adSlots(itemCount, every: every, maxAds: maxAds);
    final adsBefore = math.min(index ~/ (every + 1), slots);
    return index - adsBefore;
  }
}
