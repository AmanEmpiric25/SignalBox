import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../notifications/domain/notification_filter.dart';
import '../../data/statistics_repository.dart';
import '../../domain/statistics_models.dart';

final statisticsRepositoryProvider = Provider<StatisticsRepository>(
  (ref) => StatisticsRepository(ref.watch(databaseProvider)),
);

/// Date ranges offered on the Statistics screen.
enum StatsRange {
  last7Days(7, 'Last 7 days'),
  last30Days(30, 'Last 30 days'),
  allTime(0, 'All time');

  const StatsRange(this.days, this.label);

  final int days;
  final String label;
}

final statsRangeProvider = NotifierProvider<StatsRangeNotifier, StatsRange>(
  StatsRangeNotifier.new,
);

class StatsRangeNotifier extends Notifier<StatsRange> {
  @override
  StatsRange build() => StatsRange.last7Days;

  void select(StatsRange range) => state = range;
}

/// Optional application filter for the Statistics screen.
final statsPackageFilterProvider =
    NotifierProvider<StatsPackageFilterNotifier, String?>(
      StatsPackageFilterNotifier.new,
    );

class StatsPackageFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? packageName) => state = packageName;
}

/// Statistics for the selected range and application.
final statisticsProvider = FutureProvider<NotificationStatistics>((ref) {
  final range = ref.watch(statsRangeProvider);
  final package = ref.watch(statsPackageFilterProvider);

  final now = DateTime.now();
  final filter = NotificationFilter(
    start: range.days == 0 ? null : now.subtract(Duration(days: range.days)),
    end: range.days == 0 ? null : now,
    packageNames: package == null ? const <String>{} : {package},
  );

  return ref.watch(statisticsRepositoryProvider).load(filter);
});
