import 'package:share_plus/share_plus.dart';

/// The only place that talks to the share_plus package. Newer share_plus
/// versions replaced the static `Share.share(...)` calls with
/// `SharePlus.instance.share(ShareParams(...))`; keeping that in one file
/// means the next change to the plugin touches one file, not every screen.
class ShareService {
  /// Opens the system share sheet with plain text.
  static Future<void> text(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }

  /// Opens the system share sheet with files, and optionally text and a
  /// subject line (used as the email subject by mail apps).
  static Future<void> files(
    List<XFile> files, {
    String? text,
    String? subject,
  }) async {
    await SharePlus.instance.share(
      ShareParams(files: files, text: text, subject: subject),
    );
  }
}
