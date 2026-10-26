import 'strings_en.dart';
import 'strings_es.dart';
import 'strings_pt.dart';
import 'strings_fr.dart';
import 'strings_de.dart';
import 'strings_id.dart';
import 'strings_hi.dart';

/// Looks up UI text by key for a language, with English as the fallback.
/// Pure Dart (no Flutter), so it can be unit tested.
///
/// How it behaves:
///  - an unknown language code uses English;
///  - a key missing from a language uses the English text;
///  - a key missing everywhere returns the key itself, so a mistake is visible
///    on screen instead of crashing.
/// Placeholders such as {email} are replaced from the `args` map.
class Translations {
  static const List<String> languageCodes = ['en', 'es', 'pt', 'fr', 'de', 'id', 'hi'];

  /// Each language written in its own language, for the language picker.
  static const Map<String, String> languageNames = {
    'en': 'English',
    'es': 'Español',
    'pt': 'Português (Brasil)',
    'fr': 'Français',
    'de': 'Deutsch',
    'id': 'Bahasa Indonesia',
    'hi': 'हिन्दी',
  };

  static const Map<String, Map<String, String>> _tables = {
    'en': stringsEn,
    'es': stringsEs,
    'pt': stringsPt,
    'fr': stringsFr,
    'de': stringsDe,
    'id': stringsId,
    'hi': stringsHi,
  };

  /// Returns [code] if it is a supported language, otherwise 'en'.
  static String resolve(String? code) =>
      (code != null && _tables.containsKey(code)) ? code : 'en';

  static bool has(String key) => stringsEn.containsKey(key);

  /// The full table of a language (used by tests).
  static Map<String, String> table(String code) => _tables[resolve(code)]!;

  static String lookup(String code, String key, [Map<String, Object?> args = const {}]) {
    final text = _tables[resolve(code)]![key] ?? stringsEn[key] ?? key;
    return _fill(text, args);
  }

  static String _fill(String text, Map<String, Object?> args) {
    if (args.isEmpty) return text;
    var out = text;
    args.forEach((name, value) {
      out = out.replaceAll('{$name}', '${value ?? ''}');
    });
    return out;
  }
}
