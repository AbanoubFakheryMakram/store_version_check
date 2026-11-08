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
- CI: format, analyze, tests, publish dry-run, plus a weekly canary against the real Google Play page.

## 0.1.0

- Initial release: App Store (iTunes lookup) and Google Play (page parsing) version checks.
- `StoreVersionChecker.check()` and `checkOncePerSession()`.
- `StoreVersionChecker.simulated(...)` for testing without publishing anything.
- `VersionComparator` with tolerant parsing (`1.2.3+4`, `1.2`, `v2.0.0-beta`).
