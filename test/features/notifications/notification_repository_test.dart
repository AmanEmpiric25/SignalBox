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

    test('page() agrees with all() on tied timestamps', () async {
      final tie = DateTime(2026, 3, 12, 14);
      for (var i = 0; i < 6; i++) {
        await repository.insert(build(title: 'Tied $i', postedAt: tie));
      }

      final paged = await repository.page(limit: 10, offset: 0);
      final unpaged = await repository.all();

      expect(
        paged.map((i) => i.id).toList(),
        unpaged.map((i) => i.id).toList(),
      );
    });

    test('page() returns the same order when repeated', () async {
      final tie = DateTime(2026, 3, 12, 14);
      for (var i = 0; i < 6; i++) {
        await repository.insert(build(title: 'Tied $i', postedAt: tie));
      }

      final once = await repository.page(limit: 10, offset: 0);
      final twice = await repository.page(limit: 10, offset: 0);
      expect(once.map((i) => i.id).toList(), twice.map((i) => i.id).toList());
    });

    test('paging tied timestamps neither repeats nor drops a row', () async {
      // The practical damage of a missing tiebreaker: without a stable order
      // SQLite may place a row on both sides of a page boundary, or on neither.
      final tie = DateTime(2026, 3, 12, 14);
      for (var i = 0; i < 10; i++) {
        await repository.insert(build(title: 'Tied $i', postedAt: tie));
      }

      final first = await repository.page(limit: 5, offset: 0);
      final second = await repository.page(limit: 5, offset: 5);
      final ids = [...first, ...second].map((i) => i.id).toList();

      expect(ids.toSet(), hasLength(10));
      expect(ids, (await repository.all()).map((i) => i.id).toList());
    });

    test('forPackage() agrees with all() on tied timestamps', () async {
      final tie = DateTime(2026, 3, 12, 14);
      for (var i = 0; i < 4; i++) {
        await repository.insert(
          build(title: 'Tied $i', package: 'com.slack', postedAt: tie),
        );
      }

      final perApp = await repository.forPackage('com.slack');
      final unpaged = await repository.all();
      expect(
        perApp.map((i) => i.id).toList(),
        unpaged.map((i) => i.id).toList(),
      );
    });

    test('snoozed() breaks ties on an identical wake-up time', () async {
      // `snooze()` derives the wake-up time from `DateTime.now()`, so a loop
      // over it never produces a real tie. Writing the column directly is the
      // only way to exercise the tiebreaker.
      final until = DateTime.now()
          .add(const Duration(hours: 3))
          .millisecondsSinceEpoch;
      final ids = <int>[];
      for (var i = 0; i < 4; i++) {
        final id = await repository.insert(build(title: 'Snoozed $i'));
        await db.update(
          'notification_items',
          {'snooze_until': until},
          where: 'id = ?',
          whereArgs: [id],
        );
        ids.add(id);
      }

      final once = await repository.snoozed();
      final twice = await repository.snoozed();
      expect(once.map((i) => i.id).toList(), twice.map((i) => i.id).toList());
      expect(once.map((i) => i.id).toSet(), ids.toSet());
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

  group('date range filtering', () {
    test('a range ending today includes everything posted today', () async {
      final now = DateTime.now();
      await repository.insert(
        build(
          title: 'Today',
          postedAt: DateTime(now.year, now.month, now.day, 9),
        ),
      );

      final items = await repository.all(
        filter: NotificationFilter(
          start: now.subtract(const Duration(days: 1)),
          end: now,
        ),
      );
      expect(items.map((item) => item.title), contains('Today'));
    });

    test('the last minute of the end date is included', () async {
      final end = DateTime(2026, 3, 12);
      await repository.insert(
        build(title: 'Late', postedAt: DateTime(2026, 3, 12, 23, 59)),
      );

      final items = await repository.all(
        filter: NotificationFilter(start: DateTime(2026, 3, 11), end: end),
      );
      expect(items, hasLength(1));
      expect(items.single.title, 'Late');
    });

    test('a single-day range returns that whole day', () async {
      final day = DateTime(2026, 3, 12);
      await repository.insert(
        build(title: 'Morning', postedAt: DateTime(2026, 3, 12, 0, 0, 1)),
      );
      await repository.insert(
        build(title: 'Evening', postedAt: DateTime(2026, 3, 12, 22, 15)),
      );
      await repository.insert(
        build(title: 'Next day', postedAt: DateTime(2026, 3, 13, 0, 30)),
      );

      final items = await repository.all(
        filter: NotificationFilter(start: day, end: day),
      );
      expect(
        items.map((item) => item.title),
        containsAll(['Morning', 'Evening']),
      );
      expect(items, hasLength(2));
    });

    test('the lower bound still includes midnight on the start date', () async {
      await repository.insert(
        build(title: 'Midnight', postedAt: DateTime(2026, 3, 12)),
      );

      final items = await repository.all(
        filter: NotificationFilter(
          start: DateTime(2026, 3, 12, 18, 0),
          end: DateTime(2026, 3, 12),
        ),
      );
      expect(items, hasLength(1));
      expect(items.single.title, 'Midnight');
    });

    test('notifications after the end date are still excluded', () async {
      await repository.insert(
        build(title: 'Too late', postedAt: DateTime(2026, 3, 13, 0, 1)),
      );

      final items = await repository.all(
        filter: NotificationFilter(
          start: DateTime(2026, 3, 11),
          end: DateTime(2026, 3, 12),
        ),
      );
      expect(items, isEmpty);
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

  group('muted applications', () {
    Future<void> addApp(String package, {bool muted = false}) {
      return db.insert('app_sources', {
        'package_name': package,
        'app_label': package,
        'is_muted': muted ? 1 : 0,
        'first_seen_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    test('the inbox excludes a muted application', () async {
      await addApp('com.whatsapp', muted: true);
      await addApp('com.slack');
      await repository.insert(build(package: 'com.whatsapp', title: 'Hidden'));
      await repository.insert(build(package: 'com.slack', title: 'Shown'));

      final inbox = await repository.page(limit: 20, offset: 0);
      expect(inbox.map((item) => item.title), ['Shown']);
    });

    test('forPackage still lists a muted application', () async {
      await addApp('com.whatsapp', muted: true);
      await repository.insert(build(package: 'com.whatsapp', title: 'Hidden'));

      final perApp = await repository.forPackage('com.whatsapp');
      expect(perApp.map((item) => item.title), ['Hidden']);
    });

    test('unmuting restores the notifications with no data loss', () async {
      await addApp('com.whatsapp', muted: true);
      await repository.insert(build(package: 'com.whatsapp', title: 'Hidden'));
      expect(await repository.page(limit: 20, offset: 0), isEmpty);

      await db.update(
        'app_sources',
        {'is_muted': 0},
        where: 'package_name = ?',
        whereArgs: ['com.whatsapp'],
      );

      final inbox = await repository.page(limit: 20, offset: 0);
      expect(inbox.map((item) => item.title), ['Hidden']);
    });

    test('the unread badge agrees with the inbox', () async {
      await addApp('com.whatsapp', muted: true);
      await addApp('com.slack');
      await repository.insert(build(package: 'com.whatsapp'));
      await repository.insert(build(package: 'com.slack'));

      expect(await repository.unreadCount(), 1);
    });

    test('an application with no app_sources row is still shown', () async {
      // Notifications can arrive before `syncInstalled` has registered the
      // app, and `NOT IN` must not swallow them.
      await repository.insert(build(package: 'com.unknown', title: 'Early'));

      final inbox = await repository.page(limit: 20, offset: 0);
      expect(inbox.map((item) => item.title), ['Early']);
    });

    test('all() is not scoped by mute', () async {
      await addApp('com.whatsapp', muted: true);
      await repository.insert(build(package: 'com.whatsapp', title: 'Hidden'));

      expect(await repository.all(), hasLength(1));
    });
  });

  group('markAllAsRead', () {
    test('only marks notifications matching the filter', () async {
      await repository.insert(build(package: 'com.whatsapp', title: 'Chat'));
      await repository.insert(build(package: 'com.slack', title: 'Work'));

      await repository.markAllAsRead(
        const NotificationFilter(packageNames: {'com.slack'}),
      );

      final items = await repository.all();
      final byTitle = {for (final item in items) item.title: item.isRead};
      expect(byTitle['Work'], isTrue);
      expect(byTitle['Chat'], isFalse);
    });

    test('an unfiltered call marks everything unread as read', () async {
      await repository.insert(build(package: 'com.whatsapp'));
      await repository.insert(build(package: 'com.slack'));

      await repository.markAllAsRead(NotificationFilter.empty);

      expect(await repository.unreadCount(), 0);
    });

    test('archived notifications are untouched by default', () async {
      await repository.insert(build(title: 'Live'));
      await repository.insert(build(title: 'Filed', isArchived: true));

      await repository.markAllAsRead(NotificationFilter.empty);

      final archived = await repository.all(
        filter: const NotificationFilter(includeArchived: true),
      );
      final filed = archived.firstWhere((item) => item.title == 'Filed');
      expect(filed.isRead, isFalse);
    });

    test('includeArchived also marks archived notifications', () async {
      await repository.insert(build(title: 'Filed', isArchived: true));

      await repository.markAllAsRead(
        const NotificationFilter(includeArchived: true),
      );

      final archived = await repository.all(
        filter: const NotificationFilter(includeArchived: true),
      );
      expect(archived.single.isRead, isTrue);
    });

    test('a search query narrows what gets marked', () async {
      await repository.insert(build(title: 'Payment received'));
      await repository.insert(build(title: 'Priya Sharma'));

      await repository.markAllAsRead(
        const NotificationFilter(query: 'Payment'),
      );

      final items = await repository.all();
      final byTitle = {for (final item in items) item.title: item.isRead};
      expect(byTitle['Payment received'], isTrue);
      expect(byTitle['Priya Sharma'], isFalse);
    });

    test('already-read notifications stay read', () async {
      await repository.insert(build(title: 'Seen', isRead: true));
      await repository.markAllAsRead(NotificationFilter.empty);
      final items = await repository.all();
      expect(items.single.isRead, isTrue);
    });

    test('a muted application is not marked', () async {
      // The button sits above the inbox, and the inbox hides muted apps, so
      // marking them would mark rows the user cannot see.
      await db.insert('app_sources', {
        'package_name': 'com.whatsapp',
        'app_label': 'WhatsApp',
        'is_muted': 1,
        'first_seen_at': DateTime.now().millisecondsSinceEpoch,
      });
      await repository.insert(build(package: 'com.whatsapp', title: 'Muted'));
      await repository.insert(build(package: 'com.slack', title: 'Visible'));

      await repository.markAllAsRead(NotificationFilter.empty);

      final items = await repository.all();
      final byTitle = {for (final item in items) item.title: item.isRead};
      expect(byTitle['Visible'], isTrue);
      expect(byTitle['Muted'], isFalse);
    });

    test('a notification snoozed for later today is not marked', () async {
      // #41 documents that a still-snoozed notification is not marked, since
      // it is absent from the list. That was only true on paper until this
      // branch: with the old end-of-today bound a same-day snooze satisfied
      // the clause and did get marked. Pinning the documented behaviour now
      // that it actually holds.
      final id = await repository.insert(build(title: 'Snoozed'));
      await repository.insert(build(title: 'Visible'));
      await repository.snooze(id, const Duration(minutes: 30));

      await repository.markAllAsRead(NotificationFilter.empty);

      // Read the snoozed row by id: it is absent from `all()` too, because the
      // snooze clause is part of the shared filter.
      expect((await repository.byId(id))!.isRead, isFalse);
      final visible = (await repository.all()).single;
      expect(visible.title, 'Visible');
      expect(visible.isRead, isTrue);
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

    test('a snoozed notification is hidden from the inbox', () async {
      final id = await repository.insert(build(title: 'Snoozed'));
      await repository.snooze(id, const Duration(hours: 1));

      expect(await repository.all(), isEmpty);
      expect(await repository.page(limit: 20, offset: 0), isEmpty);
    });

    test('a snooze expiring later today still hides the row', () async {
      // The whole point of B5: a snooze that lands before midnight must not be
      // treated as already elapsed.
      final id = await repository.insert(build(title: 'Fifteen minutes'));
      await repository.snooze(id, const Duration(minutes: 15));

      expect(await repository.all(), isEmpty);
    });

    test(
      'a notification whose snooze has passed is back in the inbox',
      () async {
        final id = await repository.insert(build(title: 'Woke up'));
        await repository.snooze(id, const Duration(hours: -2));

        final items = await repository.all();
        expect(items, hasLength(1));
        expect(items.single.id, id);
      },
    );

    test('notifications that were never snoozed are unaffected', () async {
      await repository.insert(build(title: 'Plain'));
      final items = await repository.all();
      expect(items, hasLength(1));
      expect(items.single.title, 'Plain');
    });

    test('the inbox and snoozed() agree on what is snoozed', () async {
      final id = await repository.insert(build(title: 'Snoozed'));
      await repository.insert(build(title: 'Visible'));
      await repository.snooze(id, const Duration(minutes: 30));

      final inbox = await repository.all();
      final snoozed = await repository.snoozed();

      expect(inbox.map((item) => item.title), ['Visible']);
      expect(snoozed.map((item) => item.title), ['Snoozed']);
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
