import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'play_store_parser.dart';
import 'store_version_result.dart';
import 'version_comparator.dart';

/// Asks Google Play or the Apple App Store which version of your app is published, and compares it with the
/// installed version.
///
/// ```dart
/// final checker = StoreVersionChecker();
/// final result = await checker.check();
/// if (result.isUpdateAvailable) {
///   // show your own dialog, then launchUrl(Uri.parse(result.storeUrl!))
/// }
/// ```
///
/// It never throws: every failure ends as [StoreVersionStatus.unknown].
class StoreVersionChecker {
  /// Creates a checker that reads the real store.
  ///
  /// [androidPackageName] and [iosBundleId] default to the installed app's own identifier, so most apps need
  /// no arguments. Pass them when the iOS bundle id differs from the Android package name.
  StoreVersionChecker({
    this.androidPackageName,
    this.iosBundleId,
    this.countryCode,
    this.timeout = const Duration(seconds: 5),
    this.allowGlobalStorefrontFallback = true,
    http.Client? client,
    this.currentVersionOverride,
    this.platformOverride,
    this.onError,
  })  : _simulatedStoreVersion = null,
        _client = client;

  /// Creates a checker that pretends the store publishes [storeVersion], with no network call.
  ///
  /// Use it to see your update UI on any build (debug, APK, TestFlight) without publishing a release:
  ///
  /// ```dart
  /// StoreVersionChecker.simulated(storeVersion: '99.0.0') // always reports an update
  /// ```
  StoreVersionChecker.simulated({
    required String storeVersion,
    this.currentVersionOverride,
    this.androidPackageName,
    this.iosBundleId,
    this.platformOverride,
    this.onError,
  })  : _simulatedStoreVersion = storeVersion,
        countryCode = null,
        timeout = const Duration(seconds: 5),
        allowGlobalStorefrontFallback = true,
        _client = null;

  /// Android application id to look up. Defaults to the installed package name.
  final String? androidPackageName;

  /// iOS bundle id to look up. Defaults to the installed bundle id.
  final String? iosBundleId;

  /// Two-letter store country (`eg`, `us`...). Defaults to the device locale's country.
  /// If the app is not listed there, the iOS lookup is retried without a country.
  final String? countryCode;

  /// The time budget of the whole [check], including the iOS storefront fallback request. A slow network ends as
  /// [StoreVersionStatus.unknown], never a hang.
  final Duration timeout;

  /// iOS only. When the app is not listed in the user's storefront (`countryCode`), look it up without a country
  /// instead of giving up. The version found then is the global one, which may not be installable in the user's
  /// country yet; set this to `false` to report [StoreVersionStatus.unknown] in that case.
  final bool allowGlobalStorefrontFallback;

  /// Overrides the installed version (mainly for tests). Defaults to `PackageInfo.version`.
  final String? currentVersionOverride;

  /// Overrides the detected platform (mainly for tests).
  final TargetPlatform? platformOverride;

  /// Called with the reason whenever a check ends as unknown. Hook your logging / Crashlytics here so a
  /// changed Play Store layout does not fail silently.
  final void Function(Object error, StackTrace stackTrace)? onError;

  final String? _simulatedStoreVersion;
  final http.Client? _client;

  bool _checkedThisSession = false;

  /// The result of the first [checkOncePerSession] call.
  StoreVersionResult? lastResult;

  /// Runs [check] the first time it is called on this instance and returns `null` afterwards.
  ///
  /// "Session" means this instance: two instances each run their own first check. Keep ONE instance for the app's
  /// lifetime (a provider, a singleton, a field of a long-lived service), never create it per screen or per call.
  Future<StoreVersionResult?> checkOncePerSession() async {
    if (_checkedThisSession) return null;
    _checkedThisSession = true;
    return lastResult = await check();
  }

