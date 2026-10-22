/// Reads contact cards (vCard and MECARD) and calendar events (iCalendar
/// VEVENT) out of scanned text, and writes them back out as a .vcf / .ics
/// file that the phone's Contacts and Calendar apps can import.
///
/// Pure Dart so it can be unit tested. Everything read from a code is
/// untrusted text: it is only ever displayed, never opened or run.

/// Splits [text] into lines and joins folded lines back together. A line that
/// starts with a space or tab continues the previous line.
List<String> _unfoldLines(String text) {
  final out = <String>[];
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  for (final line in normalized.split('\n')) {
    if (out.isNotEmpty && line.isNotEmpty && (line[0] == ' ' || line[0] == '\t')) {
      out[out.length - 1] = out.last + line.substring(1);
    } else {
      out.add(line);
    }
  }
  return out;
}

/// Splits [value] on [sep] (when given), skipping separators written as
/// `\;`, and removes backslash escapes (`\,` `\;` `\\` and `\n`).
List<String> _split(String value, String? sep) {
  final parts = <String>[];
  final buf = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final ch = value[i];
    if (ch == r'\' && i + 1 < value.length) {
      final next = value[i + 1];
      buf.write(next == 'n' || next == 'N' ? '\n' : next);
      i++;
    } else if (sep != null && ch == sep) {
      parts.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  parts.add(buf.toString());
  return parts;
}

String _unescape(String value) => _split(value, null).first;

String? _clean(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

String _escape(String s) => s
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\r\n', r'\n')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\n');

String _oneLine(String s) => s.replaceAll(RegExp(r'[\r\n]+'), ' ');

class ContactCard {
  /// Largest number of phones, emails and links kept from one card.
  static const int maxEntries = 5;

  final String? name;
  final String? organization;
  final String? title;
  final List<String> phones;
  final List<String> emails;
  final List<String> urls;
  final String? address;
  final String? note;

  const ContactCard({
    this.name,
    this.organization,
    this.title,
    this.phones = const [],
    this.emails = const [],
    this.urls = const [],
    this.address,
    this.note,
  });

  String get displayName =>
      name ??
      organization ??
      (phones.isNotEmpty ? phones.first : (emails.isNotEmpty ? emails.first : 'Contact'));

  /// Returns null unless [raw] is a vCard or MECARD with at least a name,
  /// organization, phone number or email address.
  static ContactCard? parse(String raw) {
    final text = raw.trim();
    final lower = text.toLowerCase();
    if (lower.startsWith('begin:vcard')) return _parseVCard(text);
    if (lower.startsWith('mecard:')) return _parseMeCard(text.substring(7));
    return null;
  }

  static ContactCard? _build({
    String? name,
    String? organization,
    String? title,
    required List<String> phones,
    required List<String> emails,
    required List<String> urls,
    String? address,
    String? note,
  }) {
    final p = phones.take(maxEntries).toList();
    final e = emails.take(maxEntries).toList();
    if (name == null && organization == null && p.isEmpty && e.isEmpty) return null;
    return ContactCard(
      name: name,
      organization: organization,
      title: title,
      phones: p,
      emails: e,
      urls: urls.take(maxEntries).toList(),
      address: address,
      note: note,
    );
  }

  static ContactCard? _parseVCard(String text) {
    String? fn, given, family, org, title, address, note;
    final phones = <String>[], emails = <String>[], urls = <String>[];

    for (final line in _unfoldLines(text)) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      final head = line.substring(0, colon);
      final value = line.substring(colon + 1);

      // Drop parameters (";TYPE=CELL") and group prefixes ("item1.TEL").
      final semi = head.indexOf(';');
      var prop = (semi == -1 ? head : head.substring(0, semi)).toUpperCase();
      final dot = prop.lastIndexOf('.');
      if (dot != -1) prop = prop.substring(dot + 1);

      switch (prop) {
        case 'FN':
          fn ??= _clean(_unescape(value));
        case 'N':
          final parts = _split(value, ';');
          family ??= _clean(parts.isNotEmpty ? parts[0] : null);
          given ??= _clean(parts.length > 1 ? parts[1] : null);
        case 'ORG':
          org ??= _clean(_split(value, ';').where((s) => s.trim().isNotEmpty).join(', '));
        case 'TITLE':
          title ??= _clean(_unescape(value));
        case 'TEL':
          final tel = _clean(_unescape(value).replaceFirst(RegExp('^tel:', caseSensitive: false), ''));
          if (tel != null) phones.add(_oneLine(tel));
        case 'EMAIL':
          final mail = _clean(_unescape(value));
          if (mail != null) emails.add(_oneLine(mail));
        case 'URL':
          final url = _clean(value);
          if (url != null) urls.add(_oneLine(url));
        case 'ADR':
          address ??= _clean(_split(value, ';').where((s) => s.trim().isNotEmpty).join(', '));
        case 'NOTE':
          note ??= _clean(_unescape(value));
      }
    }

    final name = fn ?? _clean('${given ?? ''} ${family ?? ''}');
    return _build(
      name: name,
      organization: org,
      title: title,
      phones: phones,
      emails: emails,
      urls: urls,
      address: address,
      note: note,
    );
  }

  static ContactCard? _parseMeCard(String body) {
    String? name, org, address, note;
    final phones = <String>[], emails = <String>[], urls = <String>[];

    for (final field in _split(body, ';')) {
      final colon = field.indexOf(':');
      if (colon <= 0) continue;
      final key = field.substring(0, colon).toUpperCase();
      final value = _clean(field.substring(colon + 1));
      if (value == null) continue;

      switch (key) {
        case 'N':
          // MECARD writes names as "Family,Given".
          final comma = value.indexOf(',');
          name ??= comma == -1
              ? value
              : _clean('${value.substring(comma + 1)} ${value.substring(0, comma)}');
        case 'TEL':
          phones.add(_oneLine(value));
        case 'EMAIL':
          emails.add(_oneLine(value));
        case 'URL':
          urls.add(_oneLine(value));
        case 'ORG':
          org ??= value;
        case 'ADR':
          address ??= value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).join(', ');
        case 'NOTE':
          note ??= value;
      }
    }

    return _build(
      name: name,
      organization: org,
      phones: phones,
      emails: emails,
      urls: urls,
      address: address,
      note: note,
    );
  }

  static (String, String) _splitName(String full) {
    final words = full.trim().split(RegExp(r'\s+'));
    if (words.length < 2) return (full.trim(), '');
    return (words.sublist(0, words.length - 1).join(' '), words.last);
  }

  /// A vCard 3.0 file body that Contacts apps can import.
  String toVCard() {
    final (given, family) = _splitName(displayName);
    final lines = <String>[
      'BEGIN:VCARD',
      'VERSION:3.0',
      'FN:${_escape(displayName)}',
      'N:${_escape(family)};${_escape(given)};;;',
      if (organization != null) 'ORG:${_escape(organization!)}',
      if (title != null) 'TITLE:${_escape(title!)}',
      for (final p in phones) 'TEL:${_oneLine(p)}',
      for (final e in emails) 'EMAIL:${_oneLine(e)}',
      for (final u in urls) 'URL:${_oneLine(u)}',
      if (address != null) 'ADR:;;${_escape(address!)};;;;',
      if (note != null) 'NOTE:${_escape(note!)}',
      'END:VCARD',
    ];
    return '${lines.join('\r\n')}\r\n';
  }
}

