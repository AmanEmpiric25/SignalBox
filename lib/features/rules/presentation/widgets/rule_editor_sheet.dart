import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/notification_priority.dart';
import '../../../../shared/models/notification_rule.dart';
import '../../../../shared/models/rule_models.dart';
import '../providers/rule_providers.dart';

/// Create or edit a single rule.
class RuleEditorSheet extends ConsumerStatefulWidget {
  const RuleEditorSheet({this.rule, super.key});

  final NotificationRule? rule;

  static Future<void> show(BuildContext context, {NotificationRule? rule}) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => RuleEditorSheet(rule: rule),
    );
  }

  @override
  ConsumerState<RuleEditorSheet> createState() => _RuleEditorSheetState();
}

class _RuleEditorSheetState extends ConsumerState<RuleEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _matchController;
  late final TextEditingController _actionValueController;

  late RuleMatchField _field;
  late RuleAction _action;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _nameController = TextEditingController(text: rule?.name ?? '');
    _matchController = TextEditingController(text: rule?.matchValue ?? '');
    _actionValueController = TextEditingController(
      text: rule?.actionValue ?? '${NotificationPriority.high.index}',
    );
    _field = rule?.matchField ?? RuleMatchField.title;
    _action = rule?.action ?? RuleAction.setPriority;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _matchController.dispose();
    _actionValueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final existing = widget.rule;
    final rule = NotificationRule(
      id: existing?.id ?? 0,
      name: _nameController.text.trim(),
      matchField: _field,
      matchValue: _matchController.text.trim(),
      action: _action,
      actionValue: _actionValueController.text.trim(),
      isEnabled: existing?.isEnabled ?? true,
      sortOrder: existing?.sortOrder ?? 100,
    );

    final notifier = ref.read(rulesProvider.notifier);
    existing == null ? await notifier.add(rule) : await notifier.save(rule);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.rule == null ? 'New rule' : 'Edit rule',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Rule name'),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Give the rule a name'
                      : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<RuleMatchField>(
                  initialValue: _field,
                  decoration: const InputDecoration(labelText: 'Match on'),
                  items: [
                    for (final field in RuleMatchField.values)
                      DropdownMenuItem(value: field, child: Text(field.label)),
                  ],
                  onChanged: (value) =>
                      setState(() => _field = value ?? RuleMatchField.title),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _matchController,
                  decoration: const InputDecoration(
                    labelText: 'Contains text',
                    hintText: 'for example: com.whatsapp or "invoice"',
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter the text to match'
                      : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<RuleAction>(
                  initialValue: _action,
                  decoration: const InputDecoration(labelText: 'Then'),
                  items: [
                    for (final action in RuleAction.values)
                      DropdownMenuItem(
                        value: action,
                        child: Text(action.label),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _action = value ?? RuleAction.setPriority),
                ),
                if (_action != RuleAction.mute) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _actionValueController,
                    decoration: InputDecoration(
                      labelText: switch (_action) {
                        RuleAction.setPriority =>
                          'Priority index (0 high, 1 normal, 2 low)',
                        RuleAction.assignCategory => 'Category name',
                        RuleAction.autoSnooze => 'Snooze minutes',
                        RuleAction.mute => '',
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(widget.rule == null ? 'Create rule' : 'Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
