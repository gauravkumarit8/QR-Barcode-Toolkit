import 'package:flutter_test/flutter_test.dart';
import 'package:qr_barcode_toolkit/utils/contact_card.dart';
import 'package:qr_barcode_toolkit/utils/scan_content.dart';

const _vcard = 'BEGIN:VCARD\n'
    'VERSION:3.0\n'
    'N:Rao;Asha;;;\n'
    'FN:Asha Rao\n'
    'ORG:Acme Traders;Sales\n'
    'TITLE:Manager\n'
    'TEL;TYPE=CELL:+91 98765 43210\n'
    'TEL;TYPE=WORK:+91 33 1234 5678\n'
    'EMAIL;TYPE=INTERNET:asha@acme.example\n'
    'URL:https://acme.example\n'
    'ADR;TYPE=WORK:;;12 Park St;Kolkata;WB;700016;India\n'
    'NOTE:Met at expo\\, Hall 2\n'
    'END:VCARD';

const _event = 'BEGIN:VCALENDAR\n'
    'VERSION:2.0\n'
    'BEGIN:VEVENT\n'
    'SUMMARY:Team lunch\n'
    'DTSTART:20261121T130000Z\n'
    'DTEND:20261121T140000Z\n'
    'LOCATION:Park Street\\, Kolkata\n'
    'DESCRIPTION:Bring the report\n'
    'END:VEVENT\n'
    'END:VCALENDAR';

