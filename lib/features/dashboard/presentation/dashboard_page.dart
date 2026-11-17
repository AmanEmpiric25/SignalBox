import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/date_time_x.dart';
import '../../../core/router/app_router.dart';
import '../../statistics/domain/statistics_models.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/simple_bar_chart.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../notifications/presentation/providers/notification_providers.dart';
import '../../statistics/presentation/providers/statistics_providers.dart';
import 'widgets/access_banner.dart';

/// Landing screen: today's volume, unread count and quick entry points.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final snoozed = ref.watch(snoozedNotificationsProvider).valueOrNull ?? [];
    final stats = ref.watch(statisticsProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SignalBox'),
        actions: [
          IconButton(
            tooltip: 'Notification rules',
            onPressed: () => context.push(Routes.rules),
            icon: const Icon(Icons.rule_rounded),
          ),
          IconButton(
            tooltip: 'Categories',
            onPressed: () => context.push(Routes.categories),
            icon: const Icon(Icons.label_outline_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(unreadCountProvider);
          ref.invalidate(statisticsProvider);
          ref.invalidate(snoozedNotificationsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const AccessBanner(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Unread',
                    value: '$unread',
                    icon: Icons.mark_email_unread_outlined,
                    onTap: () => context.go(Routes.inbox),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Captured in range',
                    value: '${stats?.total ?? 0}',
                    icon: Icons.inbox_rounded,
                    onTap: () => context.go(Routes.statistics),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Snoozed',
                    value: '${snoozed.length}',
                    icon: Icons.snooze_rounded,
                    accent: const Color(0xFFE5A32A),
                    onTap: () => context.push(Routes.snoozed),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Daily average',
                    value: (stats?.dailyAverage ?? 0).toStringAsFixed(1),
                    icon: Icons.show_chart_rounded,
                    accent: const Color(0xFF2E9E5B),
                  ),
                ),
              ],
            ),
            const SectionHeader(title: 'Last 7 days'),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: SimpleBarChart(
                  data: [
                    for (final day in (stats?.perDay ?? const <DayCount>[]))
                      BarDatum(
                        label: day.day.dayKey.substring(5),
                        value: day.count,
                        highlight: day.day.isToday,
                      ),
                  ],
                ),
              ),
            ),
            const SectionHeader(title: 'Most active apps'),
            Card(
              child: Column(
                children: [
                  if ((stats?.perApp ?? const <AppCount>[]).isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No activity in this range'),
                    )
                  else
                    for (final app
                        in (stats?.perApp ?? const <AppCount>[]).take(5))
                      ListTile(
                        leading: AppAvatar(
                          packageName: app.packageName,
                          label: app.appLabel,
                          size: 36,
                        ),
                        title: Text(app.appLabel),
                        subtitle: Text(
                          '${app.count} notification'
                          '${app.count == 1 ? '' : 's'}',
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                        ),
                        onTap: () =>
                            context.push(Routes.appDetail(app.packageName)),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'SignalBox stores everything on this device. Nothing is uploaded.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
