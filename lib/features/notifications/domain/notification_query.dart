import '../../../core/extensions/date_time_x.dart';
import 'notification_filter.dart';

/// Translates a [NotificationFilter] into SQL.
///
/// Both the inbox and the statistics screen use this builder so that a filter
/// means exactly the same thing everywhere in the app.
class NotificationQuery {
  const NotificationQuery._();

  /// Excludes notifications belonging to a muted application.
  ///
  /// A muted app keeps collecting history — the rows stay in the table and the
  /// per-application screen and Statistics still show them — it just drops out
  /// of the inbox. `{c}` is replaced with the caller's column prefix.
  static const String _mutedExclusion =
      '{c}package_name NOT IN '
      '(SELECT package_name FROM app_sources WHERE is_muted = 1)';

  /// Builds the `WHERE` body (without the keyword) and its arguments.
  ///
  /// Pass [alias] when the statement joins another table, so that every
  /// column is qualified and cannot become ambiguous.
  ///
  /// Pass [excludeMuted] for the inbox and the unread badge, which hide muted
  /// applications. Statistics deliberately leaves it off: muting an app stops
  /// it cluttering the inbox, it does not erase it from the history.
  static (String where, List<Object?> args) where(
    NotificationFilter filter, {
    String alias = '',
    bool excludeMuted = false,
  }) {
    final c = alias.isEmpty ? '' : '$alias.';
    final clauses = <String>[];
    final args = <Object?>[];

    if (excludeMuted) {
      clauses.add(_mutedExclusion.replaceAll('{c}', c));
    }

    if (!filter.includeArchived) {
      clauses.add('${c}is_archived = 0');
    }

    final query = filter.query.trim();
    if (query.isNotEmpty) {
      // A notification is just as findable by what it said as by its title, so
      // the query matches either field. The clause is parenthesised because
      // every clause in this list is joined with AND.
      //
      // Case folding here is ASCII-only: SQLite's LIKE lowercases A-Z and
      // nothing else unless the build carries ICU, and `lower()` has the same
      // limit. So `upi` finds `UPI`, but a non-ASCII query only matches text
      // in the same case. Treat the search as case insensitive for ASCII and
      // case sensitive for everything else.
      const escape = "ESCAPE '$_likeEscape'";
      clauses.add('(${c}title LIKE ? $escape OR ${c}body LIKE ? $escape)');
      final pattern = '%${_escapeLike(query)}%';
      args.addAll([pattern, pattern]);
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

  /// Escape character used with SQL `LIKE`.
  static const String _likeEscape = r'\';

  /// Makes [value] safe to drop inside a `LIKE` pattern.
  ///
  /// Without this, a search for `%` or `_` would be read as a wildcard and
  /// match far more than the user typed. The escape character itself is
  /// doubled first, so that it cannot swallow the characters escaped after it.
  static String _escapeLike(String value) => value
      .replaceAll(_likeEscape, '$_likeEscape$_likeEscape')
      .replaceAll('%', '$_likeEscape%')
      .replaceAll('_', '${_likeEscape}_');
}
