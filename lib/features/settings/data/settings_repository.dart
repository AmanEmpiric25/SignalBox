import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/app_settings.dart';

/// Loads and stores [AppSettings].
class SettingsRepository {
  const SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  AppSettings load() {
    return AppSettings(
      themeMode: _themeModeFromName(_prefs.getString(PrefKeys.themeMode)),
      retentionDays:
          _prefs.getInt(PrefKeys.retentionDays) ??
          AppConstants.defaultRetentionDays,
      hidePreviewContent: _prefs.getBool(PrefKeys.hidePreviewContent) ?? false,
      groupByApp: _prefs.getBool(PrefKeys.groupByApp) ?? false,
      dailySummaryEnabled:
          _prefs.getBool(PrefKeys.dailySummaryEnabled) ?? false,
    );
  }

  Future<void> saveThemeMode(ThemeMode mode) =>
      _prefs.setString(PrefKeys.themeMode, mode.name);

  Future<void> saveRetentionDays(int days) =>
      _prefs.setInt(PrefKeys.retentionDays, days);

  Future<void> saveHidePreviewContent(bool value) =>
      _prefs.setBool(PrefKeys.hidePreviewContent, value);

  Future<void> saveGroupByApp(bool value) =>
      _prefs.setBool(PrefKeys.groupByApp, value);

  Future<void> saveDailySummaryEnabled(bool value) =>
      _prefs.setBool(PrefKeys.dailySummaryEnabled, value);

  Future<void> clearAll() => _prefs.clear();

  static ThemeMode _themeModeFromName(String? name) => switch (name) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
