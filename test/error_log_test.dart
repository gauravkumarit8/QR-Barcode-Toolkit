import 'package:flutter_test/flutter_test.dart';
import 'package:qr_barcode_toolkit/services/error_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formatting', () {
    test('trimStack keeps only the first lines', () {
      final stack = [for (var i = 0; i < 10; i++) '#$i frame'].join('\n');
      final out = ErrorLog.trimStack(stack);
      expect(out.split('\n').length, ErrorLog.maxStackLines);
      expect(out, startsWith('#0 frame'));
    });

    test('trimStack handles null and empty', () {
      expect(ErrorLog.trimStack(null), '');
      expect(ErrorLog.trimStack('   '), '');
    });

    test('formatEntry has time, source and message', () {
      final e = ErrorLog.formatEntry(
        time: DateTime.utc(2026, 11, 2, 10, 11, 12),
        source: 'flutter',
        error: Exception('boom'),
      );
      expect(e, '2026-11-02T10:11:12.000Z [flutter] Exception: boom');
    });

    test('formatEntry adds a short stack and cuts long entries', () {
      final withStack = ErrorLog.formatEntry(
        time: DateTime.utc(2026, 1, 1),
        source: 'async',
        error: 'x',
        stack: StackTrace.fromString('#0 a\n#1 b'),
      );
      expect(withStack, endsWith('\n#0 a\n#1 b'));

      final long = ErrorLog.formatEntry(
        time: DateTime.utc(2026, 1, 1),
        source: 'async',
        error: 'y' * 2000,
      );
      expect(long.length, ErrorLog.maxChars + 1);
      expect(long, endsWith('…'));
    });

    test('withEntry keeps only the newest entries', () {
      var list = <String>[];
      for (var i = 0; i < 8; i++) {
        list = ErrorLog.withEntry(list, 'e$i');
      }
      expect(list, ['e3', 'e4', 'e5', 'e6', 'e7']);
    });

    test('isRepeat ignores the time but not the message', () {
      expect(
        ErrorLog.isRepeat('2026-01-01T00:00:00.000Z [a] same', '2026-01-02T00:00:00.000Z [a] same'),
        isTrue,
      );
      expect(
        ErrorLog.isRepeat('2026-01-01T00:00:00.000Z [a] one', '2026-01-01T00:00:00.000Z [a] two'),
        isFalse,
      );
    });
  });

  group('storage', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('records, repeats are skipped, and the log is capped', () async {
      await ErrorLog.record(Exception('first'), null, source: 't');
      await ErrorLog.record(Exception('first'), null, source: 't'); // repeat
      expect((await ErrorLog.recent()).length, 1);

      for (var i = 0; i < 8; i++) {
        await ErrorLog.record(Exception('err $i'), null, source: 't');
      }
      final all = await ErrorLog.recent();
      expect(all.length, ErrorLog.maxEntries);
      expect(all.last, contains('err 7'));
    });

    test('clear empties the log', () async {
      await ErrorLog.record(Exception('x'), null);
      await ErrorLog.clear();
      expect(await ErrorLog.recent(), isEmpty);
    });
  });
}
