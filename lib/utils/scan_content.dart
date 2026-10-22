import 'contact_card.dart';

/// What kind of thing a scanned code contains, so the result card can offer
/// the one action that makes sense (call, email, open a map, copy the Wi-Fi
/// password...) instead of a generic "Search online" for everything.
///
/// Pure Dart, no Flutter imports, so it is easy to unit test.
enum ScanKind { url, wifi, phone, email, sms, geo, product, payment, contact, event, text }

class WifiInfo {
  final String ssid;
  final String? password;
  final String security; // WPA, WEP, nopass...
  final bool hidden;

  const WifiInfo({
    required this.ssid,
    required this.password,
    required this.security,
    required this.hidden,
  });

  bool get hasPassword => password != null && password!.isNotEmpty;
}

/// Details read from a payment code: a UPI link (upi://pay?...) or an EMVCo
/// merchant QR (the standard behind BharatQR, Pix and many others).
///
/// Everything here is text taken from the code. The payee name in particular
/// is chosen by whoever made the code, so the UI always shows the payment ID
/// next to it and tells the user to check it.
class PaymentInfo {
  final String scheme; // 'upi' or 'emv'
  final String? payeeName;
  final String? payeeId; // UPI ID (VPA); UPI links only
  final String? place; // merchant city; EMV codes only
  final String? amount; // digits only, e.g. "499.00"
  final String? currency; // e.g. "INR"
  final String? note;
  final bool isCollectRequest;

  const PaymentInfo({
    required this.scheme,
    this.payeeName,
    this.payeeId,
    this.place,
    this.amount,
    this.currency,
    this.note,
    this.isCollectRequest = false,
  });

  /// "₹499.00", "25.00 BRL", or null when the code sets no amount.
  String? get amountLabel {
    final a = amount;
    if (a == null) return null;
    final c = currency;
    if (c == null) return a;
    return c == 'INR' ? '\u20B9$a' : '$a $c';
  }

  String get warning {
    const base = 'Entering your PIN in a payment app SENDS money from your '
        'account. You never need to scan a code to receive money.';
    if (isCollectRequest) return 'Someone is asking you to pay. $base';
    return 'This code is a payment request. $base';
  }
}

class ScanContent {
  final ScanKind kind;
  final String raw;

  /// Set for url / phone / email / sms / geo, and for UPI payment links.
  final Uri? uri;

  /// Set for wifi.
  final WifiInfo? wifi;

  /// Set for payment.
  final PaymentInfo? payment;

  /// Set for contact (vCard / MECARD).
  final ContactCard? contact;

  /// Set for event (calendar VEVENT).
  final EventInfo? event;

  const ScanContent._(
    this.kind,
    this.raw, {
    this.uri,
    this.wifi,
    this.payment,
    this.contact,
    this.event,
  });

  /// [isProductBarcode] should be true for numeric EAN/UPC retail barcodes —
  /// the caller knows the barcode format, this parser only sees the text.
  factory ScanContent.parse(String raw, {bool isProductBarcode = false}) {
    final value = raw.trim();
    final lower = value.toLowerCase();

    if (lower.startsWith('wifi:')) {
      final wifi = _parseWifi(value.substring(5));
      if (wifi != null) return ScanContent._(ScanKind.wifi, raw, wifi: wifi);
    }

    // Payment codes are checked early: they matter most to get right.
    if (lower.startsWith('upi:')) {
      final pay = _parseUpi(value);
      if (pay != null) {
        return ScanContent._(ScanKind.payment, raw, uri: Uri.tryParse(value), payment: pay);
      }
    }
    final emv = _parseEmv(value);
    if (emv != null) return ScanContent._(ScanKind.payment, raw, payment: emv);

    if (lower.startsWith('begin:vcard') || lower.startsWith('mecard:')) {
      final contact = ContactCard.parse(value);
      if (contact != null) return ScanContent._(ScanKind.contact, raw, contact: contact);
    }

    if (lower.startsWith('begin:vcalendar') || lower.startsWith('begin:vevent')) {
      final event = EventInfo.parse(value);
      if (event != null) return ScanContent._(ScanKind.event, raw, event: event);
    }

    if (lower.startsWith('tel:')) {
      final uri = Uri.tryParse(value);
      if (uri != null) return ScanContent._(ScanKind.phone, raw, uri: uri);
    }

    if (lower.startsWith('mailto:')) {
      final uri = Uri.tryParse(value);
      if (uri != null) return ScanContent._(ScanKind.email, raw, uri: uri);
    }

    if (_looksLikeEmail(value)) {
      return ScanContent._(
        ScanKind.email,
        raw,
        uri: Uri(scheme: 'mailto', path: value),
      );
    }

    if (lower.startsWith('smsto:') || lower.startsWith('sms:')) {
      final uri = _smsUri(value);
      if (uri != null) return ScanContent._(ScanKind.sms, raw, uri: uri);
    }

    if (lower.startsWith('geo:')) {
      final uri = Uri.tryParse(value);
      if (uri != null) return ScanContent._(ScanKind.geo, raw, uri: uri);
    }

    final uri = Uri.tryParse(value);
    if (uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return ScanContent._(ScanKind.url, raw, uri: uri);
    }

    if (isProductBarcode) return ScanContent._(ScanKind.product, raw);

    return ScanContent._(ScanKind.text, raw);
  }

  static bool _looksLikeEmail(String value) {
    return RegExp(r'^[\w.+\-]+@[\w\-]+(\.[\w\-]+)+$').hasMatch(value);
  }

