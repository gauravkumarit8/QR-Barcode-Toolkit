/// Builds CSV text. Pure Dart (no Flutter / IO) so it is easy to test.
///
/// Scanned codes are attacker-controlled text. A QR code containing
/// `=HYPERLINK("http://evil",...)` would run as a formula when the exported
/// file is opened in Excel or Google Sheets ("CSV injection"). So any cell
/// starting with = + - @ (or tab / CR) gets a leading apostrophe, which
/// spreadsheets treat as "this is text". The apostrophe is visible in some
/// viewers; that is the accepted trade-off for not executing scanned content.
class CsvBuilder {
  static String build(List<String> header, List<List<String>> rows) {
    final out = StringBuffer()..write(_line(header));
    for (final row in rows) {
      out.write(_line(row));
    }
    return out.toString();
  }

  static String _line(List<String> cells) => '${cells.map(_cell).join(',')}\r\n';

  static String _cell(String raw) {
    var v = raw;
    if (v.isNotEmpty && '=+-@\t\r'.contains(v[0])) v = "'$v";
    if (v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r')) {
      v = '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}
