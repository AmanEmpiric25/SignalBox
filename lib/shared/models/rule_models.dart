/// The notification field a rule is matched against.
enum RuleMatchField {
  packageName,
  title,
  body;

  static RuleMatchField fromIndex(int index) =>
      index >= 0 && index < RuleMatchField.values.length
      ? RuleMatchField.values[index]
      : RuleMatchField.title;

  String get label => switch (this) {
    RuleMatchField.packageName => 'Package name',
    RuleMatchField.title => 'Title',
    RuleMatchField.body => 'Body',
  };
}

/// What a rule does when it matches.
enum RuleAction {
  setPriority,
  assignCategory,
  mute,
  autoSnooze;

  static RuleAction fromIndex(int index) =>
      index >= 0 && index < RuleAction.values.length
      ? RuleAction.values[index]
      : RuleAction.setPriority;

  String get label => switch (this) {
    RuleAction.setPriority => 'Set priority',
    RuleAction.assignCategory => 'Assign category',
    RuleAction.mute => 'Mute',
    RuleAction.autoSnooze => 'Auto-snooze',
  };
}
