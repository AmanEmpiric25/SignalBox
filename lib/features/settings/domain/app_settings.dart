import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// User preferences, persisted with `SharedPreferences`.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.retentionDays = AppConstants.defaultRetentionDays,
    this.hidePreviewContent = false,
    this.groupByApp = false,
    this.dailySummaryEnabled = false,
  });

  final ThemeMode themeMode;

  /// How many days of history to keep. `0` means keep everything.
  final int retentionDays;

  /// Hides notification bodies in lists, for shoulder-surfing protection.
  final bool hidePreviewContent;

  /// Groups the inbox by application instead of by day.
  final bool groupByApp;

  /// Whether the daily summary notification is scheduled.
  final bool dailySummaryEnabled;

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? retentionDays,
    bool? hidePreviewContent,
    bool? groupByApp,
    bool? dailySummaryEnabled,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    retentionDays: retentionDays ?? this.retentionDays,
    hidePreviewContent: hidePreviewContent ?? this.hidePreviewContent,
    groupByApp: groupByApp ?? this.groupByApp,
    dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.retentionDays == retentionDays &&
      other.hidePreviewContent == hidePreviewContent &&
      other.groupByApp == groupByApp &&
      other.dailySummaryEnabled == dailySummaryEnabled;

  @override
  int get hashCode => Object.hash(
    themeMode,
    retentionDays,
    hidePreviewContent,
    groupByApp,
    dailySummaryEnabled,
  );
}
