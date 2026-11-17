import '../../../shared/models/notification_priority.dart';

/// How the inbox and the statistics screen narrow down notifications.
///
/// The filter is immutable so that Riverpod can compare instances and skip
/// redundant rebuilds.
class NotificationFilter {
  const NotificationFilter({
    this.query = '',
    this.packageNames = const <String>{},
    this.priorities = const <NotificationPriority>{},
    this.categoryId,
    this.start,
    this.end,
    this.onlyUnread = false,
    this.includeArchived = false,
  });

  final String query;
  final Set<String> packageNames;
  final Set<NotificationPriority> priorities;
  final int? categoryId;

  /// Inclusive lower bound of the posted-at range.
  final DateTime? start;

  /// Inclusive upper bound of the posted-at range.
  final DateTime? end;

  final bool onlyUnread;
  final bool includeArchived;

  static const NotificationFilter empty = NotificationFilter();

  bool get isActive =>
      query.trim().isNotEmpty ||
      packageNames.isNotEmpty ||
      priorities.isNotEmpty ||
      categoryId != null ||
      start != null ||
      end != null ||
      onlyUnread ||
      includeArchived;

  /// Number of active constraints, shown as a badge on the filter button.
  int get activeCount => [
    query.trim().isNotEmpty,
    packageNames.isNotEmpty,
    priorities.isNotEmpty,
    categoryId != null,
    start != null || end != null,
    onlyUnread,
  ].where((active) => active).length;

  NotificationFilter copyWith({
    String? query,
    Set<String>? packageNames,
    Set<NotificationPriority>? priorities,
    int? categoryId,
    DateTime? start,
    DateTime? end,
    bool? onlyUnread,
    bool? includeArchived,
    bool clearCategory = false,
    bool clearDates = false,
  }) => NotificationFilter(
    query: query ?? this.query,
    packageNames: packageNames ?? this.packageNames,
    priorities: priorities ?? this.priorities,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    start: clearDates ? null : (start ?? this.start),
    end: clearDates ? null : (end ?? this.end),
    onlyUnread: onlyUnread ?? this.onlyUnread,
    includeArchived: includeArchived ?? this.includeArchived,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationFilter &&
      other.query == query &&
      other.categoryId == categoryId &&
      other.start == start &&
      other.end == end &&
      other.onlyUnread == onlyUnread &&
      other.includeArchived == includeArchived &&
      _setEquals(other.packageNames, packageNames) &&
      _setEquals(other.priorities, priorities);

  @override
  int get hashCode => Object.hash(
    query,
    categoryId,
    start,
    end,
    onlyUnread,
    includeArchived,
    packageNames.length,
    priorities.length,
  );

  static bool _setEquals<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);
}
