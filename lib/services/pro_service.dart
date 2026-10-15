import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the user has Pro (ads removed, unlimited history, CSV and
/// print-quality export).
///
/// This is a persisted flag. The purchase and restore code calls [setPro];
/// nothing else in the app needs to change, since ads, the history cap and the
/// Pro-only exports all read [isPro].
class ProService {
  static const _key = 'is_pro_v1';

  /// Testing aid: `flutter run --dart-define=FORCE_PRO=true` unlocks Pro for
  /// that run only, so Pro features can be tried without buying anything. It
  /// is never saved, and builds made without the flag (including CI builds)
  /// are unaffected.
  static const bool _forcePro = bool.fromEnvironment('FORCE_PRO');

  static final ValueNotifier<bool> isPro = ValueNotifier(false);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isPro.value = _forcePro || (prefs.getBool(_key) ?? false);
  }

  static Future<void> setPro(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    isPro.value = value;
  }
}
