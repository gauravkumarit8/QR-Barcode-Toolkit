/// Builds `upi://pay` payment links (for the UPI QR generator).
///
/// Pure Dart (no Flutter) so it can be unit tested. The output is read back
/// by `ScanContent.parse`, and the tests check that round trip.
///
/// The link format is the common UPI deep link:
///   upi://pay?pa=<UPI ID>&pn=<name>&am=<amount>&cu=INR&tn=<note>
/// Only `pa` is required. The amount is optional; when it is left out the
/// payer types it in their UPI app.
class UpiLink {
  /// Conservative length caps. Some UPI apps cut off or reject long values.
  static const int nameMax = 50;
  static const int noteMax = 50;

  /// UPI ID (VPA) such as `shop@okbank` or `9876543210@ybl`.
  /// Deliberately lenient: it rejects obvious typos (spaces, no `@`, missing
  /// bank handle) without refusing real IDs from banks we don't know about.
  static final RegExp _vpa =
      RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z][a-zA-Z0-9.\-]{1,63}$');

  /// Up to 7 digits and at most 2 decimals. A trailing "." is allowed while
  /// the user is still typing and is removed on output.
  static final RegExp _amount = RegExp(r'^\d{1,7}(\.\d{0,2})?$');

  static bool isValidVpa(String value) => _vpa.hasMatch(value.trim());

  /// Returns:
  ///  - `''`  when [raw] is empty (no amount; the payer chooses),
  ///  - the cleaned amount (e.g. `"499"`, `"10.5"`) when valid,
  ///  - `null` when invalid (not a positive number with at most 2 decimals).
  static String? normalizeAmount(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    if (!_amount.hasMatch(v)) return null;
    final clean = v.endsWith('.') ? v.substring(0, v.length - 1) : v;
    final n = double.tryParse(clean);
    if (n == null || n <= 0) return null;
    return clean;
  }

  /// Message for the UPI ID field, or null when it is empty or valid.
  static String? vpaError(String value) {
    if (value.trim().isEmpty || isValidVpa(value)) return null;
    return 'Enter a UPI ID like name@bank';
  }

  /// Message for the amount field, or null when it is empty or valid.
  static String? amountError(String value) {
    return normalizeAmount(value) == null
        ? 'Enter an amount like 499 or 499.50'
        : null;
  }

  /// Returns the payment link, or null when the UPI ID or amount is invalid.
  static String? build({
    required String vpa,
    String name = '',
    String amount = '',
    String note = '',
  }) {
    final id = vpa.trim();
    if (!isValidVpa(id)) return null;
    final am = normalizeAmount(amount);
    if (am == null) return null;

    final pn = _clip(_tidy(name), nameMax);
    final tn = _clip(_tidy(note), noteMax);

    // '@' is left readable in the UPI ID; apps expect "pa=name@bank".
    final b = StringBuffer('upi://pay?pa=${_encodeVpa(id)}');
    if (pn.isNotEmpty) b.write('&pn=${Uri.encodeComponent(pn)}');
    if (am.isNotEmpty) b.write('&am=$am');
    b.write('&cu=INR');
    if (tn.isNotEmpty) b.write('&tn=${Uri.encodeComponent(tn)}');
    return b.toString();
  }

  static String _encodeVpa(String id) =>
      Uri.encodeComponent(id).replaceAll('%40', '@');

  /// Trims, turns control characters into spaces, and collapses whitespace.
  static String _tidy(String s) => s
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Cuts to [max] characters (whole code points, so emoji aren't split).
  static String _clip(String s, int max) {
    final runes = s.runes;
    return runes.length <= max ? s : String.fromCharCodes(runes.take(max));
  }
}
