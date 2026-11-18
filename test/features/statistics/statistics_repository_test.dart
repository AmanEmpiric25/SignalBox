import 'package:flutter_test/flutter_test.dart';
import 'package:signalbox/features/notifications/data/notification_repository.dart';
import 'package:signalbox/features/notifications/domain/notification_filter.dart';
import 'package:signalbox/features/statistics/data/statistics_repository.dart';
import 'package:signalbox/shared/models/notification_item.dart';
import 'package:signalbox/shared/models/notification_priority.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(initTestDatabase);

  late Database db;
  late NotificationRepository notifications;
  late StatisticsRepository statistics;

  setUp(() async {
    db = await openTestDatabase();
    notifications = NotificationRepository(db);
    statistics = StatisticsRepository(db);

    await db.insert('app_sources', {
      'package_name': 'com.whatsapp',
      'app_label': 'WhatsApp',
      'is_muted': 0,
      'first_seen_at': DateTime.now().millisecondsSinceEpoch,
    });
  });

  tearDown(() async => db.close());

  Future<void> seed({
    String package = 'com.whatsapp',
    NotificationPriority priority = NotificationPriority.normal,
    bool isRead = false,
    int? categoryId,
    DateTime? postedAt,
    String title = 'Title',
    String body = 'Body',
  }) {
    return notifications.insert(
      NotificationItem(
        id: 0,
        packageName: package,
        title: title,
        body: body,
        postedAt: postedAt ?? DateTime.now(),
        priority: priority,
        categoryId: categoryId,
        isRead: isRead,
      ),
    );
  }

  test('empty database produces zeroed statistics', () async {
    final stats = await statistics.load(NotificationFilter.empty);
    expect(stats.total, 0);
    expect(stats.unread, 0);
    expect(stats.perApp, isEmpty);
    expect(stats.perDay, isEmpty);
  });

  test('unread counts only unread notifications', () async {
    await seed();
    await seed();
    await seed(isRead: true);

    final stats = await statistics.load(NotificationFilter.empty);
    expect(stats.unread, 2);
  });

  test('perApp groups by package and resolves the app label', () async {
    await seed();
    await seed();
    await seed(package: 'com.slack');

    final stats = await statistics.load(NotificationFilter.empty);
    expect(stats.perApp, hasLength(2));

    final whatsapp = stats.perApp.firstWhere(
      (a) => a.packageName == 'com.whatsapp',
    );
    expect(whatsapp.count, 2);
    expect(whatsapp.appLabel, 'WhatsApp');

    // Unknown packages fall back to the package name.
    final slack = stats.perApp.firstWhere((a) => a.packageName == 'com.slack');
    expect(slack.appLabel, 'com.slack');
  });

  test('perApp is ordered by descending volume', () async {
    await seed(package: 'com.slack');
    await seed();
    await seed();
    await seed();

    final stats = await statistics.load(NotificationFilter.empty);
    expect(stats.perApp.first.packageName, 'com.whatsapp');
  });

  test('perPriority counts each bucket', () async {
    await seed(priority: NotificationPriority.high);
    await seed(priority: NotificationPriority.high);
    await seed(priority: NotificationPriority.low);

    final stats = await statistics.load(NotificationFilter.empty);
    expect(stats.perPriority[NotificationPriority.high], 2);
    expect(stats.perPriority[NotificationPriority.low], 1);
    expect(stats.perPriority[NotificationPriority.normal], isNull);
  });

  test('perCategory labels uncategorised notifications', () async {
    await seed();
    final stats = await statistics.load(NotificationFilter.empty);
    expect(stats.perCategory, hasLength(1));
    expect(stats.perCategory.single.name, 'Uncategorised');
    expect(stats.perCategory.single.categoryId, isNull);
  });

  test('perCategory resolves seeded system categories', () async {
    final categories = await db.query(
      'categories',
      where: 'name = ?',
      whereArgs: ['Messages'],
    );
    final messagesId = categories.single['id'] as int;

    await seed(categoryId: messagesId);
    await seed(categoryId: messagesId);

    final stats = await statistics.load(NotificationFilter.empty);
    final messages = stats.perCategory.firstWhere(
      (c) => c.categoryId == messagesId,
    );
    expect(messages.name, 'Messages');
    expect(messages.count, 2);
  });

  test('perDay groups notifications by calendar day', () async {
    final today = DateTime.now();
    await seed(postedAt: today);
    await seed(postedAt: today);

    final stats = await statistics.load(NotificationFilter.empty);
    expect(stats.perDay, hasLength(1));
    expect(stats.perDay.single.count, 2);
  });

  test('a Last 7 days range counts notifications posted today', () async {
    // Mirrors what `statisticsProvider` builds for StatsRange.last7Days: the
    // range ends at "now", so an exclusive upper bound would drop today.
    final now = DateTime.now();
    await seed(postedAt: DateTime(now.year, now.month, now.day, 8));
    await seed(postedAt: now.subtract(const Duration(days: 2)));

    final stats = await statistics.load(
      NotificationFilter(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
    );

    expect(stats.total, 2);
    expect(stats.perDay, hasLength(2));
  });

  test('busiestDayCount and dailyAverage derive from perDay', () async {
    final today = DateTime.now();
    await seed(postedAt: today);
    await seed(postedAt: today);
    await seed(postedAt: today.subtract(const Duration(days: 2)));

    final stats = await statistics.load(NotificationFilter.empty);
    expect(stats.busiestDayCount, 2);
    expect(stats.dailyAverage, closeTo(1.5, 0.001));
  });

  test('package filter narrows the per-app breakdown', () async {
    await seed();
    await seed(package: 'com.slack');

    final stats = await statistics.load(
      const NotificationFilter(packageNames: {'com.slack'}),
    );
    expect(stats.perApp, hasLength(1));
    expect(stats.perApp.single.packageName, 'com.slack');
  });

  test('a search query narrows the per-app breakdown by body text', () async {
    await db.insert('app_sources', {
      'package_name': 'com.slack',
      'app_label': 'Slack',
      'is_muted': 0,
      'first_seen_at': DateTime.now().millisecondsSinceEpoch,
    });
    await seed(title: 'Payment received', body: 'UPI transaction credited');
    await seed(package: 'com.slack', title: 'Priya Sharma', body: 'On my way');

    // StatisticsRepository is the only caller that passes `alias: 'n'`, so this
    // exercises the qualified-column form of the search clause.
    final stats = await statistics.load(const NotificationFilter(query: 'UPI'));
    expect(stats.perApp, hasLength(1));
    expect(stats.perApp.single.packageName, 'com.whatsapp');
    expect(stats.perApp.single.count, 1);
  });

  test('a search query narrows the per-category breakdown', () async {
    await seed(title: 'Payment received', body: 'UPI transaction credited');
    await seed(title: 'Priya Sharma', body: 'On my way');

    final stats = await statistics.load(const NotificationFilter(query: 'UPI'));
    final counted = stats.perCategory.where((c) => c.count > 0).toList();
    expect(counted, hasLength(1));
    expect(counted.single.count, 1);
  });

  test('a muted application is still counted in statistics', () async {
    // Muting keeps an app out of the inbox; it does not erase it from the
    // history. If this ever starts failing, the mute clause has leaked out of
    // the inbox queries into the aggregates.
    await db.update(
      'app_sources',
      {'is_muted': 1},
      where: 'package_name = ?',
      whereArgs: ['com.whatsapp'],
    );
    await seed();
    await seed();

    final stats = await statistics.load(NotificationFilter.empty);
    expect(stats.total, 2);
    expect(stats.perApp.single.count, 2);
  });

  group('total respects the filter', () {
    test('a package filter changes the total', () async {
      await db.insert('app_sources', {
        'package_name': 'com.slack',
        'app_label': 'Slack',
        'is_muted': 0,
        'first_seen_at': DateTime.now().millisecondsSinceEpoch,
      });
      await seed(package: 'com.whatsapp');
      await seed(package: 'com.whatsapp');
      await seed(package: 'com.slack');

      final all = await statistics.load(NotificationFilter.empty);
      final slack = await statistics.load(
        const NotificationFilter(packageNames: {'com.slack'}),
      );

      expect(all.total, 3);
      expect(slack.total, 1);
    });

    test('the total equals the summed perDay counts', () async {
      await seed(postedAt: DateTime(2026, 3, 10, 9));
      await seed(postedAt: DateTime(2026, 3, 11, 9));
      await seed(postedAt: DateTime(2026, 3, 11, 10));

      // The end bound is the 12th, not the 11th, so this holds whether or not
      // B2 (#37) has landed: the 11th's two rows are inside the range and the
      // 10th's row is outside it under either end-of-day behaviour.
      final stats = await statistics.load(
        NotificationFilter(
          start: DateTime(2026, 3, 11),
          end: DateTime(2026, 3, 12),
        ),
      );

      final summed = stats.perDay.fold(0, (sum, day) => sum + day.count);
      expect(stats.total, summed);
      expect(stats.total, 2);
    });

    test('the total equals the summed perPriority counts', () async {
      await seed(priority: NotificationPriority.high);
      await seed(priority: NotificationPriority.low);
      await seed(priority: NotificationPriority.normal);

      final stats = await statistics.load(NotificationFilter.empty);
      final summed = stats.perPriority.values.fold(0, (sum, c) => sum + c);
      expect(stats.total, summed);
    });

    test('a search query narrows the total', () async {
      await seed(title: 'Payment received');
      await seed(title: 'Priya Sharma');

      final stats = await statistics.load(
        const NotificationFilter(query: 'Payment'),
      );
      expect(stats.total, 1);
    });

    test('an empty result set reports a total of 0', () async {
      await seed(title: 'Payment received');

      final stats = await statistics.load(
        const NotificationFilter(query: 'nothing matches this'),
      );
      expect(stats.total, 0);
    });

    test('archived notifications stay out of the total by default', () async {
      await seed();
      await notifications.insert(
        NotificationItem(
          id: 0,
          packageName: 'com.whatsapp',
          title: 'Filed',
          body: 'Body',
          postedAt: DateTime.now(),
          priority: NotificationPriority.normal,
          isArchived: true,
        ),
      );

      final stats = await statistics.load(NotificationFilter.empty);
      expect(stats.total, 1);
    });
  });
}
