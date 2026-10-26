import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_barcode_toolkit/l10n/strings_en.dart';
import 'package:qr_barcode_toolkit/l10n/translations.dart';

void main() {
  final placeholder = RegExp(r'\{(\w+)\}');
  Set<String> placeholdersOf(String s) =>
      placeholder.allMatches(s).map((m) => m.group(1)!).toSet();

  group('every language is complete and consistent with English', () {
    for (final code in Translations.languageCodes) {
      test(code, () {
        final table = Translations.table(code);
        expect(table.keys.toSet(), stringsEn.keys.toSet(), reason: 'keys differ in $code');
        for (final key in stringsEn.keys) {
          expect(table[key]!.trim(), isNotEmpty, reason: '$code / $key is empty');
          expect(
            placeholdersOf(table[key]!),
            placeholdersOf(stringsEn[key]!),
            reason: 'placeholders differ in $code / $key',
          );
        }
        expect(table['date.weekdays']!.split('|').length, 7, reason: '$code weekdays');
        expect(table['date.months']!.split('|').length, 12, reason: '$code months');
      });
    }

    test('every language has a name for the language picker', () {
      for (final code in Translations.languageCodes) {
        expect(Translations.languageNames[code], isNotNull, reason: code);
      }
    });
  });

  group('lookup', () {
    test('returns the text in the chosen language', () {
      expect(Translations.lookup('en', 'nav.scan'), 'Scan');
      expect(Translations.lookup('es', 'nav.scan'), 'Escanear');
      expect(Translations.lookup('de', 'nav.history'), 'Verlauf');
    });

    test('an unsupported language falls back to English', () {
      expect(Translations.lookup('xx', 'nav.scan'), 'Scan');
      expect(Translations.lookup('', 'nav.scan'), 'Scan');
    });

    test('an unknown key returns the key itself', () {
      expect(Translations.lookup('en', 'no.such.key'), 'no.such.key');
      expect(Translations.lookup('fr', 'no.such.key'), 'no.such.key');
    });

    test('placeholders are filled in', () {
      expect(
        Translations.lookup('en', 'settings.noEmailApp', {'email': 'a@b.com'}),
        'No email app found. Write to a@b.com instead.',
      );
      expect(
        Translations.lookup('es', 'settings.noEmailApp', {'email': 'a@b.com'}),
        contains('a@b.com'),
      );
      expect(
        Translations.lookup('en', 'history.minutesAgo', {'n': 5}),
        '5m ago',
      );
    });
  });

  group('resolve', () {
    test('supported, unsupported and missing codes', () {
      expect(Translations.resolve('es'), 'es');
      expect(Translations.resolve('hi'), 'hi');
      expect(Translations.resolve('xx'), 'en');
      expect(Translations.resolve(null), 'en');
    });
  });

  test('every text key used in the app exists in English', () {
    final used = <String>{};
    final pattern = RegExp(r"""\.t\(\s*'([\w.]+)'""");
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.contains('l10n')) {
        for (final m in pattern.allMatches(entity.readAsStringSync())) {
          used.add(m.group(1)!);
        }
      }
    }
    expect(used, isNotEmpty);
    final missing = used.where((k) => !Translations.has(k)).toList()..sort();
    expect(missing, isEmpty, reason: 'used in code but missing from strings_en.dart: $missing');
  });
}
