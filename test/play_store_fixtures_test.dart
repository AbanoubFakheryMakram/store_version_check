import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:store_version_check/store_version_check.dart';

/// Trimmed copies of real Google Play pages. If Google changes the page, refresh these and the parser together.
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  test('real page: InStock Business', () {
    expect(PlayStoreParser.parseVersion(fixture('play_page_business.html')), '1.3.0');
  });

  test('real page: InStock (other versions on the page are not mistaken for the app version)', () {
    expect(PlayStoreParser.parseVersion(fixture('play_page_instock.html')), '1.42.1');
  });

  test('real page without the version structure gives null, never an unrelated number', () {
    expect(PlayStoreParser.parseVersion(fixture('play_page_no_version.html')), isNull);
  });
}
