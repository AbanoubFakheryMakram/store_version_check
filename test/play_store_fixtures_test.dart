import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:store_version_check/store_version_check.dart';

/// Synthetic pages that follow the structure of a Google Play app page (no real app data).
/// If Google changes the page, update these together with the parser.
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  test('reads the version from a page that follows the Play structure', () {
    expect(PlayStoreParser.parseVersion(fixture('play_page_basic.html')), '1.3.0');
  });

  test('other version-like values on the page are not mistaken for the app version', () {
    expect(PlayStoreParser.parseVersion(fixture('play_page_decoys.html')), '2.5.0');
  });

  test('a page without the version structure gives null, never an unrelated number', () {
    expect(PlayStoreParser.parseVersion(fixture('play_page_no_version.html')), isNull);
  });
}
