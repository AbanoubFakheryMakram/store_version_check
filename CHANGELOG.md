## 0.1.0

- Initial release: App Store (iTunes lookup) and Google Play (page parsing) version checks.
- `StoreVersionChecker.check()` and `checkOncePerSession()`.
- `StoreVersionChecker.simulated(...)` for testing without publishing anything.
- `VersionComparator` with tolerant parsing (`1.2.3+4`, `1.2`, `v2.0.0-beta`).
