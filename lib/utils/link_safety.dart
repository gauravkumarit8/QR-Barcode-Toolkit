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

  /// Every reason this link deserves a second look. Empty means none of these
  /// specific checks fired — NOT a guarantee that the link is safe.
  static List<String> reasons(Uri uri) {
    final host = uri.host.toLowerCase();
    final out = <String>[];

    if (_shortenerHosts.contains(host)) {
      out.add('This is a shortened link — the real destination is hidden until you open it.');
    }
    if (_isRawIpHost(host)) {
      out.add('This link points directly to an IP address rather than a normal website name.');
    }
    if (host.startsWith('xn--') || host.contains('.xn--') || host.runes.any((r) => r > 127)) {
      out.add('This web address uses characters that can be made to look like a different, trusted site.');
    }
    if (uri.userInfo.isNotEmpty) {
      // e.g. http://real-bank.com@evil.example — browsers ignore the part
      // before @ as auth info, but many users read it as the domain.
      out.add('This link is disguised to look like it goes to a different site than it actually does.');
    }
    if (host.split('.').length >= 5) {
      out.add('This address has many parts before the site name. Scammers use long addresses to imitate real sites, so check the very end of the address.');
    }
    if (uri.scheme == 'http') {
      out.add('This link is not encrypted (http), so anything you type on the page could be seen or changed on the way.');
    }
    return out;
  }

  /// The most serious reason, or null if none fired.
  static String? checkReason(Uri uri) {
    final r = reasons(uri);
    return r.isEmpty ? null : r.first;
  }

  /// Everything after the host (path, query, fragment), shown small under the
  /// host so the part that identifies the site is what the user reads first.
  static String restOf(Uri uri) {
    final b = StringBuffer(uri.path);
    if (uri.hasQuery) b.write('?${uri.query}');
    if (uri.hasFragment) b.write('#${uri.fragment}');
    final s = b.toString();
    return s == '/' ? '' : s;
  }

  static bool _isRawIpHost(String host) {
    final ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
    return ipv4.hasMatch(host);
  }
}
