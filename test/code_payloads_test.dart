import 'package:flutter_test/flutter_test.dart';
import 'package:qr_barcode_toolkit/utils/code_payloads.dart';
import 'package:qr_barcode_toolkit/utils/scan_content.dart';

void main() {
  group('normalizeUrl', () {
    test('adds https:// when there is no scheme', () {
      expect(CodePayloads.normalizeUrl('example.com'), 'https://example.com');
      expect(CodePayloads.normalizeUrl('www.example.com/a?b=1'), 'https://www.example.com/a?b=1');
      expect(CodePayloads.normalizeUrl('localhost:3000/x'), 'https://localhost:3000/x');
      expect(CodePayloads.normalizeUrl('//example.com'), 'https://example.com');
    });

    test('keeps an existing scheme and trims spaces', () {
      expect(CodePayloads.normalizeUrl('  https://a.com  '), 'https://a.com');
      expect(CodePayloads.normalizeUrl('http://a.com'), 'http://a.com');
      expect(CodePayloads.normalizeUrl('ftp://files.example.com'), 'ftp://files.example.com');
      expect(CodePayloads.normalizeUrl('mailto:a@b.com'), 'mailto:a@b.com');
      expect(CodePayloads.normalizeUrl('tel:+123'), 'tel:+123');
    });

    test('empty stays empty', () {
      expect(CodePayloads.normalizeUrl(''), '');
      expect(CodePayloads.normalizeUrl('   '), '');
    });
  });

  group('phone', () {
    test('cleanPhone keeps digits and a leading plus', () {
      expect(CodePayloads.cleanPhone('+91 98765-43210'), '+919876543210');
      expect(CodePayloads.cleanPhone('(033) 1234 5678'), '03312345678');
      expect(CodePayloads.cleanPhone('+1 (555) 010-9999'), '+15550109999');
    });

    test('too short or not a number gives empty', () {
      expect(CodePayloads.cleanPhone('abc'), '');
      expect(CodePayloads.cleanPhone('12'), '');
      expect(CodePayloads.cleanPhone(''), '');
    });

    test('tel uri', () {
      expect(CodePayloads.tel('+91 98765 43210'), 'tel:+919876543210');
      expect(CodePayloads.tel('x'), '');
    });
  });

  group('email', () {
    test('plain address', () {
      expect(CodePayloads.mailto(address: 'a@b.com'), 'mailto:a@b.com');
      expect(CodePayloads.mailto(address: '  a@b.com '), 'mailto:a@b.com');
    });

    test('subject and body are encoded', () {
      expect(
        CodePayloads.mailto(address: 'a@b.com', subject: 'Hello there', body: 'Line1\nLine2'),
        'mailto:a@b.com?subject=Hello%20there&body=Line1%0ALine2',
      );
      expect(
        CodePayloads.mailto(address: 'a@b.com', subject: 'Only subject'),
        'mailto:a@b.com?subject=Only%20subject',
      );
    });

    test('invalid address gives empty, with a field message', () {
      expect(CodePayloads.mailto(address: 'nope'), '');
      expect(CodePayloads.emailError('nope'), isNotNull);
      expect(CodePayloads.emailError(''), isNull);
      expect(CodePayloads.emailError('a@b.com'), isNull);
    });
  });

  group('sms', () {
    test('number and message', () {
      expect(
        CodePayloads.smsto(number: '+91 98765 43210', message: 'Hi: there'),
        'SMSTO:+919876543210:Hi: there',
      );
    });

    test('number only', () {
      expect(CodePayloads.smsto(number: '+919876543210'), 'SMSTO:+919876543210');
    });

    test('bad number gives empty', () {
      expect(CodePayloads.smsto(number: 'abc', message: 'hi'), '');
    });
  });

  group('location', () {
    test('accepts comma, semicolon and space separators', () {
      expect(CodePayloads.geo('48.8584, 2.2945'), 'geo:48.8584,2.2945');
      expect(CodePayloads.geo('48.8584,2.2945'), 'geo:48.8584,2.2945');
      expect(CodePayloads.geo('48.8584 2.2945'), 'geo:48.8584,2.2945');
      expect(CodePayloads.geo('48.8584; 2.2945'), 'geo:48.8584,2.2945');
    });

    test('negative values and tidy numbers', () {
      expect(CodePayloads.geo('-33.8688,151.2093'), 'geo:-33.8688,151.2093');
      expect(CodePayloads.geo('12.50000,3'), 'geo:12.5,3');
      expect(CodePayloads.geo('0,0'), 'geo:0,0');
    });

    test('out of range or not numbers gives empty', () {
      expect(CodePayloads.geo('91,0'), '');
      expect(CodePayloads.geo('0,181'), '');
      expect(CodePayloads.geo('abc'), '');
      expect(CodePayloads.geo('45'), ''); // one number, no separator
      expect(CodePayloads.geo(''), '');
    });

    test('field message', () {
      expect(CodePayloads.locationError(''), isNull);
      expect(CodePayloads.locationError('48.8584, 2.2945'), isNull);
      expect(CodePayloads.locationError('hello'), isNotNull);
    });
  });

  group('contact', () {
    test('writes a vCard with every field', () {
      final v = CodePayloads.contactVCard(
        name: 'Asha Rao',
        phone: '+91 98765 43210',
        email: 'asha@acme.example',
        organization: 'Acme',
        website: 'acme.example',
      );
      expect(v, contains('FN:Asha Rao\r\n'));
      expect(v, contains('TEL:+919876543210\r\n'));
      expect(v, contains('EMAIL:asha@acme.example\r\n'));
      expect(v, contains('ORG:Acme\r\n'));
      expect(v, contains('URL:https://acme.example\r\n'));
    });

    test('needs something to put on the card', () {
      expect(CodePayloads.contactVCard(), '');
      expect(CodePayloads.contactVCard(website: 'acme.example'), '');
    });

    test('an invalid email gives empty rather than a wrong card', () {
      expect(CodePayloads.contactVCard(name: 'A B', email: 'nope'), '');
    });

    test('a card with only a phone number still works', () {
      expect(CodePayloads.contactVCard(phone: '+919876543210'), contains('TEL:+919876543210'));
    });
  });

  group('round trip: what we generate is what the scanner reads', () {
    test('phone', () {
      expect(ScanContent.parse(CodePayloads.tel('+91 98765 43210')).kind, ScanKind.phone);
    });

    test('email', () {
      final c = ScanContent.parse(
        CodePayloads.mailto(address: 'a@b.com', subject: 'Hi', body: 'Body'),
      );
      expect(c.kind, ScanKind.email);
      expect(c.uri!.path, 'a@b.com');
    });

    test('sms', () {
      final c = ScanContent.parse(CodePayloads.smsto(number: '+919876543210', message: 'Hello'));
      expect(c.kind, ScanKind.sms);
      expect(c.uri!.scheme, 'sms');
      expect(c.uri!.path, '+919876543210');
    });

    test('location', () {
      expect(ScanContent.parse(CodePayloads.geo('48.8584, 2.2945')).kind, ScanKind.geo);
    });

    test('link', () {
      final c = ScanContent.parse(CodePayloads.normalizeUrl('example.com/page'));
      expect(c.kind, ScanKind.url);
      expect(c.uri!.host, 'example.com');
    });

    test('contact', () {
      final c = ScanContent.parse(CodePayloads.contactVCard(
        name: 'Asha Rao',
        phone: '+91 98765 43210',
        email: 'asha@acme.example',
        organization: 'Acme',
        website: 'acme.example',
      ));
      expect(c.kind, ScanKind.contact);
      expect(c.contact!.name, 'Asha Rao');
      expect(c.contact!.phones, ['+919876543210']);
      expect(c.contact!.emails, ['asha@acme.example']);
      expect(c.contact!.organization, 'Acme');
      expect(c.contact!.urls, ['https://acme.example']);
    });
  });
}