void main() {
  group('ContactInfo.parse — vCard', () {
    test('reads all the common fields', () {
      final c = ContactInfo.parse(_vcard)!;
      expect(c.name, 'Asha Rao');
      expect(c.organization, 'Acme Traders, Sales');
      expect(c.title, 'Manager');
      expect(c.phones, ['+91 98765 43210', '+91 33 1234 5678']);
      expect(c.emails, ['asha@acme.example']);
      expect(c.urls, ['https://acme.example']);
      expect(c.address, '12 Park St, Kolkata, WB, 700016, India');
      expect(c.note, 'Met at expo, Hall 2');
    });

    test('Windows line endings work too', () {
      final c = ContactInfo.parse(_vcard.replaceAll('\n', '\r\n'))!;
      expect(c.name, 'Asha Rao');
      expect(c.phones.length, 2);
    });

    test('a name is built from N when FN is missing', () {
      final c = ContactInfo.parse('BEGIN:VCARD\nN:Rao;Asha;;;\nTEL:123\nEND:VCARD')!;
      expect(c.name, 'Asha Rao');
    });

    test('folded lines are joined', () {
      final c = ContactInfo.parse('BEGIN:VCARD\nFN:Asha\nNOTE:Hello \n world\nEND:VCARD')!;
      expect(c.note, 'Hello world');
    });

    test('group prefixes and tel: prefixes are removed', () {
      final c = ContactInfo.parse(
        'BEGIN:VCARD\nFN:A B\nitem1.TEL;VALUE=uri:tel:+123\nEND:VCARD',
      )!;
      expect(c.phones, ['+123']);
    });

    test('no usable field means no contact', () {
      expect(ContactInfo.parse('BEGIN:VCARD\nVERSION:3.0\nEND:VCARD'), isNull);
      expect(ContactInfo.parse('hello'), isNull);
    });

    test('at most five phones are kept', () {
      final tels = [for (var i = 0; i < 9; i++) 'TEL:10$i'].join('\n');
      final c = ContactInfo.parse('BEGIN:VCARD\nFN:A B\n$tels\nEND:VCARD')!;
      expect(c.phones.length, ContactInfo.maxEntries);
    });
  });

  group('ContactInfo.parse — MECARD', () {
    test('reads fields, flips "Family,Given", handles escapes', () {
      final c = ContactInfo.parse(
        r'MECARD:N:Doe,John;TEL:+123456;TEL:+654321;EMAIL:j@x.com;ORG:Foo\;Bar;URL:https\://x.com;NOTE:hi;;',
      )!;
      expect(c.name, 'John Doe');
      expect(c.phones, ['+123456', '+654321']);
      expect(c.emails, ['j@x.com']);
      expect(c.organization, 'Foo;Bar');
      expect(c.urls, ['https://x.com']);
      expect(c.note, 'hi');
    });

    test('a name without a comma is used as is', () {
      expect(ContactInfo.parse('MECARD:N:Madonna;TEL:1;;')!.name, 'Madonna');
    });

    test('an empty MECARD is not a contact', () {
      expect(ContactInfo.parse('MECARD:;;'), isNull);
    });
  });

  group('ContactInfo.toVCard', () {
    test('writes a vCard 3.0 file', () {
      const c = ContactInfo(name: 'John Doe', phones: ['+123456'], emails: ['j@x.com']);
      final v = c.toVCard();
      expect(v, startsWith('BEGIN:VCARD\r\nVERSION:3.0\r\n'));
      expect(v, contains('FN:John Doe\r\n'));
      expect(v, contains('N:Doe;John;;;\r\n'));
      expect(v, contains('TEL:+123456\r\n'));
      expect(v, contains('EMAIL:j@x.com\r\n'));
      expect(v, endsWith('END:VCARD\r\n'));
    });

    test('what we write can be read back', () {
      final original = ContactInfo.parse(_vcard)!;
      final again = ContactInfo.parse(original.toVCard())!;
      expect(again.name, original.name);
      expect(again.organization, original.organization);
      expect(again.title, original.title);
      expect(again.phones, original.phones);
      expect(again.emails, original.emails);
      expect(again.urls, original.urls);
      expect(again.address, original.address);
      expect(again.note, original.note);
    });
  });

  group('EventInfo', () {
    test('reads a timed event', () {
      final e = EventInfo.parse(_event)!;
      expect(e.title, 'Team lunch');
      expect(e.start, DateTime.utc(2026, 11, 21, 13));
      expect(e.end, DateTime.utc(2026, 11, 21, 14));
      expect(e.allDay, isFalse);
      expect(e.location, 'Park Street, Kolkata');
      expect(e.description, 'Bring the report');
    });

    test('reads an all-day event', () {
      final e = EventInfo.parse(
        'BEGIN:VEVENT\nSUMMARY:Holiday\nDTSTART;VALUE=DATE:20261121\nEND:VEVENT',
      )!;
      expect(e.allDay, isTrue);
      expect(e.start, DateTime(2026, 11, 21));
      expect(e.whenLabel, '21 Nov 2026 (all day)');
    });

    test('whenLabel for a same-day event (local times)', () {
      final e = EventInfo.parse(
        'BEGIN:VEVENT\nSUMMARY:X\nDTSTART:20261121T130000\nDTEND:20261121T140000\nEND:VEVENT',
      )!;
      expect(e.whenLabel, '21 Nov 2026, 13:00 \u2013 14:00');
    });

    test('whenLabel across two days', () {
      final e = EventInfo.parse(
        'BEGIN:VEVENT\nSUMMARY:X\nDTSTART:20261121T230000\nDTEND:20261122T010000\nEND:VEVENT',
      )!;
      expect(e.whenLabel, '21 Nov 2026, 23:00 \u2013 22 Nov 2026, 01:00');
    });

    test('an event without a valid start is not an event', () {
      expect(EventInfo.parse('BEGIN:VEVENT\nSUMMARY:X\nEND:VEVENT'), isNull);
      expect(
        EventInfo.parse('BEGIN:VEVENT\nSUMMARY:X\nDTSTART:20261321T130000Z\nEND:VEVENT'),
        isNull,
      );
      expect(
        EventInfo.parse('BEGIN:VEVENT\nSUMMARY:X\nDTSTART:20261121T250000Z\nEND:VEVENT'),
        isNull,
      );
    });

    test('toIcs writes a calendar file and keeps the original times', () {
      final ics = EventInfo.parse(_event)!.toIcs(now: DateTime.utc(2026, 10, 21, 8, 5, 9));
      expect(ics, startsWith('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'));
      expect(ics, contains('DTSTAMP:20261021T080509Z\r\n'));
      expect(ics, contains('DTSTART:20261121T130000Z\r\n'));
      expect(ics, contains('DTEND:20261121T140000Z\r\n'));
      expect(ics, contains('SUMMARY:Team lunch\r\n'));
      expect(ics, contains('LOCATION:Park Street\\, Kolkata\r\n'));
      expect(ics, endsWith('END:VCALENDAR\r\n'));
    });

    test('what we write can be read back', () {
      final first = EventInfo.parse(_event)!;
      final again = EventInfo.parse(first.toIcs())!;
      expect(again.title, first.title);
      expect(again.start, first.start);
      expect(again.end, first.end);
      expect(again.location, first.location);
      expect(again.description, first.description);
    });
  });

  group('ScanContent recognises them', () {
    test('contact', () {
      final c = ScanContent.parse(_vcard);
      expect(c.kind, ScanKind.contact);
      expect(c.contact!.name, 'Asha Rao');
    });

    test('MECARD is a contact', () {
      expect(ScanContent.parse('MECARD:N:Doe,John;TEL:1;;').kind, ScanKind.contact);
    });

    test('event', () {
      final c = ScanContent.parse(_event);
      expect(c.kind, ScanKind.event);
      expect(c.event!.title, 'Team lunch');
    });

    test('an empty card or event stays plain text', () {
      expect(ScanContent.parse('BEGIN:VCARD\nEND:VCARD').kind, ScanKind.text);
      expect(ScanContent.parse('BEGIN:VEVENT\nEND:VEVENT').kind, ScanKind.text);
    });
  });
}
