extension StringX on String {
  /// Collapses repeated whitespace and trims the result.
  String get normalised => replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Shortens a string for single-line display.
  String truncate(int max) =>
      length <= max ? this : '${substring(0, max).trimRight()}…';

  /// Best-effort human readable label for an Android package name.
  ///
  /// `com.whatsapp` -> `Whatsapp`, `com.google.android.gm` -> `Gm`.
  String get packageLabel {
    final segments = split('.').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return this;
    final last = segments.last;
    return last[0].toUpperCase() + last.substring(1);
  }

  bool get isBlank => normalised.isEmpty;
}