class EventInfo {
  final String? title;
  final DateTime start;
  final DateTime? end;
  final bool allDay;
  final String? location;
  final String? description;

  // The original DTSTART / DTEND lines, kept as written so time zones survive
  // the trip into the calendar app.
  final String _startLine;
  final String? _endLine;

  const EventInfo._({
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.location,
    required this.description,
    required String startLine,
    required String? endLine,
  })  : _startLine = startLine,
        _endLine = endLine;

  static final RegExp _icsDate =
      RegExp(r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$');

  /// Returns null unless [raw] holds a VEVENT with a valid start date.
  static EventInfo? parse(String raw) {
    String? title, location, description, startLine, endLine;
    DateTime? start, end;
    var allDay = false;
    var inEvent = false;

    for (final line in _unfoldLines(raw.trim())) {
      final upper = line.trim().toUpperCase();
      if (upper == 'BEGIN:VEVENT') {
        inEvent = true;
        continue;
      }
      if (upper == 'END:VEVENT') break;
      if (!inEvent) continue;

      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      final head = line.substring(0, colon);
      final value = line.substring(colon + 1);
      final semi = head.indexOf(';');
      final prop = (semi == -1 ? head : head.substring(0, semi)).toUpperCase();

      switch (prop) {
        case 'SUMMARY':
          title ??= _clean(_unescape(value));
        case 'LOCATION':
          location ??= _clean(_unescape(value));
        case 'DESCRIPTION':
          description ??= _clean(_unescape(value));
        case 'DTSTART':
          final startDate = _parseDate(value.trim());
          if (startDate != null && start == null) {
            start = startDate.$1;
            allDay = startDate.$2;
            startLine = line.trim();
          }
        case 'DTEND':
          final endDate = _parseDate(value.trim());
          if (endDate != null && end == null) {
            end = endDate.$1;
            endLine = line.trim();
          }
      }
    }

    if (start == null || startLine == null) return null;
    return EventInfo._(
      title: title,
      start: start,
      end: end,
      allDay: allDay,
      location: location,
      description: description,
      startLine: startLine,
      endLine: endLine,
    );
  }

  /// (date, isDateOnly), or null if [value] is not a valid iCalendar date.
  static (DateTime, bool)? _parseDate(String value) {
    final m = _icsDate.firstMatch(value);
    if (m == null) return null;
    final y = int.parse(m[1]!);
    final mo = int.parse(m[2]!);
    final d = int.parse(m[3]!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    if (m[4] == null) return (DateTime(y, mo, d), true);
    final h = int.parse(m[4]!);
    final mi = int.parse(m[5]!);
    final s = m[6] == null ? 0 : int.parse(m[6]!);
    if (h > 23 || mi > 59 || s > 59) return null;
    final utc = m[7] != null;
    return (utc ? DateTime.utc(y, mo, d, h, mi, s) : DateTime(y, mo, d, h, mi, s), false);
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Readable date and time, such as "21 Nov 2026, 13:00 – 14:00". Times
  /// ending in Z are shown in the phone's local time.
  String get whenLabel {
    final a = start.isUtc ? start.toLocal() : start;
    if (allDay) return '${_date(a)} (all day)';
    final e = end;
    if (e == null) return '${_date(a)}, ${_time(a)}';
    final b = e.isUtc ? e.toLocal() : e;
    final sameDay = a.year == b.year && a.month == b.month && a.day == b.day;
    return sameDay
        ? '${_date(a)}, ${_time(a)} \u2013 ${_time(b)}'
        : '${_date(a)}, ${_time(a)} \u2013 ${_date(b)}, ${_time(b)}';
  }

  static String _stamp(DateTime utc) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}${two(utc.day)}'
        'T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  /// An iCalendar file body that Calendar apps can import.
  String toIcs({DateTime? now}) {
    final stamp = _stamp((now ?? DateTime.now()).toUtc());
    final uid = '${'${title ?? ''}|$_startLine'.hashCode.abs()}@qr-barcode-toolkit';
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//QR Barcode Toolkit//EN',
      'BEGIN:VEVENT',
      'UID:$uid',
      'DTSTAMP:$stamp',
      _startLine,
      if (_endLine != null) _endLine!,
      'SUMMARY:${_escape(title ?? 'Event')}',
      if (location != null) 'LOCATION:${_escape(location!)}',
      if (description != null) 'DESCRIPTION:${_escape(description!)}',
      'END:VEVENT',
      'END:VCALENDAR',
    ];
    return '${lines.join('\r\n')}\r\n';
  }
}
