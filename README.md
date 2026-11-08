# store_version_check

Find out whether a **newer version of your app is live on Google Play or the Apple App Store**, then show your
own "update available" UI. Pure Dart/Flutter: **no native code, no Play Core, no backend, no Firebase.**

```dart
final result = await StoreVersionChecker().check();
if (result.isUpdateAvailable) {
  // your dialog → launchUrl(Uri.parse(result.storeUrl!))
}
```

## Why this package

| | `store_version_check` | Play Core based packages (e.g. `in_app_update`) |
|---|---|---|
| Works on **debug builds, APKs, TestFlight, CI artifacts** | Yes | No (Play-installed builds only) |
| Works on **Android and iOS** with one API | Yes | Android only |
| **Test the UI without publishing a release** | Yes, `StoreVersionChecker.simulated(...)` | Needs an old + a new build on a Play track |
| Native setup / permissions | None | Play Core, Android only |
| Shows **your own** dialog | Yes | Play's own flow |
| Official, store-supported API | **No** (see risks) | Yes |

### Why it is better for testing

Play Core only reports updates to builds *installed by Google Play*. To see your dialog you must upload two
builds to a track, install the older from Play, wait for the newer to propagate, and repeat per attempt.

This package compares versions you can control:

```dart
// see the dialog on ANY build, immediately, with no network call
StoreVersionChecker.simulated(storeVersion: '99.0.0');
```

or lower your local `version:` in `pubspec.yaml` below what the store publishes. Your CI, simulator and
emulator all behave the same as production.

## Install

```yaml
dependencies:
  store_version_check: ^0.1.0
  url_launcher: ^6.3.0   # to open the store page
```

No `AndroidManifest.xml` / `Info.plist` changes are required for the check itself. To open the store link with
`url_launcher` on iOS and Android 11+, follow its
[setup notes](https://pub.dev/packages/url_launcher#installation) (`https` queries).

## Usage

### 1. Basic check

```dart
final checker = StoreVersionChecker();          // keep one instance
final result = await checker.check();

switch (result.status) {
  case StoreVersionStatus.updateAvailable: // result.storeVersion, result.storeUrl
  case StoreVersionStatus.upToDate:
  case StoreVersionStatus.unknown:         // offline / not listed / layout changed: stay quiet
}
```

### 2. Once per app session (typical splash screen)

"Session" means the **instance**: create one `StoreVersionChecker` for the app's lifetime (provider, singleton,
long-lived service), not one per screen or per call, or each instance will do its own first check.

```dart
class SplashManager {
  final _checker = StoreVersionChecker();   // one instance for the whole session

  Future<void> start() async {
    final result = await _checker.checkOncePerSession(); // null after the first call
    if (result != null && result.isUpdateAvailable) {
      await showUpdateDialog(result);       // await it BEFORE navigating away
    }
    navigateToHome();
  }
}
```

> Await the dialog before `pushReplacement`; replacing the route while it is open removes the dialog.

### 3. Different Android / iOS ids

```dart
StoreVersionChecker(
  androidPackageName: 'com.company.app',
  iosBundleId: 'com.company.app.ios',
  countryCode: 'eg',                        // optional, defaults to the device locale
  allowGlobalStorefrontFallback: true,      // iOS: if the app is not listed in that country, use the global
                                            // version; false reports `unknown` instead
  timeout: const Duration(seconds: 5),      // budget of the WHOLE check (including the fallback request)
);
```

By default both ids are read from the installed app, so most apps need no arguments.

### 4. Open the store

```dart
await launchUrl(Uri.parse(result.storeUrl!), mode: LaunchMode.externalApplication);
```

On iOS `storeUrl` is the exact `trackViewUrl` the App Store returned.

### 5. Do not fail silently (recommended)

```dart
StoreVersionChecker(
  onError: (error, stack) => FirebaseCrashlytics.instance.recordError(error, stack, fatal: false),
);
```

The Play Store check parses a web page; reporting failures tells you the day Google changes it.

### 6. Test it

```dart
// UI testing on any build: always "update available"
StoreVersionChecker.simulated(storeVersion: '99.0.0');

// "up to date" path
StoreVersionChecker.simulated(storeVersion: '1.0.0', currentVersionOverride: '1.0.0');

// unit tests with your own HTTP responses
StoreVersionChecker(
  client: MockClient((_) async => http.Response('x[[["2.0.0"]]y', 200)),
  currentVersionOverride: '1.0.0',
  platformOverride: TargetPlatform.android,
);
```

Gate the simulated checker behind `kDebugMode` or a flavor so it never ships:

```dart
final checker = kDebugMode ? StoreVersionChecker.simulated(storeVersion: '99.0.0') : StoreVersionChecker();
```

## How it works

| Platform | Source | Reliability |
|---|---|---|
| iOS | `https://itunes.apple.com/lookup?bundleId=…&country=…` (Apple's public API; retried without country) | High |
| Android | The public Google Play app page, parsed for the version (`PlayStoreParser`) | Medium: no official API exists. Tested against real page fixtures, plus a weekly CI canary that fails when Google changes the page |

Versions are compared numerically segment by segment (`1.10.0 > 1.9.0`); `+build` numbers, pre-release tags and a
leading `v` are ignored; `1.2` equals `1.2.0`.

## Benefits

- Zero native code and zero permissions; works on every build type.
- One API for Android and iOS, your own UI, your own copy and localisation.
- Never throws, bounded by a timeout, so it cannot stall a splash screen.
- Testable by design (simulated versions, injectable `http.Client`, overridable platform and version).

## Risks and limitations (read this)

1. **Google Play has no official version API.** The Android check parses the Play web page. Google can change its
   markup at any time and the check will then return `unknown` until the parser is updated. Pin a version, use
   `onError` reporting, and treat `unknown` as "do not prompt".
   A version that cannot be parsed (store or installed) is reported as `unknown`, never as "up to date".
2. **Play may not serve the page** in some regions or to some networks (consent walls, rate limiting). Same
   outcome: `unknown`.
3. **Store propagation lag.** The store can show a new version hours before every device can install it, so a
   user may be told to update and see no "Update" button yet. Treat the prompt as a gentle nudge.
4. **Not a forced-update mechanism.** The client decides, so it can be bypassed. For mandatory updates use a
   minimum-version value from your own backend / Remote Config in addition.
5. **Staged rollouts and country availability.** The store version may be higher than what a given user can get.
6. **iOS version scheme.** The lookup reports the marketing version (`CFBundleShortVersionString`), so compare
   marketing versions, not build numbers.
7. **Apple / Google policies.** Prompting to update is allowed; do not block usage of an app behind it in ways the
   store guidelines discourage.
8. **Web and desktop are unsupported** and return `unknown`.

## API summary

| Member | Purpose |
|---|---|
| `StoreVersionChecker(...)` | Real store check |
| `StoreVersionChecker.simulated(storeVersion: ...)` | Fake store version, no network |
| `check()` | One check |
| `checkOncePerSession()` | First call returns a result, later calls return `null` |
| `StoreVersionResult` | `status`, `currentVersion`, `storeVersion`, `storeUrl`, `error`, `simulated` |
| `VersionComparator` | `compare`, `isNewer`, `parse` |
| `PlayStoreParser.parseVersion(html)` | The parser, public for your own tests |

## License

MIT
