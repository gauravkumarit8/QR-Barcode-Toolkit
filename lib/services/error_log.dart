import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the last few errors on the device, so that a tester or user can
/// choose to attach them to a support email. Nothing is sent anywhere by the
/// app itself: the entries only leave the phone if the user adds them to an
/// email and presses Send.
///
/// The formatting helpers are plain functions so they can be unit tested.
class ErrorLog {
  static const _key = 'error_log_v1';

  /// Only the newest errors are kept.
  static const int maxEntries = 5;

  /// Longest single entry, in characters.
  static const int maxChars = 700;

  /// Lines of stack trace kept per entry.
  static const int maxStackLines = 6;

  static String trimStack(String? stack, {int maxLines = maxStackLines}) {
    if (stack == null || stack.trim().isEmpty) return '';
    return stack.trim().split('\n').take(maxLines).join('\n');
  }

  /// One log entry: UTC time, where it came from, the error, a short stack.
  static String formatEntry({
    required DateTime time,
    required String source,
    required Object error,
    StackTrace? stack,
    int maxChars = ErrorLog.maxChars,
  }) {
    final head = '${time.toUtc().toIso8601String()} [$source] $error';
    final trace = trimStack(stack?.toString());
    final full = trace.isEmpty ? head : '$head\n$trace';
    return full.length <= maxChars ? full : '${full.substring(0, maxChars)}…';
  }

  /// Adds [entry] and keeps only the newest [max] entries.
  static List<String> withEntry(List<String> existing, String entry, {int max = maxEntries}) {
    final list = [...existing, entry];
    return list.length <= max ? list : list.sublist(list.length - max);
  }

  /// First line of an entry without its timestamp, used to spot an error
  /// that keeps repeating (for example one thrown on every frame).
  static String _signature(String entry) {
    final firstLine = entry.split('\n').first;
    final space = firstLine.indexOf(' ');
    return space == -1 ? firstLine : firstLine.substring(space + 1);
  }

  static bool isRepeat(String last, String next) => _signature(last) == _signature(next);

  // ----------------------------------------------------------------- storage

  /// Records an error. Never throws, so it is safe to call from an error
  /// handler.
  static Future<void> record(Object error, StackTrace? stack, {String source = 'app'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_key) ?? const <String>[];
      final entry = formatEntry(time: DateTime.now(), source: source, error: error, stack: stack);
      if (existing.isNotEmpty && isRepeat(existing.last, entry)) return;
      await prefs.setStringList(_key, withEntry(existing, entry));
    } catch (_) {
      // Logging must never cause a second failure.
    }
  }

  static Future<List<String>> recent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) ?? const <String>[];
    } catch (_) {
      return const <String>[];
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
