import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/review_policy.dart';
import 'ad_pacing.dart';

/// Counts moments where the app clearly helped the user and, when
/// [ReviewPolicy] allows, shows Google's in-app rating sheet.
///
/// Call [recordPositiveAction] after something good has finished: a code saved
/// or shared, a file exported. It never waits for the user, never throws, and
/// does nothing on devices where the rating sheet is not available. Google
/// also limits how often the sheet may appear, so a request can be ignored.
class ReviewPrompt {
  static const _actionsKey = 'review_actions_v1';
  static const _askedKey = 'review_asked_count_v1';
  static const _lastAskedKey = 'review_last_asked_ms_v1';

  static bool _busy = false;

  static Future<void> recordPositiveAction() async {
    if (_busy) return;
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final actions = (prefs.getInt(_actionsKey) ?? 0) + 1;
      await prefs.setInt(_actionsKey, actions);

      final askedCount = prefs.getInt(_askedKey) ?? 0;
      final lastAsked = prefs.getInt(_lastAskedKey);
      final now = DateTime.now().millisecondsSinceEpoch;

      final ask = ReviewPolicy.shouldAsk(
        actions: actions,
        launches: AdPacing.launches,
        askedCount: askedCount,
        lastAskedMs: lastAsked,
        nowMs: now,
      );
      if (!ask) return;

      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;

      // Save first, so a crash or a closed sheet never causes a second ask.
      await prefs.setInt(_askedKey, askedCount + 1);
      await prefs.setInt(_lastAskedKey, now);
      await prefs.setInt(_actionsKey, 0);
      await review.requestReview();
    } catch (_) {
      // Ratings are optional; never let them affect the user's task.
    } finally {
      _busy = false;
    }
  }
}
