/// Application-wide constants.
///
/// Keep this file small: only values that are genuinely shared across
/// features belong here.
class AppConstants {
  const AppConstants._();

  static const String appName = 'SignalBox';
  static const String databaseFileName = 'signalbox.sqlite';

  /// Number of notifications fetched per inbox page.
  static const int inboxPageSize = 20;

  /// Default number of days of notification history that is kept.
  static const int defaultRetentionDays = 30;

  /// Snooze presets offered in the UI, in minutes.
  static const List<int> snoozePresetsMinutes = <int>[15, 60, 180, 480];
}

/// Preference keys used by [SharedPreferences].
///
/// NOTE: every key must be read and written through this class so that the
/// reader and the writer can never drift apart.
class PrefKeys {
  const PrefKeys._();

  static const String themeMode = 'settings.theme_mode';
  static const String retentionDays = 'settings.retention_days';
  static const String hidePreviewContent = 'settings.hide_preview_content';
  static const String groupByApp = 'settings.group_by_app';
  static const String dailySummaryEnabled = 'settings.daily_summary_enabled';
}
