import 'package:flutter_test/flutter_test.dart';
import 'package:qr_barcode_toolkit/utils/scan_content.dart';

void main() {
  group('ScanContent.parse — links and plain text', () {
    test('https link', () {
      final c = ScanContent.parse('https://example.com/a?b=1');
      expect(c.kind, ScanKind.url);
      expect(c.uri!.host, 'example.com');
    });

    test('surrounding whitespace is ignored but raw is preserved', () {
      const raw = '  https://example.com  ';
      final c = ScanContent.parse(raw);
      expect(c.kind, ScanKind.url);
      expect(c.raw, raw);
    });

    test('non-web schemes are plain text, never links', () {
      expect(ScanContent.parse('javascript:alert(1)').kind, ScanKind.text);
      expect(ScanContent.parse('file:///etc/passwd').kind, ScanKind.text);
    });

    test('ordinary text', () {
      expect(ScanContent.parse('hello world').kind, ScanKind.text);
    });
  });

  group('ScanContent.parse — contact-style codes', () {
    test('tel', () {
      final c = ScanContent.parse('tel:+911234567890');
      expect(c.kind, ScanKind.phone);
      expect(c.uri!.scheme, 'tel');
    });

    test('mailto and a bare email address', () {
      expect(ScanContent.parse('mailto:a@b.com').kind, ScanKind.email);
      final bare = ScanContent.parse('a@b.com');
      expect(bare.kind, ScanKind.email);
      expect(bare.uri!.scheme, 'mailto');
    });

    test('SMSTO format becomes an sms uri', () {
      final c = ScanContent.parse('SMSTO:+123:Hi there');
      expect(c.kind, ScanKind.sms);
      expect(c.uri!.scheme, 'sms');
    });

    test('geo', () {
      expect(ScanContent.parse('geo:12.34,56.78').kind, ScanKind.geo);
    });
  });

  group('ScanContent.parse — Wi-Fi', () {
    test('reads ssid, password, security; handles escaped semicolon', () {
      final c = ScanContent.parse(r'WIFI:T:WPA;S:MyNet;P:pass\;word;H:false;;');
      expect(c.kind, ScanKind.wifi);
      expect(c.wifi!.ssid, 'MyNet');
      expect(c.wifi!.password, 'pass;word');
      expect(c.wifi!.security, 'WPA');
      expect(c.wifi!.hidden, isFalse);
      expect(c.wifi!.hasPassword, isTrue);
    });

    test('open network', () {
      final c = ScanContent.parse('WIFI:T:nopass;S:Cafe;;');
      expect(c.kind, ScanKind.wifi);
      expect(c.wifi!.hasPassword, isFalse);
    });

    test('without an ssid it is not treated as Wi-Fi', () {
      expect(ScanContent.parse('WIFI:T:WPA;P:x;;').kind, ScanKind.text);
    });
  });

  group('ScanContent.parse — products', () {
    test('numeric product barcode only when the caller says it is one', () {
      expect(ScanContent.parse('8901234567890', isProductBarcode: true).kind,
          ScanKind.product);
      expect(ScanContent.parse('8901234567890').kind, ScanKind.text);
    });
  });

  group('ScanContent.parse — UPI payments', () {
    test('pay link with all fields', () {
      final c = ScanContent.parse(
        'upi://pay?pa=shop@bank&pn=Shop%20Name&am=499.00&cu=INR&tn=Order',
      );
      expect(c.kind, ScanKind.payment);
      final p = c.payment!;
      expect(p.scheme, 'upi');
      expect(p.payeeId, 'shop@bank');
      expect(p.payeeName, 'Shop Name');
      expect(p.amount, '499.00');
      expect(p.currency, 'INR');
      expect(p.note, 'Order');
      expect(p.isCollectRequest, isFalse);
      expect(p.amountLabel, '\u20B9499.00');
      expect(c.uri, isNotNull);
    });

    test('scheme is case-insensitive', () {
      expect(ScanContent.parse('UPI://pay?pa=a@b').kind, ScanKind.payment);
    });

    test('collect request is flagged and the warning says so', () {
      final c = ScanContent.parse('upi://collect?pa=a@b&pn=X');
      expect(c.kind, ScanKind.payment);
      expect(c.payment!.isCollectRequest, isTrue);
      expect(c.payment!.warning, startsWith('Someone is asking you to pay.'));
    });

    test('a malformed amount is ignored, not trusted', () {
      final p = ScanContent.parse('upi://pay?pa=a@b&am=abc').payment!;
      expect(p.amount, isNull);
      expect(p.amountLabel, isNull);
    });

    test('currency defaults to INR when missing', () {
      expect(ScanContent.parse('upi://pay?pa=a@b').payment!.currency, 'INR');
    });

    test('unknown upi action is not a payment', () {
      expect(ScanContent.parse('upi://mandate?pa=a@b').kind, ScanKind.text);
    });
  });

  group('ScanContent.parse — EMVCo merchant QR', () {
    // Tags: 00=01, 01=11, 53=356 (INR), 54=100.00, 58=IN, 59=Shop, 60=Delhi, 63=CRC.
    const emv = '00020101021153033565406100.005802IN5904Shop6005Delhi6304ABCD';

    test('reads merchant, city, amount and currency', () {
      final c = ScanContent.parse(emv);
      expect(c.kind, ScanKind.payment);
      final p = c.payment!;
      expect(p.scheme, 'emv');
      expect(p.payeeName, 'Shop');
      expect(p.place, 'Delhi');
      expect(p.amount, '100.00');
      expect(p.currency, 'INR');
      expect(p.amountLabel, '\u20B9100.00');
      expect(c.uri, isNull);
    });

    test('without merchant name or country it is not a payment', () {
      expect(ScanContent.parse('0002010102116304ABCD').kind, ScanKind.text);
    });

    test('without the CRC field it is not a payment', () {
      expect(
        ScanContent.parse('00020101021153033565802IN5904Shop').kind,
        ScanKind.text,
      );
    });
  });
}
