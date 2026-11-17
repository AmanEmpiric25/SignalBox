import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../shared/models/notification_rule.dart';
import '../../data/rule_repository.dart';

final ruleRepositoryProvider = Provider<RuleRepository>(
  (ref) => RuleRepository(ref.watch(databaseProvider)),
);

final rulesProvider =
    AsyncNotifierProvider<RulesNotifier, List<NotificationRule>>(
      RulesNotifier.new,
    );

class RulesNotifier extends AsyncNotifier<List<NotificationRule>> {
  RuleRepository get _repository => ref.read(ruleRepositoryProvider);

  @override
  Future<List<NotificationRule>> build() => _repository.all();

  Future<void> add(NotificationRule rule) async {
    await _repository.insert(rule);
    ref.invalidateSelf();
    await future;
  }

  Future<void> save(NotificationRule rule) async {
    await _repository.update(rule);
    ref.invalidateSelf();
    await future;
  }

  Future<void> setEnabled(int id, bool isEnabled) async {
    await _repository.setEnabled(id, isEnabled);
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current
          .map((r) => r.id == id ? r.copyWith(isEnabled: isEnabled) : r)
          .toList(),
    );
  }

  Future<void> delete(int id) async {
    await _repository.delete(id);
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.where((r) => r.id != id).toList());
  }
}
