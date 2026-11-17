import 'package:flutter_test/flutter_test.dart';
import 'package:signalbox/features/categories/data/category_repository.dart';
import 'package:signalbox/features/notifications/data/notification_repository.dart';
import 'package:signalbox/shared/models/notification_item.dart';
import 'package:signalbox/shared/models/notification_priority.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(initTestDatabase);

  late Database db;
  late CategoryRepository repository;

  setUp(() async {
    db = await openTestDatabase();
    repository = CategoryRepository(db);
  });

  tearDown(() async => db.close());

  test('the schema seeds the five system categories', () async {
    final categories = await repository.all();
    expect(categories, hasLength(5));
    expect(
      categories.map((c) => c.name),
      containsAll(['Messages', 'Social', 'Finance', 'Promotions', 'System']),
    );
    expect(categories.every((c) => c.isSystem), isTrue);
  });

  test('every system category carries a colour', () async {
    final categories = await repository.all();
    for (final category in categories) {
      expect(category.colorValue, isNot(0));
    }
  });

  test('byId resolves a category', () async {
    final first = (await repository.all()).first;
    final found = await repository.byId(first.id);
    expect(found!.name, first.name);
  });

  test('byId returns null for an unknown id', () async {
    expect(await repository.byId(9999), isNull);
  });

  test('a created category is not a system category', () async {
    final id = await repository.create(name: 'Work', colorValue: 0xFF112233);
    final created = await repository.byId(id);
    expect(created!.isSystem, isFalse);
    expect(created.name, 'Work');
  });

  test('system categories cannot be deleted', () async {
    final system = (await repository.all()).first;
    await repository.delete(system.id);
    expect(await repository.byId(system.id), isNotNull);
  });

  test('user categories can be deleted', () async {
    final id = await repository.create(name: 'Work', colorValue: 0xFF112233);
    await repository.delete(id);
    expect(await repository.byId(id), isNull);
  });

  test('countsByCategory counts assigned notifications', () async {
    final notifications = NotificationRepository(db);
    final messages = (await repository.all()).firstWhere(
      (c) => c.name == 'Messages',
    );

    for (var i = 0; i < 3; i++) {
      await notifications.insert(
        NotificationItem(
          id: 0,
          packageName: 'com.whatsapp',
          title: 'Title',
          body: 'Body',
          postedAt: DateTime.now(),
          priority: NotificationPriority.normal,
          categoryId: messages.id,
        ),
      );
    }

    final counts = await repository.countsByCategory();
    expect(counts[messages.id], 3);
  });

  test('countsByCategory ignores uncategorised notifications', () async {
    final notifications = NotificationRepository(db);
    await notifications.insert(
      NotificationItem(
        id: 0,
        packageName: 'com.whatsapp',
        title: 'Title',
        body: 'Body',
        postedAt: DateTime.now(),
        priority: NotificationPriority.normal,
      ),
    );

    expect(await repository.countsByCategory(), isEmpty);
  });
}
