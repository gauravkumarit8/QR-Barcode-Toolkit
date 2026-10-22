/// Builds the support email: an empty message for the user to fill in, and
/// optionally some technical details. Pure Dart so it can be unit tested.
class FeedbackReport {
  /// Long mailto links can be refused by mail apps, so the body is capped.
  static const int maxBodyChars = 1800;

  static String body({
    required String appVersion,
    required String phone,
    required List<String> errors,
    required bool includeDetails,
  }) {
    final b = StringBuffer('Describe the problem or your idea here:\n\n\n');
    if (includeDetails) {
      b.writeln('--- Technical details (you can delete this part) ---');
      b.writeln('App version: $appVersion');
      b.writeln('Phone: $phone');
      if (errors.isEmpty) {
        b.writeln('Recent errors: none');
      } else {
        b.writeln('Recent errors:');
        for (final e in errors) {
          b.writeln(e);
          b.writeln();
        }
      }
    }
    final text = b.toString();
    return text.length <= maxBodyChars ? text : '${text.substring(0, maxBodyChars)}…';
  }

  static Uri mailto({required String to, required String subject, required String body}) {
    return Uri(
      scheme: 'mailto',
      path: to,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
  }
}
