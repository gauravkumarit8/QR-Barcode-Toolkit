import 'contact_card.dart';

/// Builds the text stored inside a generated QR code for each content type
/// (link, phone, email, SMS, location, contact card). Pure Dart so it can be
/// unit tested; the formats are the same ones `ScanContent.parse` reads back.
///
/// Every builder returns an empty string when the input is missing or not
/// valid, which the generator screen treats as "nothing to show yet".
class CodePayloads {
  static final RegExp _hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://');
  static final RegExp _knownSchemes =
      RegExp(r'^(mailto|tel|sms|smsto|geo|upi|wifi|market):', caseSensitive: false);

  /// Same pattern the scanner uses to recognise an email address.
  static final RegExp _email = RegExp(r'^[\w.+\-]+@[\w\-]+(\.[\w\-]+)+$');

  static final RegExp _latLng =
      RegExp(r'^(-?\d+(?:\.\d+)?)(?:\s*[,;]\s*|\s+)(-?\d+(?:\.\d+)?)$');

  // -------------------------------------------------------------------- link

  /// Adds `https://` when the link has no scheme, so "example.com" works
  /// (phones treat a bare "example.com" as plain text, not a link).
  static String normalizeUrl(String input) {
    final t = input.trim();
    if (t.isEmpty) return '';
    if (_hasScheme.hasMatch(t) || _knownSchemes.hasMatch(t)) return t;
    if (t.startsWith('//')) return 'https:$t';
    return 'https://$t';
  }

  // ------------------------------------------------------------------- phone

  /// Keeps digits and a leading "+". Returns '' for fewer than 3 digits.
  static String cleanPhone(String input) {
    final t = input.trim();
    final digits = t.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 3) return '';
    return t.startsWith('+') ? '+$digits' : digits;
  }

  static String tel(String input) {
    final n = cleanPhone(input);
    return n.isEmpty ? '' : 'tel:$n';
  }

  // ------------------------------------------------------------------- email

  static bool isValidEmail(String value) => _email.hasMatch(value.trim());

  /// Message for an email field, or null when it is empty or valid.
  static String? emailError(String value) {
    if (value.trim().isEmpty || isValidEmail(value)) return null;
    return 'Enter an email like name@example.com';
  }

  static String mailto({required String address, String subject = '', String body = ''}) {
    final a = address.trim();
    if (!isValidEmail(a)) return '';
    final params = <String>[
      if (subject.trim().isNotEmpty) 'subject=${Uri.encodeComponent(subject.trim())}',
      if (body.trim().isNotEmpty) 'body=${Uri.encodeComponent(body.trim())}',
    ];
    return params.isEmpty ? 'mailto:$a' : 'mailto:$a?${params.join('&')}';
  }

  // --------------------------------------------------------------------- sms

  /// "SMSTO:number:message", the format phones and the scanner both read.
  static String smsto({required String number, String message = ''}) {
    final n = cleanPhone(number);
    if (n.isEmpty) return '';
    final m = message.trim();
    return m.isEmpty ? 'SMSTO:$n' : 'SMSTO:$n:$m';
  }

  // ---------------------------------------------------------------- location

  /// Accepts "48.8584, 2.2945" (comma, semicolon or space between the two
  /// numbers, as copied from a maps app) and returns `geo:48.8584,2.2945`.
  static String geo(String input) {
    final m = _latLng.firstMatch(input.trim());
    if (m == null) return '';
    final lat = double.parse(m[1]!);
    final lng = double.parse(m[2]!);
    if (lat.abs() > 90 || lng.abs() > 180) return '';
    return 'geo:${_number(lat)},${_number(lng)}';
  }

  /// Message for a location field, or null when it is empty or valid.
  static String? locationError(String value) {
    if (value.trim().isEmpty || geo(value).isNotEmpty) return null;
    return 'Enter latitude and longitude, like 48.8584, 2.2945';
  }

  /// At most 6 decimals, without trailing zeros.
  static String _number(double n) {
    if (n == 0) return '0';
    final fixed = n.toStringAsFixed(6);
    return fixed.contains('.')
        ? fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : fixed;
  }

  // ----------------------------------------------------------------- contact

  /// A vCard for a contact. Needs at least a name, phone, email or
  /// organization. Returns '' if an email address is given but invalid.
  static String contactVCard({
    String name = '',
    String phone = '',
    String email = '',
    String organization = '',
    String website = '',
  }) {
    final n = name.trim();
    final org = organization.trim();
    final tel = cleanPhone(phone);
    final mail = email.trim();
    final url = normalizeUrl(website);
    if (mail.isNotEmpty && !isValidEmail(mail)) return '';
    if (n.isEmpty && org.isEmpty && tel.isEmpty && mail.isEmpty) return '';
    return ContactCard(
      name: n.isEmpty ? null : n,
      organization: org.isEmpty ? null : org,
      phones: tel.isEmpty ? const [] : [tel],
      emails: mail.isEmpty ? const [] : [mail],
      urls: url.isEmpty ? const [] : [url],
    ).toVCard();
  }
}