  /// Fetches the store version and compares it with the installed one.
  Future<StoreVersionResult> check() async {
    String? current;
    try {
      current = currentVersionOverride ?? (await PackageInfo.fromPlatform()).version;
      if (!VersionComparator.isValid(current)) {
        throw StoreVersionException('The installed version "$current" is not a comparable version.');
      }

      final simulated = _simulatedStoreVersion;
      if (simulated != null) {
        if (!VersionComparator.isValid(simulated)) {
          throw StoreVersionException('The simulated store version "$simulated" is not a comparable version.');
        }
        return StoreVersionResult(
          status: VersionComparator.isNewer(simulated, current)
              ? StoreVersionStatus.updateAvailable
              : StoreVersionStatus.upToDate,
          currentVersion: current,
          storeVersion: simulated,
          storeUrl: await _storeUrl(),
          simulated: true,
        );
      }

      final lookup = await _lookup().timeout(timeout);
      if (lookup == null) {
        throw const StoreVersionException('The store did not return a version for this app.');
      }
      if (!VersionComparator.isValid(lookup.version)) {
        throw StoreVersionException('The store version "${lookup.version}" is not a comparable version.');
      }
      return StoreVersionResult(
        status: VersionComparator.isNewer(lookup.version, current)
            ? StoreVersionStatus.updateAvailable
            : StoreVersionStatus.upToDate,
        currentVersion: current,
        storeVersion: lookup.version,
        storeUrl: lookup.url,
      );
    } catch (error, stackTrace) {
      _report(error, stackTrace);
      return StoreVersionResult(status: StoreVersionStatus.unknown, currentVersion: current, error: error);
    }
  }

  /// A failing [onError] must never turn an unknown result into an exception.
  void _report(Object error, StackTrace stackTrace) {
    try {
      onError?.call(error, stackTrace);
    } catch (_) {}
  }

  TargetPlatform get _platform => platformOverride ?? defaultTargetPlatform;

  Future<String> _storeUrl() async {
    if (_platform == TargetPlatform.iOS) {
      return 'https://apps.apple.com/app/${await _bundleId()}';
    }
    return 'https://play.google.com/store/apps/details?id=${await _packageName()}';
  }

  Future<String> _packageName() async => androidPackageName ?? (await PackageInfo.fromPlatform()).packageName;

  Future<String> _bundleId() async => iosBundleId ?? (await PackageInfo.fromPlatform()).packageName;

  Future<({String version, String url})?> _lookup() async {
    switch (_platform) {
      case TargetPlatform.android:
        return _playStoreLookup(await _packageName());
      case TargetPlatform.iOS:
        return _appStoreLookup(await _bundleId());
      default:
        throw StoreVersionException('Unsupported platform: $_platform');
    }
  }

  Future<({String version, String url})?> _playStoreLookup(String packageName) async {
    final url = 'https://play.google.com/store/apps/details?id=$packageName&hl=en';
    final response = await _get(Uri.parse(url));
    if (response.statusCode != 200) return null;
    final version = PlayStoreParser.parseVersion(response.body);
    return version == null ? null : (version: version, url: url);
  }

  Future<({String version, String url})?> _appStoreLookup(String bundleId) async {
    final country = (countryCode ?? PlatformDispatcher.instance.locale.countryCode)?.toLowerCase();
    final hasCountry = country != null && country.isNotEmpty;
    // the country first (the app may only be listed in some storefronts), then, if allowed, a global lookup
    for (final query in [if (hasCountry) '&country=$country', if (!hasCountry || allowGlobalStorefrontFallback) '']) {
      final response = await _get(Uri.parse('https://itunes.apple.com/lookup?bundleId=$bundleId$query'));
      if (response.statusCode != 200) continue;
      final json = jsonDecode(response.body);
      final results = json is Map ? json['results'] : null;
      if (results is List && results.isNotEmpty && results.first['version'] != null) {
        final first = results.first as Map;
        return (
          version: first['version'].toString(),
          url: (first['trackViewUrl'] ?? 'https://apps.apple.com/app/$bundleId').toString(),
        );
      }
    }
    return null;
  }

  Future<http.Response> _get(Uri uri) {
    final request = (_client?.get(uri) ?? http.get(uri));
    return request.timeout(timeout);
  }
}

/// Why a store check could not complete.
class StoreVersionException implements Exception {
  /// Creates the exception.
  const StoreVersionException(this.message);

  /// Human readable reason.
  final String message;

  @override
  String toString() => 'StoreVersionException: $message';
}
