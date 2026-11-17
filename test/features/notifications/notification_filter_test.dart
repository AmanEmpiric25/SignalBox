import 'package:flutter_test/flutter_test.dart';
import 'package:signalbox/features/notifications/domain/notification_filter.dart';
import 'package:signalbox/shared/models/notification_priority.dart';

void main() {
  group('NotificationFilter', () {
    test('the empty filter is inactive', () {
      expect(NotificationFilter.empty.isActive, isFalse);
      expect(NotificationFilter.empty.activeCount, 0);
    });

    test('a whitespace-only query does not count as active', () {
      const filter = NotificationFilter(query: '   ');
      expect(filter.isActive, isFalse);
    });

    test('activeCount counts each kind of constraint once', () {
      final filter = NotificationFilter(
        query: 'invoice',
        packageNames: const {'com.whatsapp', 'com.slack'},
        priorities: const {NotificationPriority.high},
        categoryId: 3,
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 9),
        onlyUnread: true,
      );
      expect(filter.activeCount, 6);
    });

    test('copyWith preserves untouched fields', () {
      final filter = NotificationFilter(
        query: 'bank',
        categoryId: 2,
        start: DateTime(2026, 3, 1),
      );
      final updated = filter.copyWith(onlyUnread: true);
      expect(updated.query, 'bank');
      expect(updated.categoryId, 2);
      expect(updated.start, DateTime(2026, 3, 1));
      expect(updated.onlyUnread, isTrue);
    });

    test('clearCategory and clearDates remove the values', () {
      final filter = NotificationFilter(
        categoryId: 2,
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 9),
      );
      expect(filter.copyWith(clearCategory: true).categoryId, isNull);
      expect(filter.copyWith(clearDates: true).start, isNull);
      expect(filter.copyWith(clearDates: true).end, isNull);
    });

    test('filters with the same content are equal', () {
      const a = NotificationFilter(
        query: 'x',
        packageNames: {'com.a', 'com.b'},
      );
      const b = NotificationFilter(
        query: 'x',
        packageNames: {'com.b', 'com.a'},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('filters with different content are not equal', () {
      const a = NotificationFilter(query: 'x');
      const b = NotificationFilter(query: 'y');
      expect(a, isNot(b));
    });
  });
}
