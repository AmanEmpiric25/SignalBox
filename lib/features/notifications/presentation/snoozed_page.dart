import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/date_time_x.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../applications/presentation/providers/application_providers.dart';
import 'providers/notification_providers.dart';
import 'widgets/notification_tile.dart';

/// Notifications hidden from the inbox until their snooze window closes.
class SnoozedPage extends ConsumerWidget {
  const SnoozedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snoozed = ref.watch(snoozedNotificationsProvider);
    final labels = ref.watch(appLabelsProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('Snoozed')),
      body: snoozed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(snoozedNotificationsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.snooze_rounded,
              title: 'Nothing is snoozed',
              message:
                  'Long-press a notification in the inbox to snooze it for later.',
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NotificationTile(
                    item: item,
                    appLabel: labels[item.packageName] ?? item.packageName,
                    onTap: () =>
                        context.push(Routes.notificationDetail(item.id)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Returns ${item.snoozeUntil?.fullLabel ?? 'soon'}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await ref
                                .read(notificationRepositoryProvider)
                                .clearSnooze(item.id);
                            ref.invalidate(snoozedNotificationsProvider);
                            ref.invalidate(inboxProvider);
                          },
                          child: const Text('Unsnooze'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
