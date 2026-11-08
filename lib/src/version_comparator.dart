/// Compares dotted app versions such as `1.2.3`, `1.2`, `1.2.3+45` or `v2.0.0-beta`.
class VersionComparator {
  const VersionComparator._();

  /// Parses [version] into its numeric segments. The build number (`+45`), a pre-release tag (`-beta`)
  /// and a leading `v` are ignored. Returns an empty list when nothing numeric is found.
  static List<int> parse(String version) {
    final core = version.trim().toLowerCase().replaceFirst(RegExp(r'^v'), '').split(RegExp(r'[+\-]')).first;
    final segments = <int>[];
    for (final part in core.split('.')) {
      final value = int.tryParse(part);
      if (value == null) return const [];
      segments.add(value);
    }
    return segments;
  }

  /// Whether [version] has at least one numeric segment and can be compared.
  static bool isValid(String version) => parse(version).isNotEmpty;

  /// Compares [a] to [b]: negative when [a] is older, zero when equal, positive when [a] is newer.
  /// Missing segments count as zero, so `1.2` equals `1.2.0`. Unparseable input compares as equal.
  static int compare(String a, String b) {
    final left = parse(a);
    final right = parse(b);
    if (left.isEmpty || right.isEmpty) return 0;
    for (var i = 0; i < left.length || i < right.length; i++) {
      final x = i < left.length ? left[i] : 0;
      final y = i < right.length ? right[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  /// Whether [store] is a higher version than [current].
  static bool isNewer(String store, String current) => compare(store, current) > 0;
}
