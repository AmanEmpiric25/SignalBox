import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalbox/core/constants/app_constants.dart';
import 'package:signalbox/features/settings/data/settings_repository.dart';

void main() {
  late SettingsRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = SettingsRepository(await SharedPreferences.getInstance());
  });

  test('defaults are returned for an empty store', () {
    final settings = repository.load();
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.retentionDays, AppConstants.defaultRetentionDays);
    expect(settings.hidePreviewContent, isFalse);
    expect(settings.groupByApp, isFalse);
    expect(settings.dailySummaryEnabled, isFalse);
  });

  test('theme mode survives a reload', () async {
    await repository.saveThemeMode(ThemeMode.dark);
    expect(repository.load().themeMode, ThemeMode.dark);

    await repository.saveThemeMode(ThemeMode.light);
    expect(repository.load().themeMode, ThemeMode.light);
  });

  test('an unknown theme mode name falls back to system', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PrefKeys.themeMode: 'solarized',
    });
    final reloaded = SettingsRepository(await SharedPreferences.getInstance());
    expect(reloaded.load().themeMode, ThemeMode.system);
  });

  test('hide previews survives a reload', () async {
    await repository.saveHidePreviewContent(true);
    expect(repository.load().hidePreviewContent, isTrue);
  });

  test('group by app survives a reload', () async {
    await repository.saveGroupByApp(true);
    expect(repository.load().groupByApp, isTrue);
  });

  test('daily summary survives a reload', () async {
    await repository.saveDailySummaryEnabled(true);
    expect(repository.load().dailySummaryEnabled, isTrue);
  });

  test('saveRetentionDays writes to the shared preference key', () async {
    final prefs = await SharedPreferences.getInstance();
    await repository.saveRetentionDays(90);
    expect(prefs.getInt(PrefKeys.retentionDays), 90);
  });

  test('clearAll resets everything to defaults', () async {
    await repository.saveThemeMode(ThemeMode.dark);
    await repository.saveHidePreviewContent(true);
    await repository.clearAll();

    final settings = repository.load();
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.hidePreviewContent, isFalse);
  });
}
