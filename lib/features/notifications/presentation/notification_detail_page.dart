import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/date_time_x.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/notification_item.dart';
import '../../../shared/models/notification_priority.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../applications/presentation/providers/application_providers.dart';
import '../../categories/presentation/providers/category_providers.dart';
import 'providers/notification_providers.dart';
import 'widgets/snooze_sheet.dart';

/// Full view of a single notification, with per-notification actions.
class NotificationDetailPage extends ConsumerWidget {
  const NotificationDetailPage({required this.notificationId, super.key});

  final int notificationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(notificationDetailProvider(notificationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () =>
              ref.invalidate(notificationDetailProvider(notificationId)),
        ),
        data: (item) => item == null
            ? const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Notification not found',
                message: 'It may have been deleted or cleaned up by retention.',
              )
            : _DetailBody(item: item),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final labels = ref.watch(appLabelsProvider).valueOrNull ?? const {};
    final categories =
        ref.watch(categoriesByIdProvider).valueOrNull ?? const {};
    final appLabel = labels[item.packageName] ?? item.packageName;
    final category = categories[item.categoryId];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppAvatar(
                      packageName: item.packageName,
                      label: appLabel,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appLabel,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            item.packageName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.push(Routes.appDetail(item.packageName)),
                      child: const Text('View app'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  item.title.isEmpty ? '(no title)' : item.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SelectableText(item.body, style: theme.textTheme.bodyLarge),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.postedAt.fullLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (item.snoozeUntil != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.snooze_rounded,
                        size: 15,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Snoozed until ${item.snoozeUntil!.fullLabel}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'PRIORITY',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final priority in NotificationPriority.values)
              ChoiceChip(
                label: Text(priority.label),
                selected: item.priority == priority,
                onSelected: (_) async {
                  await ref
                      .read(inboxProvider.notifier)
                      .setPriority(item.id, priority);
                  ref.invalidate(notificationDetailProvider(item.id));
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'CATEGORY',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('None'),
              selected: category == null,
              onSelected: (_) async {
                await ref
                    .read(notificationRepositoryProvider)
                    .setCategory(item.id, null);
                ref.invalidate(notificationDetailProvider(item.id));
                ref.invalidate(inboxProvider);
              },
            ),
            for (final entry in categories.entries)
              ChoiceChip(
                label: Text(entry.value.name),
                selected: category?.id == entry.key,
                onSelected: (_) async {
                  await ref
                      .read(notificationRepositoryProvider)
                      .setCategory(item.id, entry.key);
                  ref.invalidate(notificationDetailProvider(item.id));
                  ref.invalidate(inboxProvider);
                },
              ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final duration = await SnoozeSheet.show(context);
                  if (duration == null) return;
                  await ref
                      .read(inboxProvider.notifier)
                      .snooze(item.id, duration);
                  ref.invalidate(notificationDetailProvider(item.id));
                },
                icon: const Icon(Icons.snooze_rounded, size: 18),
                label: const Text('Snooze'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(inboxProvider.notifier).archive(item.id);
                  if (context.mounted) context.pop();
                },
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: const Text('Archive'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: () async {
              await ref.read(inboxProvider.notifier).delete(item.id);
              if (context.mounted) context.pop();
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete notification'),
          ),
        ),
      ],
    );
  }
}
