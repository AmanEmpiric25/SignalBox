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
  }) {
    return notifications.insert(
      NotificationItem(
        id: 0,
        packageName: package,
        title: 'Title',
        body: 'Body',
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
}
