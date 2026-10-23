/// When it is polite to ask for a Play Store rating. Pure logic (no storage,
/// no plugin) so it can be unit tested; `ReviewPrompt` does the saving and
/// shows the system rating sheet.
///
/// The rules are deliberately cautious: only after the user has finished
/// something useful a few times, never in the first days, and not often.
class ReviewPolicy {
  /// Useful things done (a saved or shared code, an export) before asking.
  static const int minActions = 4;

  /// Times the app has been opened before asking.
  static const int minLaunches = 3;

  /// Never ask more than this many times in total.
  static const int maxAsks = 3;

  /// Minimum time between two asks.
  static const Duration minGap = Duration(days: 60);

  static bool shouldAsk({
    required int actions,
    required int launches,
    required int askedCount,
    required int? lastAskedMs,
    required int nowMs,
  }) {
    if (actions < minActions) return false;
    if (launches < minLaunches) return false;
    if (askedCount >= maxAsks) return false;
    if (lastAskedMs != null && nowMs - lastAskedMs < minGap.inMilliseconds) {
      return false;
    }
    return true;
  }
}
