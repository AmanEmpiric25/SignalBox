import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/date_time_x.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import 'providers/application_providers.dart';

/// Application-wise grouping: one row per app with its notification rollup.
class ApplicationsPage extends ConsumerWidget {
  const ApplicationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(appSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Applications')),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(appSummariesProvider),
        ),
        data: (apps) {
          if (apps.isEmpty) {
            return const EmptyState(
              icon: Icons.apps_rounded,
              title: 'No applications yet',
              message:
                  'Apps appear here as soon as they post their first notification.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(appSummariesProvider),
            child: ListView.separated(
              itemCount: apps.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final app = apps[index];
                return ListTile(
                  leading: AppAvatar(
                    packageName: app.packageName,
                    label: app.appLabel,
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          app.appLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (app.isMuted) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.volume_off_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${app.total} total'
                    '${app.hasUnread ? ' · ${app.unread} unread' : ''}'
                    '${app.lastPostedAt == null ? '' : ' · ${app.lastPostedAt!.relativeLabel}'}'
                    '${app.matchingRules > 0 ? ' · ${app.matchingRules} rule${app.matchingRules == 1 ? '' : 's'}' : ''}',
                  ),
                  trailing: Switch.adaptive(
                    value: !app.isMuted,
                    onChanged: (enabled) => ref
                        .read(appMuteControllerProvider)
                        .setMuted(app.packageName, !enabled),
                  ),
                  onTap: () => context.push(Routes.appDetail(app.packageName)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
