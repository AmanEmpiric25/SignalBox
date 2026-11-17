import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../shared/models/notification_category.dart';
import '../../data/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(databaseProvider)),
);

final categoriesProvider = FutureProvider<List<NotificationCategory>>(
  (ref) => ref.watch(categoryRepositoryProvider).all(),
);

/// Notification counts keyed by category id.
final categoryCountsProvider = FutureProvider<Map<int, int>>(
  (ref) => ref.watch(categoryRepositoryProvider).countsByCategory(),
);

/// Categories keyed by id, for quick lookups while building lists.
final categoriesByIdProvider = FutureProvider<Map<int, NotificationCategory>>((
  ref,
) async {
  final categories = await ref.watch(categoriesProvider.future);
  return {for (final category in categories) category.id: category};
});
