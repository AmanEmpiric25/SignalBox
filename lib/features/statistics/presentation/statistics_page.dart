import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/date_time_x.dart';
import '../../../shared/models/notification_priority.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/simple_bar_chart.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../applications/presentation/providers/application_providers.dart';
import 'providers/statistics_providers.dart';
import 'widgets/breakdown_bar.dart';

/// Notification statistics: volume over time and breakdowns by app, category
/// and priority.
class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final range = ref.watch(statsRangeProvider);
    final packageFilter = ref.watch(statsPackageFilterProvider);
    final labels = ref.watch(appLabelsProvider).valueOrNull ?? const {};
    final stats = ref.watch(statisticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(statisticsProvider),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final option in StatsRange.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(option.label),
                        selected: range == option,
                        onSelected: (_) => ref
                            .read(statsRangeProvider.notifier)
                            .select(option),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All apps'),
                      selected: packageFilter == null,
                      onSelected: (_) => ref
                          .read(statsPackageFilterProvider.notifier)
                          .select(null),
                    ),
                  ),
                  for (final entry in labels.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: packageFilter == entry.key,
                        onSelected: (selected) => ref
                            .read(statsPackageFilterProvider.notifier)
                            .select(selected ? entry.key : null),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Total notifications',
                    value: '${data.total}',
                    icon: Icons.inbox_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Unread',
                    value: '${data.unread}',
                    icon: Icons.mark_email_unread_outlined,
                    accent: const Color(0xFFE5484D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Busiest day',
                    value: '${data.busiestDayCount}',
                    icon: Icons.local_fire_department_outlined,
                    accent: const Color(0xFFE5A32A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Daily average',
                    value: data.dailyAverage.toStringAsFixed(1),
                    icon: Icons.show_chart_rounded,
                    accent: const Color(0xFF2E9E5B),
                  ),
                ),
              ],
            ),
            const SectionHeader(title: 'Volume per day'),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: SimpleBarChart(
                  height: 180,
                  data: [
                    for (final day in data.perDay)
                      BarDatum(
                        label: day.day.dayKey.substring(5),
                        value: day.count,
                        highlight: day.day.isToday,
                      ),
                  ],
                ),
              ),
            ),
            const SectionHeader(title: 'By application'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final app in data.perApp.take(8))
                      BreakdownBar(
                        label: app.appLabel,
                        value: app.count,
                        total: data.perApp.isEmpty
                            ? 0
                            : data.perApp
                                  .map((a) => a.count)
                                  .reduce((a, b) => a + b),
                        color: theme.colorScheme.primary,
                      ),
                    if (data.perApp.isEmpty) const Text('No data'),
                  ],
                ),
              ),
            ),
            const SectionHeader(title: 'By category'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final category in data.perCategory)
                      BreakdownBar(
                        label: category.name,
                        value: category.count,
                        total: data.perCategory
                            .map((c) => c.count)
                            .fold<int>(0, (a, b) => a + b),
                        color: Color(category.colorValue),
                      ),
                    if (data.perCategory.isEmpty) const Text('No data'),
                  ],
                ),
              ),
            ),
            const SectionHeader(title: 'By priority'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final priority in NotificationPriority.values)
                      BreakdownBar(
                        label: priority.label,
                        value: data.perPriority[priority] ?? 0,
                        total: data.perPriority.values.fold<int>(
                          0,
                          (a, b) => a + b,
                        ),
                        color: priority.color,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
