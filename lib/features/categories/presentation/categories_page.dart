import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/error_view.dart';
import 'providers/category_providers.dart';

/// Notification categories.
///
/// The five system categories are read-only. User created categories are not
/// implemented yet: see the "custom categories" issue.
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider);
    final counts = ref.watch(categoryCountsProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Creating custom categories is not implemented yet.'),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New category'),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final category = items[index];
            final count = counts[category.id] ?? 0;
            return ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.label_rounded,
                  size: 18,
                  color: category.color,
                ),
              ),
              title: Text(
                category.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '$count notification${count == 1 ? '' : 's'}'
                '${category.isSystem ? ' · system category' : ''}',
              ),
              trailing: category.isSystem
                  ? Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : null,
            );
          },
        ),
      ),
    );
  }
}
