import 'package:flutter_test/flutter_test.dart';
import 'package:qr_barcode_toolkit/utils/csv_builder.dart';

void main() {
  group('CsvBuilder', () {
    test('plain rows use CRLF line endings', () {
      expect(
        CsvBuilder.build(['a', 'b'], [['1', '2']]),
        'a,b\r\n1,2\r\n',
      );
    });

    test('empty cell stays empty', () {
      expect(CsvBuilder.build(['h'], [['']]), 'h\r\n\r\n');
    });

    test('commas, quotes and newlines are quoted and escaped', () {
      expect(CsvBuilder.build(['h'], [['x,y']]), 'h\r\n"x,y"\r\n');
      expect(CsvBuilder.build(['h'], [['say "hi"']]), 'h\r\n"say ""hi"""\r\n');
      expect(CsvBuilder.build(['h'], [['a\nb']]), 'h\r\n"a\nb"\r\n');
    });

    test('formula-looking cells get a leading apostrophe (CSV injection)', () {
      expect(
        CsvBuilder.build(['h'], [['=HYPERLINK("http://evil","x")']]),
        "h\r\n\"'=HYPERLINK(\"\"http://evil\"\",\"\"x\"\")\"\r\n",
      );
      expect(
        CsvBuilder.build(['h'], [['+1'], ['-1'], ['@x'], ['\tx']]),
        "h\r\n'+1\r\n'-1\r\n'@x\r\n'\tx\r\n",
      );
    });

    test('a cell with = in the middle is left alone', () {
      expect(CsvBuilder.build(['h'], [['a=b']]), 'h\r\na=b\r\n');
    });
  });
}
