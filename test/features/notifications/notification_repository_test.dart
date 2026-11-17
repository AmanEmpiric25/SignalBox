import 'package:flutter_test/flutter_test.dart';
import 'package:signalbox/features/notifications/data/notification_repository.dart';
import 'package:signalbox/features/notifications/domain/notification_filter.dart';
import 'package:signalbox/shared/models/notification_item.dart';
import 'package:signalbox/shared/models/notification_priority.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(initTestDatabase);

  late Database db;
  late NotificationRepository repository;

  setUp(() async {
    db = await openTestDatabase();
    repository = NotificationRepository(db);
  });

  tearDown(() async => db.close());

  NotificationItem build({
    String package = 'com.whatsapp',
    String title = 'Hello',
    String body = 'World',
    DateTime? postedAt,
    NotificationPriority priority = NotificationPriority.normal,
    bool isRead = false,
    bool isArchived = false,
  }) {
    return NotificationItem(
      id: 0,
      packageName: package,
      title: title,
      body: body,
      postedAt: postedAt ?? DateTime.now(),
      priority: priority,
      isRead: isRead,
      isArchived: isArchived,
    );
  }

  group('insert and read', () {
    test('an inserted notification can be read back', () async {
      final id = await repository.insert(
        build(title: 'Payment received', body: 'INR 2,400 credited'),
      );

      final stored = await repository.byId(id);
      expect(stored, isNotNull);
      expect(stored!.title, 'Payment received');
      expect(stored.body, 'INR 2,400 credited');
      expect(stored.packageName, 'com.whatsapp');
      expect(stored.isRead, isFalse);
    });

    test('byId returns null for an unknown id', () async {
      expect(await repository.byId(4242), isNull);
    });

    test('postedAt survives the round trip to the second', () async {
      final posted = DateTime(2026, 3, 12, 9, 30, 15);
      final id = await repository.insert(build(postedAt: posted));
      final stored = await repository.byId(id);
      expect(stored!.postedAt, posted);
    });
  });

  group('counting', () {
    test('count reflects the number of stored notifications', () async {
      await repository.insert(build());
      await repository.insert(build(title: 'Second'));
      expect(await repository.count(), 2);
    });

    test('archived notifications are excluded by default', () async {
      await repository.insert(build());
      await repository.insert(build(title: 'Old', isArchived: true));
      expect(await repository.count(), 1);
      expect(
        await repository.count(
          filter: const NotificationFilter(includeArchived: true),
        ),
        2,
      );
    });

    test('unreadCount ignores read and archived rows', () async {
      await repository.insert(build());
      await repository.insert(build(title: 'Read', isRead: true));
      await repository.insert(build(title: 'Archived', isArchived: true));
      expect(await repository.unreadCount(), 1);
    });
  });

  group('paging', () {
    test('page returns at most limit rows', () async {
      for (var i = 0; i < 5; i++) {
        await repository.insert(
          build(title: 'Item $i', postedAt: DateTime(2026, 3, 12, 9, i)),
        );
      }
      final first = await repository.page(limit: 2, offset: 0);
      expect(first, hasLength(2));
    });

    test('page returns the newest notification first', () async {
      await repository.insert(
        build(title: 'Older', postedAt: DateTime(2026, 3, 12, 9)),
      );
      await repository.insert(
        build(title: 'Newer', postedAt: DateTime(2026, 3, 12, 11)),
      );

      final page = await repository.page(limit: 10, offset: 0);
      expect(page.first.title, 'Newer');
    });
  });

  group('sorting', () {
    test('all() is ordered newest first', () async {
      await repository.insert(
        build(title: 'A', postedAt: DateTime(2026, 3, 10, 9)),
      );
      await repository.insert(
        build(title: 'B', postedAt: DateTime(2026, 3, 12, 9)),
      );
      await repository.insert(
        build(title: 'C', postedAt: DateTime(2026, 3, 11, 9)),
      );

      final items = await repository.all();
      expect(items.map((i) => i.title).toList(), ['B', 'C', 'A']);
    });

    test('all() breaks ties deterministically', () async {
      final tie = DateTime(2026, 3, 12, 14);
      await repository.insert(build(title: 'First inserted', postedAt: tie));
      await repository.insert(build(title: 'Second inserted', postedAt: tie));

      final once = await repository.all();
      final twice = await repository.all();
      expect(once.map((i) => i.id).toList(), twice.map((i) => i.id).toList());
    });
  });

  group('filtering', () {
    test('filters by package name', () async {
      await repository.insert(build(package: 'com.whatsapp'));
      await repository.insert(build(package: 'com.slack'));

      final items = await repository.all(
        filter: const NotificationFilter(packageNames: {'com.slack'}),
      );
      expect(items, hasLength(1));
      expect(items.single.packageName, 'com.slack');
    });

    test('filters by priority', () async {
      await repository.insert(build(priority: NotificationPriority.high));
      await repository.insert(build(priority: NotificationPriority.low));

      final items = await repository.all(
        filter: const NotificationFilter(
          priorities: {NotificationPriority.high},
        ),
      );
      expect(items, hasLength(1));
      expect(items.single.priority, NotificationPriority.high);
    });

    test('onlyUnread hides read notifications', () async {
      await repository.insert(build());
      await repository.insert(build(title: 'Seen', isRead: true));

      final items = await repository.all(
        filter: const NotificationFilter(onlyUnread: true),
      );
      expect(items, hasLength(1));
      expect(items.single.isRead, isFalse);
    });

    test('search matches text in the title', () async {
      await repository.insert(build(title: 'Invoice for November'));
      await repository.insert(build(title: 'Priya Sharma'));

      final items = await repository.all(
        filter: const NotificationFilter(query: 'invoice'),
      );
      expect(items, hasLength(1));
      expect(items.single.title, 'Invoice for November');
    });

    test('search is case insensitive', () async {
      await repository.insert(build(title: 'Invoice for November'));
      final items = await repository.all(
        filter: const NotificationFilter(query: 'INVOICE'),
      );
      expect(items, hasLength(1));
    });

    test('search matches text in the body', () async {
      await repository.insert(
        build(
          title: 'Payment received',
          body: 'Your UPI transaction of INR 2,400 was credited successfully.',
        ),
      );
      await repository.insert(build(title: 'Priya Sharma', body: 'On my way'));

      final items = await repository.all(
        filter: const NotificationFilter(query: 'UPI'),
      );
      expect(items, hasLength(1));
      expect(items.single.title, 'Payment received');
    });

    test('a body match is case insensitive too', () async {
      await repository.insert(
        build(title: 'Payment received', body: 'UPI transaction credited'),
      );

      final items = await repository.all(
        filter: const NotificationFilter(query: 'upi'),
      );
      expect(items, hasLength(1));
    });

    test('search returns nothing when neither field matches', () async {
      await repository.insert(build(title: 'Payment received', body: 'UPI'));
      await repository.insert(build(title: 'Priya Sharma', body: 'On my way'));

      final items = await repository.all(
        filter: const NotificationFilter(query: 'zomato'),
      );
      expect(items, isEmpty);
    });

    test('a percent sign in the query is matched literally', () async {
      await repository.insert(build(title: 'Flat 20% off today', body: 'Sale'));
      await repository.insert(build(title: 'Priya Sharma', body: 'On my way'));

      final items = await repository.all(
        filter: const NotificationFilter(query: '%'),
      );
      expect(items, hasLength(1));
      expect(items.single.title, 'Flat 20% off today');
    });

    test('an underscore in the query is matched literally', () async {
      await repository.insert(build(title: 'build_failed', body: 'Job 12'));
      // Would also match if `_` were still treated as a single-character
      // wildcard, which is what makes this a regression test.
      await repository.insert(build(title: 'buildXfailed', body: 'Job 13'));

      final items = await repository.all(
        filter: const NotificationFilter(query: 'd_f'),
      );
      expect(items, hasLength(1));
      expect(items.single.title, 'build_failed');
    });

    test('a whitespace-only query returns every notification', () async {
      await repository.insert(build(title: 'Payment received'));
      await repository.insert(build(title: 'Priya Sharma'));

      final items = await repository.all(
        filter: const NotificationFilter(query: '   '),
      );
      expect(items, hasLength(2));
    });
  });

  group('mutations', () {
    test('setRead flips the read flag', () async {
      final id = await repository.insert(build());
      await repository.setRead(id);
      expect((await repository.byId(id))!.isRead, isTrue);
      await repository.setRead(id, isRead: false);
      expect((await repository.byId(id))!.isRead, isFalse);
    });

    test('setArchived removes the row from the default view', () async {
      final id = await repository.insert(build());
      await repository.setArchived(id);
      expect(await repository.count(), 0);
    });

    test('setPriority persists the new priority', () async {
      final id = await repository.insert(build());
      await repository.setPriority(id, NotificationPriority.high);
      expect((await repository.byId(id))!.priority, NotificationPriority.high);
    });

    test('delete removes the row', () async {
      final id = await repository.insert(build());
      await repository.delete(id);
      expect(await repository.byId(id), isNull);
    });

    test('deleteMany removes every listed row', () async {
      final a = await repository.insert(build(title: 'A'));
      final b = await repository.insert(build(title: 'B'));
      final c = await repository.insert(build(title: 'C'));

      await repository.deleteMany([a, b]);
      expect(await repository.count(), 1);
      expect((await repository.byId(c))!.title, 'C');
    });

    test('deleteMany on an empty list is a no-op', () async {
      await repository.insert(build());
      await repository.deleteMany(const <int>[]);
      expect(await repository.count(), 1);
    });
  });

  group('snoozing', () {
    test('snooze stores a future wake-up time', () async {
      final id = await repository.insert(build());
      await repository.snooze(id, const Duration(hours: 2));

      final stored = await repository.byId(id);
      expect(stored!.snoozeUntil, isNotNull);
      expect(stored.snoozeUntil!.isAfter(DateTime.now()), isTrue);
    });

    test('snoozed() lists notifications whose window is still open', () async {
      final id = await repository.insert(build());
      await repository.insert(build(title: 'Not snoozed'));
      await repository.snooze(id, const Duration(hours: 2));

      final snoozed = await repository.snoozed();
      expect(snoozed, hasLength(1));
      expect(snoozed.single.id, id);
    });

    test('snoozed() excludes expired snoozes', () async {
      final id = await repository.insert(build());
      await repository.snooze(id, const Duration(hours: -2));
      expect(await repository.snoozed(), isEmpty);
    });

    test('clearSnooze removes the wake-up time', () async {
      final id = await repository.insert(build());
      await repository.snooze(id, const Duration(hours: 2));
      await repository.clearSnooze(id);
      expect((await repository.byId(id))!.snoozeUntil, isNull);
    });
  });

  group('retention', () {
    test('deleteOlderThan removes rows past the cutoff', () async {
      await repository.insert(
        build(
          title: 'Ancient',
          postedAt: DateTime.now().subtract(const Duration(days: 60)),
        ),
      );
      await repository.insert(build(title: 'Fresh'));

      final removed = await repository.deleteOlderThan(30);
      expect(removed, 1);

      final remaining = await repository.all();
      expect(remaining, hasLength(1));
      expect(remaining.single.title, 'Fresh');
    });

    test('deleteAll empties the table', () async {
      await repository.insert(build());
      await repository.insert(build(title: 'Second'));
      await repository.deleteAll();
      expect(await repository.count(), 0);
    });
  });
}
