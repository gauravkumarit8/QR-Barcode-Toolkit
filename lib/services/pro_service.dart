import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the user has Pro (ads removed, unlimited history).
///
/// For now this is just a persisted flag. When the in-app purchase flow is
/// built, the purchase/restore code should call [setPro] — nothing else in
/// the app needs to change, since ads and the history cap already read
/// [isPro].
class ProService {
  static const _key = 'is_pro_v1';

  static final ValueNotifier<bool> isPro = ValueNotifier(false);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isPro.value = prefs.getBool(_key) ?? false;
  }

  static Future<void> setPro(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    isPro.value = value;
  }
}
