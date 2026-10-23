import 'package:flutter_test/flutter_test.dart';
import 'package:qr_barcode_toolkit/utils/qr_style.dart';

void main() {
  group('luminance and contrast', () {
    test('black and white', () {
      expect(QrStyleRules.luminance(0xFF000000), 0.0);
      expect(QrStyleRules.luminance(0xFFFFFFFF), closeTo(1.0, 1e-9));
      expect(QrStyleRules.contrastRatio(0xFF000000, 0xFFFFFFFF), closeTo(21.0, 1e-6));
    });

    test('contrast does not depend on the order of the two colours', () {
      expect(
        QrStyleRules.contrastRatio(0xFF14532D, 0xFFFFF8E1),
        QrStyleRules.contrastRatio(0xFFFFF8E1, 0xFF14532D),
      );
    });

    test('the same colour has contrast 1', () {
      expect(QrStyleRules.contrastRatio(0xFF808080, 0xFF808080), closeTo(1.0, 1e-9));
    });
  });

  group('isScannable', () {
    test('every offered colour pair is safe', () {
      for (final fg in QrStyleRules.foregrounds) {
        for (final bg in QrStyleRules.backgrounds) {
          expect(
            QrStyleRules.isScannable(fg.argb, bg.argb),
            isTrue,
            reason: '${fg.name} on ${bg.name}',
          );
        }
      }
    });

    test('light on dark is rejected, even with high contrast', () {
      expect(QrStyleRules.isScannable(0xFFFFFFFF, 0xFF000000), isFalse);
    });

    test('low contrast is rejected', () {
      expect(QrStyleRules.isScannable(0xFFBBBBBB, 0xFFFFFFFF), isFalse);
      expect(QrStyleRules.isScannable(0xFFFFEB3B, 0xFFFFFFFF), isFalse); // yellow on white
    });
  });

  group('choices', () {
    test('the defaults are the first choices', () {
      expect(QrStyleRules.foregrounds.first.argb, QrStyleRules.defaultForeground);
      expect(QrStyleRules.backgrounds.first.argb, QrStyleRules.defaultBackground);
    });

    test('no duplicate colours', () {
      expect(QrStyleRules.foregrounds.map((c) => c.argb).toSet().length,
          QrStyleRules.foregrounds.length);
      expect(QrStyleRules.backgrounds.map((c) => c.argb).toSet().length,
          QrStyleRules.backgrounds.length);
    });
  });

  group('isDefault', () {
    test('plain black on white is the default', () {
      expect(
        QrStyleRules.isDefault(
          foreground: QrStyleRules.defaultForeground,
          background: QrStyleRules.defaultBackground,
          rounded: false,
          hasLogo: false,
        ),
        isTrue,
      );
    });

    test('any change makes it styled', () {
      const fg = QrStyleRules.defaultForeground;
      const bg = QrStyleRules.defaultBackground;
      expect(QrStyleRules.isDefault(foreground: 0xFF0B2A6B, background: bg, rounded: false, hasLogo: false), isFalse);
      expect(QrStyleRules.isDefault(foreground: fg, background: 0xFFFFF8E1, rounded: false, hasLogo: false), isFalse);
      expect(QrStyleRules.isDefault(foreground: fg, background: bg, rounded: true, hasLogo: false), isFalse);
      expect(QrStyleRules.isDefault(foreground: fg, background: bg, rounded: false, hasLogo: true), isFalse);
    });
  });

  group('ecLevel', () {
    test('a logo always gets the highest level', () {
      expect(QrStyleRules.ecLevel(styled: true, hasLogo: true), QrEcLevel.high);
    });

    test('colours or rounded dots get a medium level', () {
      expect(QrStyleRules.ecLevel(styled: true, hasLogo: false), QrEcLevel.medium);
    });

    test('a plain code stays low', () {
      expect(QrStyleRules.ecLevel(styled: false, hasLogo: false), QrEcLevel.low);
    });
  });
}
