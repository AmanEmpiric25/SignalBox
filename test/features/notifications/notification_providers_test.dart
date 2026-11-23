import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalbox/core/database/database_provider.dart';
import 'package:signalbox/core/services/preferences_provider.dart';
import 'package:signalbox/features/notifications/data/notification_repository.dart';
import 'package:signalbox/features/notifications/domain/notification_filter.dart';
import 'package:signalbox/features/notifications/presentation/providers/notification_providers.dart';
import 'package:signalbox/shared/models/notification_item.dart';
import 'package:signalbox/shared/models/notification_priority.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

/// Provider-level tests for [InboxNotifier].
///
/// These assert the *invalidations* a mutation performs, not just the row it
/// writes. A repository test cannot see that the unread badge went stale,
/// because the staleness lives in the provider graph rather than in the
/// database. Use this as the template for the other state-management issues.
void main() {
  setUpAll(initTestDatabase);

  late Database db;
  late SharedPreferences prefs;

  setUp(() async {
    db = await openTestDatabase();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async => db.close());

  Future<int> insert({bool isRead = false, String title = 'Priya Sharma'}) {
    return NotificationRepository(db).insert(
      NotificationItem(
        id: 0,
        packageName: 'com.whatsapp',
        title: title,
        body: 'Are we still meeting at 6?',
        postedAt: DateTime.now(),
        priority: NotificationPriority.normal,
        isRead: isRead,
      ),
    );
  }

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('deleting an unread notification lowers the unread count', () async {
    final id = await insert();
    final container = makeContainer();

    // Read it first, so the value is cached. A stale cache is the bug: the
    // provider only recomputes if the mutation invalidates it.
    expect(await container.read(unreadCountProvider.future), 1);
    await container.read(inboxProvider.future);

    await container.read(inboxProvider.notifier).delete(id);

    expect(await container.read(unreadCountProvider.future), 0);
  });

  test('deleting a read notification leaves the unread count alone', () async {
    await insert(title: 'Unread one');
    final readId = await insert(isRead: true, title: 'Already seen');
    final container = makeContainer();

    expect(await container.read(unreadCountProvider.future), 1);
    await container.read(inboxProvider.future);

    await container.read(inboxProvider.notifier).delete(readId);

    expect(await container.read(unreadCountProvider.future), 1);
  });

  test('deleteMany lowers the unread count by the number removed', () async {
    final first = await insert(title: 'One');
    final second = await insert(title: 'Two');
    await insert(title: 'Three');
    final container = makeContainer();

    expect(await container.read(unreadCountProvider.future), 3);
    await container.read(inboxProvider.future);

    await container.read(inboxProvider.notifier).deleteMany([first, second]);

    expect(await container.read(unreadCountProvider.future), 1);
  });

  test('deleteMany with no ids changes nothing', () async {
    await insert();
    final container = makeContainer();

    expect(await container.read(unreadCountProvider.future), 1);
    await container.read(inboxProvider.future);

    await container.read(inboxProvider.notifier).deleteMany(const <int>[]);

    expect(await container.read(unreadCountProvider.future), 1);
    expect((await container.read(inboxProvider.future)).items, hasLength(1));
  });

  test('delete also removes the notification from the inbox list', () async {
    final id = await insert();
    final container = makeContainer();

    expect((await container.read(inboxProvider.future)).items, hasLength(1));

    await container.read(inboxProvider.notifier).delete(id);

    expect((await container.read(inboxProvider.future)).items, isEmpty);
  });

  test('archive lowers the unread count', () async {
    final id = await insert();
    final container = makeContainer();

    // Archive was already correct. Pinning it here so that a future
    // refactor of these mutations cannot quietly regress it the way
    // delete had regressed.
    expect(await container.read(unreadCountProvider.future), 1);
    await container.read(inboxProvider.future);

    await container.read(inboxProvider.notifier).archive(id);

    expect(await container.read(unreadCountProvider.future), 0);
  });

  group('pagination', () {
    /// Inserts [count] notifications with strictly decreasing timestamps.
    ///
    /// Distinct timestamps keep these tests independent of `B9`: while `page()`
    /// still lacks an id tiebreaker, rows sharing a timestamp have no
    /// guaranteed order, which would make a paging assertion flaky for reasons
    /// that have nothing to do with the offset.
    Future<List<int>> insertSeries(int count) async {
      final repository = NotificationRepository(db);
      final base = DateTime(2026, 3, 12, 12);
      final ids = <int>[];
      for (var i = 0; i < count; i++) {
        ids.add(
          await repository.insert(
            NotificationItem(
              id: 0,
              packageName: 'com.whatsapp',
              title: 'Message $i',
              body: 'Body $i',
              postedAt: base.subtract(Duration(minutes: i)),
              priority: NotificationPriority.normal,
            ),
          ),
        );
      }
      return ids;
    }

    test(
      'paging the whole inbox yields every notification exactly once',
      () async {
        await insertSeries(25);
        final container = makeContainer();

        final first = await container.read(inboxProvider.future);
        expect(first.items, hasLength(20));
        expect(first.hasMore, isTrue);

        await container.read(inboxProvider.notifier).loadMore();
        final loaded = container.read(inboxProvider).requireValue;

        final pagedIds = loaded.items.map((item) => item.id).toList();
        final expectedIds = (await NotificationRepository(
          db,
        ).all()).map((item) => item.id).toList();

        expect(pagedIds, expectedIds);
        expect(pagedIds.toSet(), hasLength(25));
        expect(loaded.hasMore, isFalse);
      },
    );

    test(
      'a total that is an exact multiple of the page size pages cleanly',
      () async {
        await insertSeries(20);
        final container = makeContainer();

        final first = await container.read(inboxProvider.future);
        expect(first.items, hasLength(20));
        // A full first page cannot know it is the last one.
        expect(first.hasMore, isTrue);

        await container.read(inboxProvider.notifier).loadMore();
        final loaded = container.read(inboxProvider).requireValue;

        expect(loaded.items, hasLength(20));
        expect(loaded.items.map((item) => item.id).toSet(), hasLength(20));
        expect(loaded.hasMore, isFalse);
      },
    );

    test('loadMore does not re-fetch a notification already loaded', () async {
      await insertSeries(21);
      final container = makeContainer();

      await container.read(inboxProvider.future);
      await container.read(inboxProvider.notifier).loadMore();
      final loaded = container.read(inboxProvider).requireValue;

      expect(loaded.items, hasLength(21));
      expect(loaded.items.map((item) => item.id).toSet(), hasLength(21));
    });
  });

  group('filtered count', () {
    // The "N notifications" row above the list reads filteredCountProvider.
    // As with the unread count, every test reads it before mutating so the
    // value is cached; an uncached provider recomputes on first read and would
    // pass whether or not the mutation invalidated it.

    late _CountingRepository repository;

    ProviderContainer makeCountingContainer() {
      repository = _CountingRepository(db);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<int> insertWith({
      bool isRead = false,
      NotificationPriority priority = NotificationPriority.normal,
      String title = 'Priya Sharma',
    }) {
      return NotificationRepository(db).insert(
        NotificationItem(
          id: 0,
          packageName: 'com.whatsapp',
          title: title,
          body: 'Are we still meeting at 6?',
          postedAt: DateTime.now(),
          priority: priority,
          isRead: isRead,
        ),
      );
    }

    /// The count the database reports for the filter the inbox is using now.
    Future<int> truth(ProviderContainer container) =>
        repository.count(filter: container.read(inboxFilterProvider));

    test('delete lowers it', () async {
      final id = await insertWith(title: 'One');
      await insertWith(title: 'Two');
      await insertWith(title: 'Three');
      final container = makeCountingContainer();

      expect(await container.read(filteredCountProvider.future), 3);
      await container.read(inboxProvider.future);

      await container.read(inboxProvider.notifier).delete(id);

      expect(await container.read(filteredCountProvider.future), 2);
      expect(await truth(container), 2);
    });

    test('deleteMany lowers it by the number removed', () async {
      final first = await insertWith(title: 'One');
      final second = await insertWith(title: 'Two');
      await insertWith(title: 'Three');
      final container = makeCountingContainer();

      expect(await container.read(filteredCountProvider.future), 3);
      await container.read(inboxProvider.future);

      await container.read(inboxProvider.notifier).deleteMany([first, second]);

      expect(await container.read(filteredCountProvider.future), 1);
    });

    test(
      'archive lowers it, because the default filter hides archived',
      () async {
        final id = await insertWith(title: 'One');
        await insertWith(title: 'Two');
        final container = makeCountingContainer();

        expect(await container.read(filteredCountProvider.future), 2);
        await container.read(inboxProvider.future);

        await container.read(inboxProvider.notifier).archive(id);

        expect(await container.read(filteredCountProvider.future), 1);
        expect(await truth(container), 1);
      },
    );

    test('snooze lowers it, because the inbox hides snoozed', () async {
      final id = await insertWith(title: 'One');
      await insertWith(title: 'Two');
      final container = makeCountingContainer();

      expect(await container.read(filteredCountProvider.future), 2);
      await container.read(inboxProvider.future);

      await container
          .read(inboxProvider.notifier)
          .snooze(id, const Duration(hours: 1));

      expect(await container.read(filteredCountProvider.future), 1);
      expect(await truth(container), 1);
    });

    test(
      'the example from the bug report: delete and archive together',
      () async {
        final toDelete = await insertWith(title: 'One');
        final toArchive = await insertWith(title: 'Two');
        await insertWith(title: 'Three');
        final container = makeCountingContainer();

        expect(await container.read(filteredCountProvider.future), 3);
        await container.read(inboxProvider.future);

        final inbox = container.read(inboxProvider.notifier);
        await inbox.delete(toDelete);
        await inbox.archive(toArchive);

        // It used to stay at 3 while the list showed one row.
        expect(await container.read(filteredCountProvider.future), 1);
        expect(
          (await container.read(inboxProvider.future)).items,
          hasLength(1),
        );
      },
    );

    test('setRead lowers it while "unread only" is active', () async {
      final id = await insertWith(title: 'One');
      await insertWith(title: 'Two');
      final container = makeCountingContainer();
      container.read(inboxFilterProvider.notifier).setOnlyUnread(true);

      expect(await container.read(filteredCountProvider.future), 2);
      await container.read(inboxProvider.future);

      await container.read(inboxProvider.notifier).setRead(id);

      expect(await container.read(filteredCountProvider.future), 1);
      expect(await truth(container), 1);
    });

    test('markAllAsRead empties it while "unread only" is active', () async {
      await insertWith(title: 'One');
      await insertWith(title: 'Two');
      final container = makeCountingContainer();
      container.read(inboxFilterProvider.notifier).setOnlyUnread(true);

      expect(await container.read(filteredCountProvider.future), 2);
      await container.read(inboxProvider.future);

      await container.read(inboxProvider.notifier).markAllAsRead();

      expect(await container.read(filteredCountProvider.future), 0);
    });

    test('setPriority changes it while a priority filter is active', () async {
      final id = await insertWith(priority: NotificationPriority.high);
      await insertWith(priority: NotificationPriority.high, title: 'Two');
      final container = makeCountingContainer();
      container
          .read(inboxFilterProvider.notifier)
          .togglePriority(NotificationPriority.high);

      expect(await container.read(filteredCountProvider.future), 2);
      await container.read(inboxProvider.future);

      await container
          .read(inboxProvider.notifier)
          .setPriority(id, NotificationPriority.low);

      expect(await container.read(filteredCountProvider.future), 1);
      expect(await truth(container), 1);
    });

    group('does not re-query when the count cannot have changed', () {
      // Reading the provider again after a mutation only calls count() if the
      // mutation invalidated it, so the number of calls is the invalidation.
      Future<int> countCallsAfter(
        ProviderContainer container,
        Future<void> Function(InboxNotifier inbox) mutate,
      ) async {
        await container.read(filteredCountProvider.future);
        await container.read(inboxProvider.future);
        final before = repository.countCalls;

        await mutate(container.read(inboxProvider.notifier));
        await container.read(filteredCountProvider.future);

        return repository.countCalls - before;
      }

      test('deleteMany with no ids', () async {
        await insertWith();
        final container = makeCountingContainer();

        expect(
          await countCallsAfter(container, (i) => i.deleteMany(const <int>[])),
          0,
        );
      });

      test('setRead under the default filter', () async {
        final id = await insertWith();
        final container = makeCountingContainer();

        expect(await countCallsAfter(container, (i) => i.setRead(id)), 0);
      });

      test('markAllAsRead under the default filter', () async {
        await insertWith();
        final container = makeCountingContainer();

        expect(await countCallsAfter(container, (i) => i.markAllAsRead()), 0);
      });

      test('setPriority with no priority filter', () async {
        final id = await insertWith();
        final container = makeCountingContainer();

        expect(
          await countCallsAfter(
            container,
            (i) => i.setPriority(id, NotificationPriority.high),
          ),
          0,
        );
      });

      test('archive while archived notifications are included', () async {
        final id = await insertWith();
        final container = makeCountingContainer();
        container.read(inboxFilterProvider.notifier).setIncludeArchived(true);

        expect(await countCallsAfter(container, (i) => i.archive(id)), 0);
      });

      test('the mutations that do change it do re-query', () async {
        final id = await insertWith();
        final container = makeCountingContainer();

        // Guards the guard: if counting were broken, every case above would
        // pass for the wrong reason.
        expect(await countCallsAfter(container, (i) => i.delete(id)), 1);
      });
    });

    test('the unread count behaves as it did before', () async {
      final id = await insertWith();
      final container = makeCountingContainer();

      expect(await container.read(unreadCountProvider.future), 1);
      await container.read(inboxProvider.future);

      await container.read(inboxProvider.notifier).delete(id);

      expect(await container.read(unreadCountProvider.future), 0);
    });
  });
}

/// A repository that counts how often [count] runs, to show whether a mutation
/// invalidated the provider that calls it.
class _CountingRepository extends NotificationRepository {
  _CountingRepository(super.db);

  int countCalls = 0;

  @override
  Future<int> count({NotificationFilter filter = NotificationFilter.empty}) {
    countCalls++;
    return super.count(filter: filter);
  }
}
