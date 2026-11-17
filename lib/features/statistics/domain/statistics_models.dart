import '../../../shared/models/notification_priority.dart';

/// Notification count for a single calendar day.
class DayCount {
  const DayCount({required this.day, required this.count});

  final DateTime day;
  final int count;
}

/// Notification count for a single application.
class AppCount {
  const AppCount({
    required this.packageName,
    required this.appLabel,
    required this.count,
  });

  final String packageName;
  final String appLabel;
  final int count;
}

/// Notification count for a single category.
class CategoryCount {
  const CategoryCount({
    required this.categoryId,
    required this.name,
    required this.colorValue,
    required this.count,
  });

  final int? categoryId;
  final String name;
  final int colorValue;
  final int count;
}

/// Everything the statistics screen renders.
class NotificationStatistics {
  const NotificationStatistics({
    required this.total,
    required this.unread,
    required this.snoozed,
    required this.perDay,
    required this.perApp,
    required this.perCategory,
    required this.perPriority,
  });

  final int total;
  final int unread;
  final int snoozed;
  final List<DayCount> perDay;
  final List<AppCount> perApp;
  final List<CategoryCount> perCategory;
  final Map<NotificationPriority, int> perPriority;

  /// Highest single-day count, used to scale the bar chart.
  int get busiestDayCount => perDay.isEmpty
      ? 0
      : perDay.map((d) => d.count).reduce((a, b) => a > b ? a : b);

  /// Mean notifications per day across the selected range.
  double get dailyAverage => perDay.isEmpty
      ? 0
      : perDay.fold<int>(0, (sum, d) => sum + d.count) / perDay.length;

  static const NotificationStatistics empty = NotificationStatistics(
    total: 0,
    unread: 0,
    snoozed: 0,
    perDay: <DayCount>[],
    perApp: <AppCount>[],
    perCategory: <CategoryCount>[],
    perPriority: <NotificationPriority, int>{},
  );
}
