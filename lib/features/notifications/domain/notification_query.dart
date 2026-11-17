import '../../../core/extensions/date_time_x.dart';
import 'notification_filter.dart';

/// Translates a [NotificationFilter] into SQL.
///
/// Both the inbox and the statistics screen use this builder so that a filter
/// means exactly the same thing everywhere in the app.
class NotificationQuery {
  const NotificationQuery._();

  /// Builds the `WHERE` body (without the keyword) and its arguments.
  ///
  /// Pass [alias] when the statement joins another table, so that every
  /// column is qualified and cannot become ambiguous.
  static (String where, List<Object?> args) where(
    NotificationFilter filter, {
    String alias = '',
  }) {
    final c = alias.isEmpty ? '' : '$alias.';
    final clauses = <String>[];
    final args = <Object?>[];

    if (!filter.includeArchived) {
      clauses.add('${c}is_archived = 0');
    }

    final query = filter.query.trim();
    if (query.isNotEmpty) {
      clauses.add('${c}title LIKE ?');
      args.add('%$query%');
    }

    if (filter.packageNames.isNotEmpty) {
      final placeholders = List.filled(
        filter.packageNames.length,
        '?',
      ).join(',');
      clauses.add('${c}package_name IN ($placeholders)');
      args.addAll(filter.packageNames);
    }

    if (filter.priorities.isNotEmpty) {
      final placeholders = List.filled(filter.priorities.length, '?').join(',');
      clauses.add('${c}priority IN ($placeholders)');
      args.addAll(filter.priorities.map((p) => p.index));
    }

    if (filter.categoryId != null) {
      clauses.add('${c}category_id = ?');
      args.add(filter.categoryId);
    }

    if (filter.start != null) {
      clauses.add('${c}posted_at >= ?');
      args.add(filter.start!.startOfDay.millisecondsSinceEpoch);
    }

    if (filter.end != null) {
      clauses.add('${c}posted_at <= ?');
      args.add(filter.end!.startOfDay.millisecondsSinceEpoch);
    }

    if (filter.onlyUnread) {
      clauses.add('${c}is_read = 0');
    }

    // Notifications that are still snoozed stay out of every view.
    clauses.add('(${c}snooze_until IS NULL OR ${c}snooze_until <= ?)');
    args.add(DateTime.now().endOfDay.millisecondsSinceEpoch);

    if (clauses.isEmpty) return ('1 = 1', args);
    return (clauses.join(' AND '), args);
  }
}
