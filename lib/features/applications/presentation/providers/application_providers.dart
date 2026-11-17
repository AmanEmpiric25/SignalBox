import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../data/application_repository.dart';
import '../../domain/app_summary.dart';

final applicationRepositoryProvider = Provider<ApplicationRepository>(
  (ref) => ApplicationRepository(ref.watch(databaseProvider)),
);

/// Per-application rollups for the Applications screen.
final appSummariesProvider = FutureProvider<List<AppSummary>>(
  (ref) => ref.watch(applicationRepositoryProvider).summaries(),
);

/// Mutes or unmutes an application and refreshes the list.
final appMuteControllerProvider = Provider<AppMuteController>(
  AppMuteController.new,
);

class AppMuteController {
  AppMuteController(this._ref);

  final Ref _ref;

  Future<void> setMuted(String packageName, bool isMuted) async {
    await _ref
        .read(applicationRepositoryProvider)
        .setMuted(packageName, isMuted);
    _ref.invalidate(appSummariesProvider);
  }
}

/// Package name to user visible label, used by notification lists.
final appLabelsProvider = FutureProvider<Map<String, String>>((ref) async {
  final sources = await ref.watch(applicationRepositoryProvider).all();
  return {for (final source in sources) source.packageName: source.appLabel};
});
