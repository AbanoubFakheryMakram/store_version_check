import 'package:flutter_test/flutter_test.dart';
import 'package:store_version_check/store_version_check.dart';

void main() {
  group('VersionComparator', () {
    test('orders versions numerically, not alphabetically', () {
      expect(VersionComparator.isNewer('1.10.0', '1.9.0'), isTrue);
      expect(VersionComparator.isNewer('1.9.0', '1.10.0'), isFalse);
    });

    test('equal versions are not newer', () {
      expect(VersionComparator.isNewer('1.2.3', '1.2.3'), isFalse);
    });

    test('missing segments count as zero', () {
      expect(VersionComparator.compare('1.2', '1.2.0'), 0);
      expect(VersionComparator.isNewer('1.2.1', '1.2'), isTrue);
    });

    test('ignores build numbers, pre-release tags and a leading v', () {
      expect(VersionComparator.compare('1.2.1+13', '1.2.1'), 0);
      expect(VersionComparator.compare('v2.0.0-beta', '2.0.0'), 0);
      expect(VersionComparator.isNewer('1.3.0+1', '1.2.9+99'), isTrue);
    });

    test('isValid tells comparable versions from garbage', () {
      expect(VersionComparator.isValid('1.2.3+4'), isTrue);
      expect(VersionComparator.isValid('abc'), isFalse);
      expect(VersionComparator.isValid(''), isFalse);
    });

    test('unparseable input never reports an update', () {
      expect(VersionComparator.isNewer('abc', '1.0.0'), isFalse);
      expect(VersionComparator.isNewer('1.0.0', ''), isFalse);
    });
  });

  group('PlayStoreParser', () {
    const sdkBlock = ',[[[36]],[[[29,"10"]]]]';

    test('reads the current layout', () {
      expect(PlayStoreParser.parseVersion('x[[["1.4.2"]]$sdkBlock'), '1.4.2');
    });

    test('reads a two segment version', () {
      expect(PlayStoreParser.parseVersion('x[[["2.0"]]$sdkBlock'), '2.0');
    });

    test('ignores an unrelated version-like array that is not followed by the SDK block', () {
      expect(PlayStoreParser.parseVersion('{"x":[[["9.9.9"]],"other"]}'), isNull);
      expect(PlayStoreParser.parseVersion('a[[["9.9.9"]]b a[[["1.0.1"]]$sdkBlock'), '1.0.1');
    });

    test('reads softwareVersion and the old layout', () {
      expect(PlayStoreParser.parseVersion('{"softwareVersion":"3.1.0"}'), '3.1.0');
      expect(PlayStoreParser.parseVersion('<div>Current Version</div><span>5.0.1<'), '5.0.1');
    });

    test('returns null when nothing matches', () {
      expect(PlayStoreParser.parseVersion('<html>nothing here</html>'), isNull);
    });
  });
}
