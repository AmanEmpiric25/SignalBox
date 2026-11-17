import 'package:flutter/material.dart';

import '../../../../core/extensions/date_time_x.dart';
import '../../../../core/extensions/string_x.dart';
import '../../../../shared/models/notification_category.dart';
import '../../../../shared/models/notification_item.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/priority_chip.dart';

/// One row in the inbox.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    required this.item,
    required this.appLabel,
    this.category,
    this.hidePreview = false,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final NotificationItem item;
  final String appLabel;
  final NotificationCategory? category;

  /// When true the body text is masked (privacy setting).
  final bool hidePreview;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !item.isRead;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Semantics(
        label:
            '${item.title} from $appLabel, ${item.postedAt.fullLabel}'
            '${unread ? ', unread' : ''}',
        button: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(packageName: item.packageName, label: appLabel),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            appLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.postedAt.relativeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.title.isEmpty ? '(no title)' : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        hidePreview
                            ? '•' * 24
                            : item.body.normalised.truncate(90),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        PriorityChip(priority: item.priority, compact: true),
                        if (category != null)
                          _CategoryChip(category: category!),
                        if (item.isSnoozed)
                          const _MetaChip(
                            icon: Icons.snooze_rounded,
                            label: 'Snoozed',
                          ),
                        if (item.isArchived)
                          const _MetaChip(
                            icon: Icons.archive_outlined,
                            label: 'Archived',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  margin: const EdgeInsets.only(left: 10, top: 6),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final NotificationCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category.name,
        style: TextStyle(
          color: category.color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
