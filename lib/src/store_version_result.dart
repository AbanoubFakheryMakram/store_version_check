/// The outcome of a store version check.
enum StoreVersionStatus {
  /// The store has a higher version than the installed one.
  updateAvailable,

  /// The installed version is the same as, or newer than, the store version.
  upToDate,

  /// The check could not be completed (offline, timeout, store layout changed, app not listed...).
  /// Treat this as "do not bother the user".
  unknown,
}

/// What [StoreVersionChecker.check] found.
class StoreVersionResult {
  /// Creates a result.
  const StoreVersionResult({
    required this.status,
    this.currentVersion,
    this.storeVersion,
    this.storeUrl,
    this.error,
    this.simulated = false,
  });

  /// Whether an update is available, the app is current, or the answer is unknown.
  final StoreVersionStatus status;

  /// Version of the installed app, e.g. `1.2.1`.
  final String? currentVersion;

  /// Version currently published in the store, e.g. `1.3.0`.
  final String? storeVersion;

  /// Store page of the app, ready for `launchUrl`.
  final String? storeUrl;

  /// Why the check ended as [StoreVersionStatus.unknown], when it did.
  final Object? error;

  /// `true` when the store version was supplied by [StoreVersionChecker.simulated], not fetched.
  final bool simulated;

  /// Shortcut for `status == StoreVersionStatus.updateAvailable`.
  bool get isUpdateAvailable => status == StoreVersionStatus.updateAvailable;

  @override
  String toString() =>
      'StoreVersionResult($status, current: $currentVersion, store: $storeVersion, simulated: $simulated)';
}
