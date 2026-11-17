import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../../notifications/presentation/providers/notification_providers.dart';
import '../../notifications/presentation/widgets/notification_tile.dart';
import '../../settings/presentation/providers/settings_providers.dart';
import 'providers/application_providers.dart';

/// Every notification captured from a single application.
class AppDetailPage extends ConsumerWidget {
  const AppDetailPage({required this.packageName, super.key});

  final String packageName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(appLabelsProvider).valueOrNull ?? const {};
    final appLabel = labels[packageName] ?? packageName;
    final items = ref.watch(notificationsForPackageProvider(packageName));
    final categories =
        ref.watch(categoriesByIdProvider).valueOrNull ?? const {};
    final hidePreview = ref.watch(settingsProvider).hidePreviewContent;

    return Scaffold(
      appBar: AppBar(
        title: Text(appLabel),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                packageName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () =>
              ref.invalidate(notificationsForPackageProvider(packageName)),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'Nothing from $appLabel',
              message: 'No notifications have been captured from this app yet.',
            );
          }
          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = notifications[index];
              return NotificationTile(
                item: item,
                appLabel: appLabel,
                category: categories[item.categoryId],
                hidePreview: hidePreview,
                onTap: () => context.push(Routes.notificationDetail(item.id)),
              );
            },
          );
        },
      ),
    );
  }
}
