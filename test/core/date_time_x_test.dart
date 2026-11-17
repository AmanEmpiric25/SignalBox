import 'package:flutter_test/flutter_test.dart';
import 'package:signalbox/core/extensions/date_time_x.dart';

void main() {
  group('DateTimeX', () {
    test('startOfDay drops the time component', () {
      final date = DateTime(2026, 3, 12, 17, 45, 30, 500);
      expect(date.startOfDay, DateTime(2026, 3, 12));
    });

    test('endOfDay is the last millisecond of the day', () {
      final date = DateTime(2026, 3, 12, 8);
      expect(date.endOfDay, DateTime(2026, 3, 12, 23, 59, 59, 999));
    });

    test('endOfDay is always after startOfDay on the same date', () {
      final date = DateTime(2026, 3, 12, 8);
      expect(date.endOfDay.isAfter(date.startOfDay), isTrue);
    });

    test('isSameDay ignores the time of day', () {
      expect(
        DateTime(2026, 3, 12, 1).isSameDay(DateTime(2026, 3, 12, 23)),
        isTrue,
      );
      expect(DateTime(2026, 3, 12).isSameDay(DateTime(2026, 3, 13)), isFalse);
    });

    test('isToday and isYesterday track the current date', () {
      final now = DateTime.now();
      expect(now.isToday, isTrue);
      expect(now.subtract(const Duration(days: 1)).isYesterday, isTrue);
      expect(now.subtract(const Duration(days: 1)).isToday, isFalse);
    });

    test('relativeLabel says Yesterday for the previous day', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(yesterday.relativeLabel, 'Yesterday');
    });

    test('dayKey is a sortable ISO date', () {
      expect(DateTime(2026, 3, 9, 22).dayKey, '2026-03-09');
    });
  });
}
