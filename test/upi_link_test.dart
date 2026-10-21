import 'package:flutter_test/flutter_test.dart';
import 'package:qr_barcode_toolkit/utils/scan_content.dart';
import 'package:qr_barcode_toolkit/utils/upi_link.dart';

void main() {
  group('UpiLink.isValidVpa', () {
    test('accepts normal UPI IDs', () {
      for (final v in [
        'name@oksbi',
        'john.doe-1@ybl',
        'a_b@paytm',
        '9876543210@ybl',
        '  shop@okbank  ', // surrounding spaces are ignored
      ]) {
        expect(UpiLink.isValidVpa(v), isTrue, reason: v);
      }
    });

    test('rejects typos and incomplete IDs', () {
      for (final v in [
        '',
        'nobank',
        'name@',
        '@bank',
        'a@b', // bank handle too short
        'x@bank', // name part too short
        'two words@bank',
        'name@bank@extra',
        'na me@bank',
      ]) {
        expect(UpiLink.isValidVpa(v), isFalse, reason: v);
      }
    });
  });

  group('UpiLink.normalizeAmount', () {
    test('empty means "no amount"', () {
      expect(UpiLink.normalizeAmount(''), '');
      expect(UpiLink.normalizeAmount('   '), '');
    });

    test('valid amounts', () {
      expect(UpiLink.normalizeAmount('499'), '499');
      expect(UpiLink.normalizeAmount(' 499 '), '499');
      expect(UpiLink.normalizeAmount('10.5'), '10.5');
      expect(UpiLink.normalizeAmount('10.50'), '10.50');
      expect(UpiLink.normalizeAmount('10.'), '10'); // still typing
      expect(UpiLink.normalizeAmount('1234567.89'), '1234567.89');
    });

    test('invalid amounts', () {
      for (final v in ['0', '0.00', '1.234', 'abc', '-5', '1,000', '.5', '12345678']) {
        expect(UpiLink.normalizeAmount(v), isNull, reason: v);
      }
    });

    test('field error messages', () {
      expect(UpiLink.amountError(''), isNull);
      expect(UpiLink.amountError('499'), isNull);
      expect(UpiLink.amountError('abc'), isNotNull);
      expect(UpiLink.vpaError(''), isNull); // empty is not an error yet
      expect(UpiLink.vpaError('shop@okbank'), isNull);
      expect(UpiLink.vpaError('nobank'), isNotNull);
    });
  });

  group('UpiLink.build', () {
    test('minimal link', () {
      expect(UpiLink.build(vpa: 'shop@okbank'), 'upi://pay?pa=shop@okbank&cu=INR');
    });

    test('all fields, in a stable order, with the UPI ID readable', () {
      final link = UpiLink.build(
        vpa: 'shop@okbank',
        name: 'Shop Name',
        amount: '499',
        note: 'Order 42',
      );
      expect(
        link,
        'upi://pay?pa=shop@okbank&pn=Shop%20Name&am=499&cu=INR&tn=Order%2042',
      );
      expect(link, isNot(contains('%40')));
    });

    test('returns null for an invalid UPI ID or amount', () {
      expect(UpiLink.build(vpa: ''), isNull);
      expect(UpiLink.build(vpa: 'nobank'), isNull);
      expect(UpiLink.build(vpa: 'shop@okbank', amount: 'abc'), isNull);
      expect(UpiLink.build(vpa: 'shop@okbank', amount: '0'), isNull);
    });

    test('whitespace is tidied and a trailing dot in the amount is dropped', () {
      final link = UpiLink.build(
        vpa: ' shop@okbank ',
        name: '  Shop \n  Name ',
        amount: '10.',
      );
      expect(link, 'upi://pay?pa=shop@okbank&pn=Shop%20Name&am=10&cu=INR');
    });

    test('long name and note are cut to the limits', () {
      final link = UpiLink.build(
        vpa: 'shop@okbank',
        name: 'a' * 60,
        note: 'b' * 80,
      )!;
      final p = ScanContent.parse(link).payment!;
      expect(p.payeeName!.length, UpiLink.nameMax);
      expect(p.note!.length, UpiLink.noteMax);
    });
  });

  group('Round trip: generator output is read correctly by the scanner', () {
    test('special characters survive', () {
      final link = UpiLink.build(
        vpa: 'ravi.k@oksbi',
        name: 'Ravi & Sons',
        amount: '1250.50',
        note: 'Order #42 \u2013 thanks',
      )!;
      final c = ScanContent.parse(link);
      expect(c.kind, ScanKind.payment);
      final p = c.payment!;
      expect(p.scheme, 'upi');
      expect(p.payeeId, 'ravi.k@oksbi');
      expect(p.payeeName, 'Ravi & Sons');
      expect(p.amount, '1250.50');
      expect(p.currency, 'INR');
      expect(p.note, 'Order #42 \u2013 thanks');
      expect(p.isCollectRequest, isFalse);
    });

    test('a link with no amount scans as a payment with no amount', () {
      final p = ScanContent.parse(UpiLink.build(vpa: 'shop@okbank')!).payment!;
      expect(p.payeeId, 'shop@okbank');
      expect(p.amount, isNull);
      expect(p.amountLabel, isNull);
    });
  });
}
