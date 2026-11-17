import 'package:flutter_test/flutter_test.dart';
import 'package:signalbox/features/rules/data/rule_repository.dart';
import 'package:signalbox/shared/models/notification_rule.dart';
import 'package:signalbox/shared/models/rule_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(initTestDatabase);

  late Database db;
  late RuleRepository repository;

  setUp(() async {
    db = await openTestDatabase();
    repository = RuleRepository(db);
  });

  tearDown(() async => db.close());

  NotificationRule build({
    String name = 'Bank alerts are high priority',
    RuleMatchField field = RuleMatchField.packageName,
    String matchValue = 'com.hdfcbank.payzapp',
    RuleAction action = RuleAction.setPriority,
    String actionValue = '0',
    bool isEnabled = true,
    int sortOrder = 0,
  }) {
    return NotificationRule(
      id: 0,
      name: name,
      matchField: field,
      matchValue: matchValue,
      action: action,
      actionValue: actionValue,
      isEnabled: isEnabled,
      sortOrder: sortOrder,
    );
  }

  test('an inserted rule round-trips through the database', () async {
    await repository.insert(build());

    final rules = await repository.all();
    expect(rules, hasLength(1));
    expect(rules.single.name, 'Bank alerts are high priority');
    expect(rules.single.matchField, RuleMatchField.packageName);
    expect(rules.single.action, RuleAction.setPriority);
    expect(rules.single.isEnabled, isTrue);
  });

  test('rules are ordered by sortOrder', () async {
    await repository.insert(build(name: 'Third', sortOrder: 3));
    await repository.insert(build(name: 'First', sortOrder: 1));
    await repository.insert(build(name: 'Second', sortOrder: 2));

    final rules = await repository.all();
    expect(rules.map((r) => r.name).toList(), ['First', 'Second', 'Third']);
  });

  test('enabled() excludes disabled rules', () async {
    await repository.insert(build(name: 'On'));
    await repository.insert(build(name: 'Off', isEnabled: false));

    final rules = await repository.enabled();
    expect(rules, hasLength(1));
    expect(rules.single.name, 'On');
  });

  test('setEnabled persists the toggle', () async {
    await repository.insert(build());
    final id = (await repository.all()).single.id;

    await repository.setEnabled(id, false);
    expect((await repository.all()).single.isEnabled, isFalse);

    await repository.setEnabled(id, true);
    expect((await repository.all()).single.isEnabled, isTrue);
  });

  test('update rewrites every editable field', () async {
    await repository.insert(build());
    final stored = (await repository.all()).single;

    await repository.update(
      stored.copyWith(
        name: 'Offers are low priority',
        matchField: RuleMatchField.title,
        matchValue: 'off on your next order',
        action: RuleAction.autoSnooze,
        actionValue: '60',
      ),
    );

    final updated = (await repository.all()).single;
    expect(updated.name, 'Offers are low priority');
    expect(updated.matchField, RuleMatchField.title);
    expect(updated.matchValue, 'off on your next order');
    expect(updated.action, RuleAction.autoSnooze);
    expect(updated.actionValue, '60');
  });

  test('delete removes the rule', () async {
    await repository.insert(build());
    final id = (await repository.all()).single.id;

    await repository.delete(id);
    expect(await repository.all(), isEmpty);
  });

  test('match field and action indexes are stable', () {
    expect(RuleMatchField.packageName.index, 0);
    expect(RuleMatchField.title.index, 1);
    expect(RuleMatchField.body.index, 2);
    expect(RuleAction.setPriority.index, 0);
    expect(RuleAction.assignCategory.index, 1);
    expect(RuleAction.mute.index, 2);
    expect(RuleAction.autoSnooze.index, 3);
  });

  test('fromIndex falls back for out-of-range values', () {
    expect(RuleMatchField.fromIndex(99), RuleMatchField.title);
    expect(RuleAction.fromIndex(-1), RuleAction.setPriority);
  });
}
