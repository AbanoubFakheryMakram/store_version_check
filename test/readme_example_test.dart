import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:store_version_check/store_version_check.dart';

/// Keeps the README's "unit tests with your own HTTP responses" example honest.
void main() {
  test('README MockClient example reports an update', () async {
    final result = await StoreVersionChecker(
      client: MockClient((_) async => http.Response('..."141":[[["2.0.0"]],[[[36]]]]...', 200)),
      currentVersionOverride: '1.0.0',
      platformOverride: TargetPlatform.android,
      androidPackageName: 'com.example.app',
    ).check();
    expect(result.isUpdateAvailable, isTrue);
  });
}
