import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalbox/core/database/database_provider.dart';
import 'package:signalbox/core/services/preferences_provider.dart';
import 'package:signalbox/features/notifications/data/notification_repository.dart';
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
}
