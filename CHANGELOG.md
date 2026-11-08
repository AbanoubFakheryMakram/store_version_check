## 0.1.4

- README: the `MockClient` example now uses the current Play page structure (version followed by the minimum-SDK
  block) and is covered by a test.

## 0.1.3

- Docs: README now shows samples of the App Store lookup response and the Google Play page entry that are parsed
  (`doc/samples/`).
- `timeout` now also covers reading the installed version (`PackageInfo`), so it bounds the entire `check()`.
- README installation example updated to the current version.
- Test fixtures and samples are now synthetic (mock ids and text, real structure) instead of trimmed real pages.
- Removed the CI workflow and the live Google Play canary test.

## 0.1.2

- README: removed a comparison row that overstated the difference with Play Core based packages.

## 0.1.1

- Google Play: the version is now only accepted when followed by the minimum-SDK block, so an unrelated
  version-like array on the page can no longer be picked up. Verified against real pages (fixtures added).
- `onError` can no longer break `check()`: an exception thrown by it is swallowed and the result stays `unknown`.
- An unparseable installed / store / simulated version now ends as `unknown` instead of `upToDate`
  (`VersionComparator.isValid` added).
- `timeout` now covers the whole check, including the iOS storefront fallback request.
- New `allowGlobalStorefrontFallback` (iOS, default `true`): set it to `false` to report `unknown` when the app
  is not listed in the user's storefront instead of using the global version.
- Clearer `checkOncePerSession` docs: "session" means the instance, keep one for the app's lifetime.

## 0.1.0

- Initial release: App Store (iTunes lookup) and Google Play (page parsing) version checks.
- `StoreVersionChecker.check()` and `checkOncePerSession()`.
- `StoreVersionChecker.simulated(...)` for testing without publishing anything.
- `VersionComparator` with tolerant parsing (`1.2.3+4`, `1.2`, `v2.0.0-beta`).
