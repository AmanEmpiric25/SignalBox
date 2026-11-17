import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';

/// Bottom sheet offering the snooze presets.
///
/// Returns the chosen [Duration], or null when dismissed.
class SnoozeSheet extends StatelessWidget {
  const SnoozeSheet({super.key});

  static Future<Duration?> show(BuildContext context) {
    return showModalBottomSheet<Duration>(
      context: context,
      showDragHandle: true,
      builder: (_) => const SnoozeSheet(),
    );
  }

  static String labelFor(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes ~/ 60;
    return hours == 1 ? '1 hour' : '$hours hours';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Snooze for',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          for (final minutes in AppConstants.snoozePresetsMinutes)
            ListTile(
              leading: const Icon(Icons.snooze_rounded),
              title: Text(labelFor(minutes)),
              onTap: () =>
                  Navigator.of(context).pop(Duration(minutes: minutes)),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
