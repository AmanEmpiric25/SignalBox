import 'package:flutter/material.dart';

/// A grouping bucket a notification can be assigned to.
class NotificationCategory {
  const NotificationCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.isSystem,
  });

  final int id;
  final String name;
  final int colorValue;

  /// System categories are seeded by the app and cannot be deleted.
  final bool isSystem;

  Color get color => Color(colorValue);

  factory NotificationCategory.fromMap(Map<String, Object?> map) =>
      NotificationCategory(
        id: map['id'] as int,
        name: map['name'] as String,
        colorValue: map['color_value'] as int,
        isSystem: (map['is_system'] as int? ?? 0) == 1,
      );

  Map<String, Object?> toMap() => <String, Object?>{
    if (id > 0) 'id': id,
    'name': name,
    'color_value': colorValue,
    'is_system': isSystem ? 1 : 0,
  };
}
