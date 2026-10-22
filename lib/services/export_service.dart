import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'share_service.dart';

/// Writes files to a temporary folder and opens the system share sheet.
class ExportService {
  static String _stamp() =>
      DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;

  /// Shares [csv] as a .csv file. A UTF-8 byte-order mark is added so Excel
  /// shows non-English text correctly.
  static Future<void> shareCsv(String csv, {String baseName = 'qr-toolkit'}) async {
    final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$baseName-${_stamp()}.csv');
    await file.writeAsBytes(bytes, flush: true);
    await ShareService.files(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'QR & Barcode Toolkit export',
    );
  }

  /// Shares text content (for example an SVG) as a file with the given
  /// extension and MIME type.
  static Future<void> shareTextFile(
    String content, {
    required String baseName,
    required String extension,
    required String mimeType,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$baseName-${_stamp()}.$extension');
    await file.writeAsString(content, flush: true);
    await ShareService.files(
      [XFile(file.path, mimeType: mimeType)],
      subject: 'QR & Barcode Toolkit export',
    );
  }
}
