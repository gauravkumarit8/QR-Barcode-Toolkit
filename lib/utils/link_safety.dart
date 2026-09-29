/// Lightweight, on-device heuristics for flagging a scanned link as worth a
/// second look before opening it. This is NOT a real phishing/malware check
/// — a proper one needs an online reputation service (e.g. Google Safe
/// Browsing), which would break the app's offline-first design and add a
/// network dependency + API key to manage. These heuristics catch some of
/// the most common red flags without any network call.
class LinkSafety {
  static const _shortenerHosts = {
    'bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'is.gd', 'ow.ly', 'buff.ly',
    'rebrand.ly', 'cutt.ly', 'shorturl.at', 'rb.gy', 'tiny.cc',
  };

  /// Returns a short reason string if the URL looks worth a second look,
  /// or null if nothing stood out. A null result is NOT a guarantee of
  /// safety — it just means these specific heuristics found nothing.
  static String? checkReason(Uri uri) {
    final host = uri.host.toLowerCase();

    if (_shortenerHosts.contains(host)) {
      return 'This is a shortened link — the real destination is hidden until you open it.';
    }

    if (_isRawIpHost(host)) {
      return 'This link points directly to an IP address rather than a normal website name.';
    }

    if (host.startsWith('xn--') || host.contains('.xn--')) {
      return 'This web address uses characters that can be made to look like a different, trusted site.';
    }

    if (uri.userInfo.isNotEmpty) {
      // e.g. http://real-bank.com@evil.example — browsers ignore the part
      // before @ as auth info, but many users read it as the domain.
      return 'This link is disguised to look like it goes to a different site than it actually does.';
    }

    return null;
  }

  static bool _isRawIpHost(String host) {
    final ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
    return ipv4.hasMatch(host);
  }
}
