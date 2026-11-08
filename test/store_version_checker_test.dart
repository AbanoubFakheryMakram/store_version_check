import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:store_version_check/store_version_check.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  StoreVersionChecker playChecker(MockClient client, {void Function(Object, StackTrace)? onError}) {
    return StoreVersionChecker(
      androidPackageName: 'com.example.app',
      currentVersionOverride: '1.0.0',
      platformOverride: TargetPlatform.android,
      client: client,
      onError: onError,
    );
  }

  test('Android: reports an update when Play has a higher version', () async {
    final client = MockClient((_) async => http.Response('x[[["1.1.0"]],[[[36]]]', 200));
    final result = await playChecker(client).check();
    expect(result.status, StoreVersionStatus.updateAvailable);
    expect(result.storeVersion, '1.1.0');
    expect(result.storeUrl, contains('com.example.app'));
  });

  test('Android: up to date when versions match', () async {
    final client = MockClient((_) async => http.Response('x[[["1.0.0"]],[[[36]]]', 200));
    expect((await playChecker(client).check()).status, StoreVersionStatus.upToDate);
  });

  test('Android: unknown (and reported) when the page layout is not recognised', () async {
    Object? reported;
    final client = MockClient((_) async => http.Response('<html></html>', 200));
    final result = await playChecker(client, onError: (e, _) => reported = e).check();
    expect(result.status, StoreVersionStatus.unknown);
    expect(reported, isA<StoreVersionException>());
  });

  test('network failure is unknown, never an exception', () async {
    final client = MockClient((_) async => throw Exception('offline'));
    expect((await playChecker(client).check()).status, StoreVersionStatus.unknown);
  });

  test('a slow store ends as unknown after the timeout', () async {
    final client = MockClient((_) => Future.delayed(const Duration(seconds: 2), () => http.Response('', 200)));
    final checker = StoreVersionChecker(
      androidPackageName: 'com.example.app',
      currentVersionOverride: '1.0.0',
      platformOverride: TargetPlatform.android,
      client: client,
      timeout: const Duration(milliseconds: 50),
    );
    expect((await checker.check()).status, StoreVersionStatus.unknown);
  });

  test('iOS: retries without the country when the storefront has no result', () async {
    final urls = <String>[];
    final client = MockClient((request) async {
      urls.add(request.url.toString());
      final hasCountry = request.url.queryParameters.containsKey('country');
      return http.Response(
        jsonEncode(
          hasCountry
              ? {'resultCount': 0, 'results': []}
              : {
                  'resultCount': 1,
                  'results': [
                    {'version': '2.0.0', 'trackViewUrl': 'https://apps.apple.com/app/id1'},
                  ],
                },
        ),
        200,
      );
    });
    final checker = StoreVersionChecker(
      iosBundleId: 'com.example.app',
      countryCode: 'eg',
      currentVersionOverride: '1.0.0',
      platformOverride: TargetPlatform.iOS,
      client: client,
    );
    final result = await checker.check();
    expect(urls.length, 2);
    expect(result.isUpdateAvailable, isTrue);
    expect(result.storeUrl, 'https://apps.apple.com/app/id1');
  });

  test('simulated: no network, always reports the given version', () async {
    final checker = StoreVersionChecker.simulated(
      storeVersion: '99.0.0',
      currentVersionOverride: '1.0.0',
      androidPackageName: 'com.example.app',
      platformOverride: TargetPlatform.android,
    );
    final result = await checker.check();
    expect(result.isUpdateAvailable, isTrue);
    expect(result.simulated, isTrue);
  });

  test('checkOncePerSession runs the first time only', () async {
    final checker = StoreVersionChecker.simulated(
      storeVersion: '2.0.0',
      currentVersionOverride: '1.0.0',
      androidPackageName: 'com.example.app',
      platformOverride: TargetPlatform.android,
    );
    expect(await checker.checkOncePerSession(), isNotNull);
    expect(await checker.checkOncePerSession(), isNull);
    expect(checker.lastResult?.isUpdateAvailable, isTrue);
  });

  test('a throwing onError never turns unknown into an exception', () async {
    final client = MockClient((_) async => http.Response('<html></html>', 200));
    final checker = playChecker(client, onError: (_, __) => throw StateError('logger is broken'));
    expect((await checker.check()).status, StoreVersionStatus.unknown);
  });

  test('an unparseable store version is unknown, not "up to date"', () async {
    final client = MockClient((_) async => http.Response('{"softwareVersion":"1.x"}', 200));
    // the parser only accepts numeric versions, so use the iOS path with a bad version to hit the comparator
    final ios = StoreVersionChecker(
      iosBundleId: 'com.example.app',
      countryCode: 'eg',
      currentVersionOverride: '1.0.0',
      platformOverride: TargetPlatform.iOS,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'resultCount': 1,
            'results': [
              {'version': 'abc'},
            ],
          }),
          200,
        ),
      ),
    );
    expect((await ios.check()).status, StoreVersionStatus.unknown);
    expect((await playChecker(client).check()).status, StoreVersionStatus.unknown);
  });

  test('an unparseable installed version is unknown', () async {
    final checker = StoreVersionChecker.simulated(
      storeVersion: '2.0.0',
      currentVersionOverride: 'dev',
      androidPackageName: 'com.example.app',
      platformOverride: TargetPlatform.android,
    );
    expect((await checker.check()).status, StoreVersionStatus.unknown);
  });

  test('the timeout covers the whole check, including the iOS fallback request', () async {
    // each request alone is faster than the timeout, the two together are not
    final client = MockClient((_) => Future.delayed(const Duration(milliseconds: 120), () {
          return http.Response(jsonEncode({'resultCount': 0, 'results': []}), 200);
        }));
    final checker = StoreVersionChecker(
      iosBundleId: 'com.example.app',
      countryCode: 'eg',
      currentVersionOverride: '1.0.0',
      platformOverride: TargetPlatform.iOS,
      client: client,
      timeout: const Duration(milliseconds: 200),
    );
    final watch = Stopwatch()..start();
    final result = await checker.check();
    expect(result.status, StoreVersionStatus.unknown);
    expect(watch.elapsedMilliseconds, lessThan(320));
  });

  test('iOS: without the global fallback an unlisted storefront is unknown', () async {
    final urls = <String>[];
    final client = MockClient((request) async {
      urls.add(request.url.toString());
      return http.Response(jsonEncode({'resultCount': 0, 'results': []}), 200);
    });
    final checker = StoreVersionChecker(
      iosBundleId: 'com.example.app',
      countryCode: 'eg',
      allowGlobalStorefrontFallback: false,
      currentVersionOverride: '1.0.0',
      platformOverride: TargetPlatform.iOS,
      client: client,
    );
    expect((await checker.check()).status, StoreVersionStatus.unknown);
    expect(urls.length, 1);
  });
}