  /// Handles both "sms:+123?body=Hi" and the common "SMSTO:+123:Hi" format.
  static Uri? _smsUri(String value) {
    final afterScheme = value.substring(value.indexOf(':') + 1);
    if (value.toLowerCase().startsWith('smsto:')) {
      final i = afterScheme.indexOf(':');
      final number = i == -1 ? afterScheme : afterScheme.substring(0, i);
      final body = i == -1 ? '' : afterScheme.substring(i + 1);
      if (number.isEmpty) return null;
      return Uri(
        scheme: 'sms',
        path: number,
        // Built by hand so spaces become %20 (Uri.queryParameters would use
        // '+', which some messaging apps show literally).
        query: body.isEmpty ? null : 'body=${Uri.encodeComponent(body)}',
      );
    }
    return Uri.tryParse(value);
  }

  /// Parses the part after "WIFI:" — e.g. `T:WPA;S:MyNet;P:pass\;word;H:false;;`
  /// Backslash escapes the next character (so `\;` is a literal semicolon).
  static WifiInfo? _parseWifi(String body) {
    final parts = <String>[];
    final buf = StringBuffer();
    for (var i = 0; i < body.length; i++) {
      final c = body[i];
      if (c == r'\' && i + 1 < body.length) {
        buf.write(body[i + 1]);
        i++;
      } else if (c == ';') {
        parts.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    if (buf.isNotEmpty) parts.add(buf.toString());

    final fields = <String, String>{};
    for (final part in parts) {
      final idx = part.indexOf(':');
      if (idx > 0) {
        fields[part.substring(0, idx).toUpperCase()] = part.substring(idx + 1);
      }
    }

    final ssid = fields['S'];
    if (ssid == null || ssid.isEmpty) return null;
    return WifiInfo(
      ssid: ssid,
      password: fields['P'],
      security: fields['T'] ?? 'nopass',
      hidden: (fields['H'] ?? '').toLowerCase() == 'true',
    );
  }

  // ----------------------------------------------------------------- payment

  static String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  /// Reads the query string by hand: Uri.parse is stricter than real-world QR
  /// codes (unescaped spaces, bad % sequences), and a payment code that fails
  /// to parse must still be recognised as a payment code.
  static Map<String, String> _query(String value) {
    final i = value.indexOf('?');
    if (i < 0) return const {};
    final out = <String, String>{};
    for (final part in value.substring(i + 1).split('&')) {
      if (part.isEmpty) continue;
      final eq = part.indexOf('=');
      final k = eq < 0 ? part : part.substring(0, eq);
      final v = eq < 0 ? '' : part.substring(eq + 1);
      try {
        out[Uri.decodeQueryComponent(k).toLowerCase()] = Uri.decodeQueryComponent(v);
      } catch (_) {
        out[k.toLowerCase()] = v;
      }
    }
    return out;
  }

  /// upi://pay?pa=shop@bank&pn=Shop%20Name&am=499.00&cu=INR&tn=Order
  static PaymentInfo? _parseUpi(String value) {
    final rest = value.substring(4).replaceFirst(RegExp(r'^/*'), ''); // after "upi:"
    final q = rest.indexOf('?');
    final action = (q < 0 ? rest : rest.substring(0, q)).toLowerCase();
    if (action != 'pay' && action != 'collect') return null;

    final params = _query(value);
    final amount = _clean(params['am']);
    return PaymentInfo(
      scheme: 'upi',
      payeeName: _clean(params['pn']),
      payeeId: _clean(params['pa']),
      amount: (amount != null && RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(amount)) ? amount : null,
      currency: _clean(params['cu'])?.toUpperCase() ?? 'INR',
      note: _clean(params['tn']),
      isCollectRequest: action == 'collect',
    );
  }

  static const _emvCurrencies = {
    '356': 'INR',
    '986': 'BRL',
    '840': 'USD',
    '978': 'EUR',
    '826': 'GBP',
    '702': 'SGD',
    '458': 'MYR',
    '764': 'THB',
    '360': 'IDR',
    '608': 'PHP',
    '784': 'AED',
    '682': 'SAR',
    '710': 'ZAR',
    '392': 'JPY',
    '156': 'CNY',
  };

  /// EMVCo merchant-presented QR: a run of tag(2) length(2) value fields that
  /// starts with "000201" and ends with the CRC field "6304" + 4 hex digits.
  static PaymentInfo? _parseEmv(String v) {
    if (!v.startsWith('000201')) return null;
    if (!RegExp(r'6304[0-9A-Fa-f]{4}$').hasMatch(v)) return null;

    final tags = <String, String>{};
    var i = 0;
    while (i + 4 <= v.length) {
      final tag = v.substring(i, i + 2);
      final len = int.tryParse(v.substring(i + 2, i + 4));
      if (len == null || i + 4 + len > v.length) break;
      tags[tag] = v.substring(i + 4, i + 4 + len);
      i += 4 + len;
    }
    // A real payment payload always names the merchant or country.
    if (!tags.containsKey('59') && !tags.containsKey('58')) return null;

    final amount = _clean(tags['54']);
    final code = _clean(tags['53']);
    return PaymentInfo(
      scheme: 'emv',
      payeeName: _clean(tags['59']),
      place: _clean(tags['60']),
      amount: (amount != null && RegExp(r'^\d+(\.\d+)?$').hasMatch(amount)) ? amount : null,
      currency: code == null ? null : (_emvCurrencies[code] ?? 'code $code'),
    );
  }
}
