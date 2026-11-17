import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/preferences_provider.dart';
import '../../data/settings_repository.dart';
import '../../domain/app_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

/// Current user preferences. Every write persists immediately.
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _repository.saveThemeMode(mode);
  }

  Future<void> setRetentionDays(int days) async {
    state = state.copyWith(retentionDays: days);
    await _repository.saveRetentionDays(days);
  }

  Future<void> setHidePreviewContent(bool value) async {
    state = state.copyWith(hidePreviewContent: value);
    await _repository.saveHidePreviewContent(value);
  }

  Future<void> setGroupByApp(bool value) async {
    state = state.copyWith(groupByApp: value);
    await _repository.saveGroupByApp(value);
  }

  Future<void> setDailySummaryEnabled(bool value) async {
    state = state.copyWith(dailySummaryEnabled: value);
    await _repository.saveDailySummaryEnabled(value);
  }
}
