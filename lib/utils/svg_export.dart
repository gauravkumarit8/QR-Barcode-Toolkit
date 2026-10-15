import 'package:barcode/barcode.dart';

/// Builds print-ready SVG for a QR code or a linear barcode.
///
/// The `barcode` package draws the code edge to edge. Scanners need empty
/// space around a code (the "quiet zone"), and a transparent background can
/// print as black, so the result is wrapped in a white page with a 10% margin.
class SvgExport {
  static const _qrSize = 800.0;
  static const _barWidth = 800.0;
  static const _barHeight = 320.0;
  static const _margin = 80.0;

  /// QR code. Tries the library's automatic version first, then every version
  /// from 1 to 40, so a failure always means the text really is too long.
  static String qr(String data) {
    Object? lastError;
    for (final version in <int?>[null, for (var v = 1; v <= 40; v++) v]) {
      try {
        return _wrap(
          Barcode.qrCode(typeNumber: version),
          data,
          _qrSize,
          _qrSize,
          drawText: false,
        );
      } catch (e) {
        lastError = e;
      }
    }
    throw FormatException('Could not encode this text as a QR code: $lastError');
  }

  /// Code 128, EAN-13, UPC-A, Code 39, ITF... drawn with the value underneath.
  /// Throws if [data] is not valid for the chosen format.
  static String linear(Barcode barcode, String data) {
    // The human-readable text is written into the SVG as XML. If the value
    // contains XML special characters, leave the text out rather than risk
    // producing a broken file.
    final textIsSafe = !RegExp('[&<>"\']').hasMatch(data);
    return _wrap(barcode, data, _barWidth, _barHeight, drawText: textIsSafe);
  }

  static String _wrap(
    Barcode barcode,
    String data,
    double width,
    double height, {
    required bool drawText,
  }) {
    final shapes = barcode.toSvg(
      data,
      width: width,
      height: height,
      drawText: drawText,
      fullSvg: false,
    );
    final totalWidth = width + _margin * 2;
    final totalHeight = height + _margin * 2;
    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<svg xmlns="http://www.w3.org/2000/svg" width="$totalWidth" height="$totalHeight" '
        'viewBox="0 0 $totalWidth $totalHeight">\n'
        '  <rect width="$totalWidth" height="$totalHeight" fill="#FFFFFF"/>\n'
        '  <g transform="translate($_margin $_margin)">\n$shapes\n  </g>\n'
        '</svg>\n';
  }
}
