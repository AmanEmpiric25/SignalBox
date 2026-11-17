import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/notification_priority.dart';
import '../../../shared/models/notification_rule.dart';
import '../../../shared/models/rule_models.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import 'providers/rule_providers.dart';
import 'widgets/rule_editor_sheet.dart';

/// Custom notification rules.
///
/// Rules can be created, edited, reordered by sort order and toggled. They are
/// NOT yet applied to incoming notifications: the evaluation engine is an open
/// task. See the "rule engine" issue.
class RulesPage extends ConsumerWidget {
  const RulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rules = ref.watch(rulesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification rules')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => RuleEditorSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New rule'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: theme.colorScheme.secondaryContainer,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  Icons.construction_rounded,
                  size: 18,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rules are stored but not applied to incoming '
                    'notifications yet.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: rules.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(rulesProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.rule_rounded,
                    title: 'No rules yet',
                    message:
                        'Create a rule to set priority or category automatically.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final rule = items[index];
                    return ListTile(
                      title: Text(
                        rule.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(_describe(rule)),
                      trailing: Switch.adaptive(
                        value: rule.isEnabled,
                        onChanged: (value) => ref
                            .read(rulesProvider.notifier)
                            .setEnabled(rule.id, value),
                      ),
                      onTap: () => RuleEditorSheet.show(context, rule: rule),
                      onLongPress: () => _confirmDelete(context, ref, rule),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _describe(NotificationRule rule) {
    final target = switch (rule.action) {
      RuleAction.setPriority =>
        'set priority to ${NotificationPriority.fromIndex(int.tryParse(rule.actionValue) ?? 1).label}',
      RuleAction.assignCategory => 'assign category ${rule.actionValue}',
      RuleAction.mute => 'mute the application',
      RuleAction.autoSnooze => 'snooze for ${rule.actionValue} minutes',
    };
    return 'When ${rule.matchField.label.toLowerCase()} contains '
        '"${rule.matchValue}", $target';
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    NotificationRule rule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${rule.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(rulesProvider.notifier).delete(rule.id);
    }
  }
}
