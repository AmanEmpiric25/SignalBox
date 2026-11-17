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

  test('retention survives a reload', () async {
    await repository.saveRetentionDays(90);
    expect(repository.load().retentionDays, 90);
  });

  test(
    'every setting is read back through the key it was written to',
    () async {
      await repository.saveThemeMode(ThemeMode.dark);
      await repository.saveRetentionDays(90);
      await repository.saveHidePreviewContent(true);
      await repository.saveGroupByApp(true);
      await repository.saveDailySummaryEnabled(true);

      // B10 was a save and a load disagreeing about one key. Asserting the
      // round trip for every setting at once is what makes that class of bug
      // fail here instead of on a user's device after a restart.
      final restarted = SettingsRepository(
        await SharedPreferences.getInstance(),
      );
      final settings = restarted.load();

      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.retentionDays, 90);
      expect(settings.hidePreviewContent, isTrue);
      expect(settings.groupByApp, isTrue);
      expect(settings.dailySummaryEnabled, isTrue);
    },
  );

  test('Forever round-trips and is not mistaken for an absent value', () async {
    await repository.saveRetentionDays(0);

    // 0 means Forever. A fallback written as `value == 0 ? default : value`
    // would silently turn Forever into 30 days, so this is worth pinning.
    expect(repository.load().retentionDays, 0);
    expect(
      repository.load().retentionDays,
      isNot(AppConstants.defaultRetentionDays),
    );
  });

  test('retention uses the PrefKeys key and no other', () async {
    final prefs = await SharedPreferences.getInstance();
    await repository.saveRetentionDays(90);

    expect(prefs.getKeys(), contains(PrefKeys.retentionDays));
    // The key the buggy read used. Nothing should ever write it.
    expect(prefs.getKeys(), isNot(contains('settings.retentionDays')));
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
