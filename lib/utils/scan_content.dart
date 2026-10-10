/// What kind of thing a scanned code contains, so the result card can offer
/// the one action that makes sense (call, email, open a map, copy the Wi-Fi
/// password...) instead of a generic "Search online" for everything.
///
/// Pure Dart, no Flutter imports, so it is easy to unit test.
enum ScanKind { url, wifi, phone, email, sms, geo, product, text }

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

class ScanContent {
  final ScanKind kind;
  final String raw;

  /// Set for url / phone / email / sms / geo.
  final Uri? uri;

  /// Set for wifi.
  final WifiInfo? wifi;

  const ScanContent._(this.kind, this.raw, {this.uri, this.wifi});

  /// [isProductBarcode] should be true for numeric EAN/UPC retail barcodes —
  /// the caller knows the barcode format, this parser only sees the text.
  factory ScanContent.parse(String raw, {bool isProductBarcode = false}) {
    final value = raw.trim();
    final lower = value.toLowerCase();

    if (lower.startsWith('wifi:')) {
      final wifi = _parseWifi(value.substring(5));
      if (wifi != null) return ScanContent._(ScanKind.wifi, raw, wifi: wifi);
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
}
