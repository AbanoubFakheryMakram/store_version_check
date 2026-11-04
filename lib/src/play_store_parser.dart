/// Extracts the published version from the HTML of a Google Play app page.
///
/// Google offers no public API for this, so the page markup is parsed. The patterns are kept in one place so a
/// layout change can be fixed in a patch release, and they are public so you can test your own app's page.
class PlayStoreParser {
  const PlayStoreParser._();

  static final List<RegExp> _patterns = [
    // current layout: the version sits alone in a nested array: [[["1.2.3"]]
    RegExp(r'\[\[\["(\d+(?:\.\d+)+)"\]\]'),
    // schema.org style field some layouts expose
    RegExp(r'"softwareVersion"\s*:\s*"(\d+(?:\.\d+)+)"'),
    // older layout: "Current Version" label followed by the number
    RegExp(r'Current Version.+?>(\d+(?:\.\d+)+)<'),
  ];

  /// Returns the version found in [html], or `null` when none of the known layouts match.
  static String? parseVersion(String html) {
    for (final pattern in _patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) return match.group(1);
    }
    return null;
  }
}
