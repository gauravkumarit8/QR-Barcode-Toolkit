import 'package:flutter_test/flutter_test.dart';
import 'package:qr_barcode_toolkit/utils/feedback_report.dart';

void main() {
  group('body', () {
    test('without details it is just the prompt', () {
      final b = FeedbackReport.body(
        appVersion: '1.0.0 (38)',
        phone: 'Android 14',
        errors: const ['secret error'],
        includeDetails: false,
      );
      expect(b, startsWith('Describe the problem'));
      expect(b, isNot(contains('Technical details')));
      expect(b, isNot(contains('secret error')));
      expect(b, isNot(contains('1.0.0')));
    });

    test('with details and no errors', () {
      final b = FeedbackReport.body(
        appVersion: '1.0.0 (38)',
        phone: 'Android 14',
        errors: const [],
        includeDetails: true,
      );
      expect(b, contains('App version: 1.0.0 (38)'));
      expect(b, contains('Phone: Android 14'));
      expect(b, contains('Recent errors: none'));
    });

    test('with details and errors', () {
      final b = FeedbackReport.body(
        appVersion: 'v',
        phone: 'p',
        errors: const ['err one', 'err two'],
        includeDetails: true,
      );
      expect(b, contains('Recent errors:'));
      expect(b, contains('err one'));
      expect(b, contains('err two'));
    });

    test('a very long report is cut', () {
      final b = FeedbackReport.body(
        appVersion: 'v',
        phone: 'p',
        errors: [for (var i = 0; i < 50; i++) 'e' * 200],
        includeDetails: true,
      );
      expect(b.length, FeedbackReport.maxBodyChars + 1);
      expect(b, endsWith('…'));
    });
  });

  group('mailto', () {
    test('subject and body survive encoding', () {
      const body = 'Line 1\nLine 2 & more # tags\n100% sure, caf\u00e9';
      final uri = FeedbackReport.mailto(
        to: 'help@example.com',
        subject: 'QR Barcode Toolkit \u2014 Support',
        body: body,
      );
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'help@example.com');
      expect(uri.queryParameters['subject'], 'QR Barcode Toolkit \u2014 Support');
      expect(uri.queryParameters['body'], body);
    });
  });
}
