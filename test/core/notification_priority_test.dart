import 'package:flutter_test/flutter_test.dart';
import 'package:signalbox/shared/models/notification_priority.dart';

void main() {
  group('NotificationPriority', () {
    test('indexes are stable because they are persisted', () {
      expect(NotificationPriority.high.index, 0);
      expect(NotificationPriority.normal.index, 1);
      expect(NotificationPriority.low.index, 2);
    });

    test('fromIndex round-trips every value', () {
      for (final priority in NotificationPriority.values) {
        expect(NotificationPriority.fromIndex(priority.index), priority);
      }
    });

    test('fromIndex falls back to normal for out-of-range input', () {
      expect(NotificationPriority.fromIndex(-1), NotificationPriority.normal);
      expect(NotificationPriority.fromIndex(99), NotificationPriority.normal);
    });

    test('every value has a label', () {
      for (final priority in NotificationPriority.values) {
        expect(priority.label, isNotEmpty);
      }
    });
  });
}
