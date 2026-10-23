import 'dart:math' as math;

/// Colour choices and safety rules for styled QR codes.
///
/// Pure Dart (colours are plain 0xAARRGGBB integers) so the rules can be unit
/// tested. Scanners need dark squares on a light background, so every choice
/// offered here is a dark colour on a light one, and [isScannable] checks the
/// contrast so a combination that is hard to scan can never be picked.
class QrColorChoice {
  final String name;
  final int argb;
  const QrColorChoice(this.name, this.argb);
}

/// How much error correction to build into the code.
enum QrEcLevel { low, medium, high }

class QrStyleRules {
  static const int defaultForeground = 0xFF000000;
  static const int defaultBackground = 0xFFFFFFFF;

  /// Dark colours for the code itself.
  static const List<QrColorChoice> foregrounds = [
    QrColorChoice('Black', 0xFF000000),
    QrColorChoice('Navy', 0xFF0B2A6B),
    QrColorChoice('Forest green', 0xFF14532D),
    QrColorChoice('Maroon', 0xFF7F1D1D),
    QrColorChoice('Purple', 0xFF4C1D95),
  ];

  /// Light colours for the background.
  static const List<QrColorChoice> backgrounds = [
    QrColorChoice('White', 0xFFFFFFFF),
    QrColorChoice('Cream', 0xFFFFF8E1),
    QrColorChoice('Light gray', 0xFFF1F1F1),
  ];

  /// Lowest contrast ratio allowed between code and background (WCAG scale,
  /// 1 to 21). Black on white is 21; the weakest offered pair is above 8.
  static const double minContrast = 7.0;

  /// Relative luminance, 0 (black) to 1 (white), as defined by WCAG.
  static double luminance(int argb) {
    double channel(int c) {
      final v = c / 255;
      return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = channel((argb >> 16) & 0xFF);
    final g = channel((argb >> 8) & 0xFF);
    final b = channel(argb & 0xFF);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double contrastRatio(int a, int b) {
    final la = luminance(a);
    final lb = luminance(b);
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// True when the code is darker than its background by enough to scan well.
  static bool isScannable(int foreground, int background) =>
      luminance(foreground) < luminance(background) &&
      contrastRatio(foreground, background) >= minContrast;

  /// True when nothing has been changed from plain black on white squares.
  static bool isDefault({
    required int foreground,
    required int background,
    required bool rounded,
    required bool hasLogo,
  }) =>
      foreground == defaultForeground &&
      background == defaultBackground &&
      !rounded &&
      !hasLogo;

  /// A logo hides part of the code, so it needs the most error correction.
  /// Colours or rounded dots get a little extra. A plain code keeps the
  /// library default (low), as before.
  static QrEcLevel ecLevel({
    required bool styled,
    required bool hasLogo,
  }) {
    if (hasLogo) return QrEcLevel.high;
    return styled ? QrEcLevel.medium : QrEcLevel.low;
  }
}
