import 'package:flutter/material.dart';

/// Priority bucket assigned to a notification.
///
/// The [index] is persisted in the database, so the order of these values
/// must not change without a database migration.
enum NotificationPriority {
  high,
  normal,
  low;

  static NotificationPriority fromIndex(int index) {
    if (index < 0 || index >= NotificationPriority.values.length) {
      return NotificationPriority.normal;
    }
    return NotificationPriority.values[index];
  }

  String get label => switch (this) {
    NotificationPriority.high => 'High',
    NotificationPriority.normal => 'Normal',
    NotificationPriority.low => 'Low',
  };

  Color get color => switch (this) {
    NotificationPriority.high => const Color(0xFFE5484D),
    NotificationPriority.normal => const Color(0xFF3E63DD),
    NotificationPriority.low => const Color(0xFF8B8D98),
  };

  IconData get icon => switch (this) {
    NotificationPriority.high => Icons.priority_high_rounded,
    NotificationPriority.normal => Icons.notifications_none_rounded,
    NotificationPriority.low => Icons.low_priority_rounded,
  };
}
