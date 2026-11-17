import 'notification_priority.dart';

/// A single captured notification.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.packageName,
    required this.title,
    required this.body,
    required this.postedAt,
    required this.priority,
    this.categoryId,
    this.isRead = false,
    this.isArchived = false,
    this.snoozeUntil,
    this.nativeKey,
  });

  final int id;
  final String packageName;
  final String title;
  final String body;
  final DateTime postedAt;
  final NotificationPriority priority;
  final int? categoryId;
  final bool isRead;
  final bool isArchived;

  /// When set in the future, the notification is hidden from the inbox.
  final DateTime? snoozeUntil;

  /// Key supplied by the Android notification listener, used to de-duplicate.
  final String? nativeKey;

  bool get isSnoozed =>
      snoozeUntil != null && snoozeUntil!.isAfter(DateTime.now());

  factory NotificationItem.fromMap(Map<String, Object?> map) =>
      NotificationItem(
        id: map['id'] as int,
        packageName: map['package_name'] as String,
        title: (map['title'] as String?) ?? '',
        body: (map['body'] as String?) ?? '',
        postedAt: DateTime.fromMillisecondsSinceEpoch(map['posted_at'] as int),
        priority: NotificationPriority.fromIndex(
          (map['priority'] as int?) ?? NotificationPriority.normal.index,
        ),
        categoryId: map['category_id'] as int?,
        isRead: (map['is_read'] as int? ?? 0) == 1,
        isArchived: (map['is_archived'] as int? ?? 0) == 1,
        snoozeUntil: map['snooze_until'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['snooze_until'] as int),
        nativeKey: map['native_key'] as String?,
      );

  Map<String, Object?> toMap() => <String, Object?>{
    if (id > 0) 'id': id,
    'package_name': packageName,
    'title': title,
    'body': body,
    'posted_at': postedAt.millisecondsSinceEpoch,
    'priority': priority.index,
    'category_id': categoryId,
    'is_read': isRead ? 1 : 0,
    'is_archived': isArchived ? 1 : 0,
    'snooze_until': snoozeUntil?.millisecondsSinceEpoch,
    'native_key': nativeKey,
  };

  NotificationItem copyWith({
    String? title,
    String? body,
    NotificationPriority? priority,
    int? categoryId,
    bool? isRead,
    bool? isArchived,
    DateTime? snoozeUntil,
    bool clearSnooze = false,
  }) => NotificationItem(
    id: id,
    packageName: packageName,
    title: title ?? this.title,
    body: body ?? this.body,
    postedAt: postedAt,
    priority: priority ?? this.priority,
    categoryId: categoryId ?? this.categoryId,
    isRead: isRead ?? this.isRead,
    isArchived: isArchived ?? this.isArchived,
    snoozeUntil: clearSnooze ? null : (snoozeUntil ?? this.snoozeUntil),
    nativeKey: nativeKey,
  );
}
