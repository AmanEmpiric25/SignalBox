import 'rule_models.dart';

/// User defined automation applied to incoming notifications.
class NotificationRule {
  const NotificationRule({
    required this.id,
    required this.name,
    required this.matchField,
    required this.matchValue,
    required this.action,
    required this.actionValue,
    required this.isEnabled,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final RuleMatchField matchField;
  final String matchValue;
  final RuleAction action;

  /// Action payload: priority index, category id, or snooze minutes.
  final String actionValue;
  final bool isEnabled;
  final int sortOrder;

  factory NotificationRule.fromMap(Map<String, Object?> map) =>
      NotificationRule(
        id: map['id'] as int,
        name: map['name'] as String,
        matchField: RuleMatchField.fromIndex(map['match_field'] as int),
        matchValue: map['match_value'] as String,
        action: RuleAction.fromIndex(map['action_type'] as int),
        actionValue: (map['action_value'] as String?) ?? '',
        isEnabled: (map['is_enabled'] as int? ?? 1) == 1,
        sortOrder: (map['sort_order'] as int?) ?? 0,
      );

  Map<String, Object?> toMap() => <String, Object?>{
    if (id > 0) 'id': id,
    'name': name,
    'match_field': matchField.index,
    'match_value': matchValue,
    'action_type': action.index,
    'action_value': actionValue,
    'is_enabled': isEnabled ? 1 : 0,
    'sort_order': sortOrder,
  };

  NotificationRule copyWith({
    String? name,
    RuleMatchField? matchField,
    String? matchValue,
    RuleAction? action,
    String? actionValue,
    bool? isEnabled,
    int? sortOrder,
  }) => NotificationRule(
    id: id,
    name: name ?? this.name,
    matchField: matchField ?? this.matchField,
    matchValue: matchValue ?? this.matchValue,
    action: action ?? this.action,
    actionValue: actionValue ?? this.actionValue,
    isEnabled: isEnabled ?? this.isEnabled,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}
