import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/date_time_x.dart';
import '../../../../shared/models/notification_priority.dart';
import '../../../applications/presentation/providers/application_providers.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../providers/notification_providers.dart';

/// Bottom sheet for narrowing down the inbox.
///
/// Advanced combinations (saved filter presets, "any of these categories",
/// exclusions) are not implemented yet. See the "advanced filters" issue.
class InboxFilterSheet extends ConsumerWidget {
  const InboxFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const InboxFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = ref.watch(inboxFilterProvider);
    final controller = ref.read(inboxFilterProvider.notifier);
    final apps = ref.watch(appLabelsProvider).valueOrNull ?? const {};
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filters',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      controller.reset();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _Label('Priority'),
              Wrap(
                spacing: 8,
                children: [
                  for (final priority in NotificationPriority.values)
                    FilterChip(
                      label: Text(priority.label),
                      selected: filter.priorities.contains(priority),
                      onSelected: (_) => controller.togglePriority(priority),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _Label('Category'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Any'),
                    selected: filter.categoryId == null,
                    onSelected: (_) => controller.setCategory(null),
                  ),
                  for (final category in categories)
                    ChoiceChip(
                      label: Text(category.name),
                      selected: filter.categoryId == category.id,
                      onSelected: (selected) =>
                          controller.setCategory(selected ? category.id : null),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _Label('Application'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in apps.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: filter.packageNames.contains(entry.key),
                      onSelected: (_) => controller.togglePackage(entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _Label('Date range'),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now,
                    initialDateRange: filter.start != null && filter.end != null
                        ? DateTimeRange(start: filter.start!, end: filter.end!)
                        : null,
                  );
                  if (range != null) {
                    controller.setDateRange(range.start, range.end);
                  }
                },
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(
                  filter.start == null || filter.end == null
                      ? 'Any date'
                      : '${filter.start!.dayKey} to ${filter.end!.dayKey}',
                ),
              ),
              if (filter.start != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => controller.setDateRange(null, null),
                    child: const Text('Clear dates'),
                  ),
                ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Unread only'),
                value: filter.onlyUnread,
                onChanged: controller.setOnlyUnread,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include archived'),
                value: filter.includeArchived,
                onChanged: controller.setIncludeArchived,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Show results'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
