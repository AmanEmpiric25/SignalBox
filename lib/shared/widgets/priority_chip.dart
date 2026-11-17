import 'package:flutter/material.dart';

import '../models/notification_priority.dart';

/// Small coloured label showing a notification's priority.
class PriorityChip extends StatelessWidget {
  const PriorityChip({required this.priority, this.compact = false, super.key});

  final NotificationPriority priority;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = priority.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
