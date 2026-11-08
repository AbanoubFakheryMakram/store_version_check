@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:store_version_check/store_version_check.dart';

/// Canary for the unofficial Google Play parsing: fetches a real, stable listing and expects a version back.
/// Run by the scheduled workflow (`flutter test --tags live`); when it fails, Google changed the page.
void main() {
  test('the parser still finds the version on the real Google Play page', () async {
    final response = await http.get(
      Uri.parse('https://play.google.com/store/apps/details?id=com.nstock.business&hl=en'),
      headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124 Mobile Safari/537.36'},
    );
    expect(response.statusCode, 200);
    final version = PlayStoreParser.parseVersion(response.body);
    expect(version, isNotNull, reason: 'Play page layout changed: update PlayStoreParser and the fixtures');
    expect(VersionComparator.isValid(version!), isTrue);
  });
}
