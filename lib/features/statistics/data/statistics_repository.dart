import 'package:sqflite/sqflite.dart';

import '../../../shared/models/notification_priority.dart';
import '../../notifications/domain/notification_filter.dart';
import '../../notifications/domain/notification_query.dart';
import '../domain/statistics_models.dart';

/// Aggregate queries behind the Statistics screen.
class StatisticsRepository {
  const StatisticsRepository(this._db);

  final Database _db;

  /// Builds the full statistics payload for [filter].
  Future<NotificationStatistics> load(NotificationFilter filter) async {
    final (where, args) = NotificationQuery.where(filter);
    final (joinWhere, joinArgs) = NotificationQuery.where(filter, alias: 'n');

    // The headline card has to agree with the breakdowns under it, so it uses
    // the same clause they do rather than a hard-coded one of its own.
    final totalRows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM notification_items WHERE $where',
      args,
    );
    final unreadRows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM notification_items WHERE $where AND is_read = 0',
      args,
    );
    final snoozedRows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM notification_items '
      'WHERE snooze_until IS NOT NULL AND snooze_until > ?',
      [DateTime.now().millisecondsSinceEpoch],
    );

    return NotificationStatistics(
      total: (totalRows.first['c'] as int?) ?? 0,
      unread: (unreadRows.first['c'] as int?) ?? 0,
      snoozed: (snoozedRows.first['c'] as int?) ?? 0,
      perDay: await _perDay(where, args),
      perApp: await _perApp(joinWhere, joinArgs),
      perCategory: await _perCategory(joinWhere, joinArgs),
      perPriority: await _perPriority(where, args),
    );
  }

  Future<List<DayCount>> _perDay(String where, List<Object?> args) async {
    final rows = await _db.rawQuery('''
      SELECT
        date(posted_at / 1000, 'unixepoch', 'localtime') AS day,
        COUNT(*) AS c
      FROM notification_items
      WHERE $where
      GROUP BY day
      ORDER BY day ASC
    ''', args);

    return rows
        .map(
          (row) => DayCount(
            day: DateTime.parse(row['day'] as String),
            count: (row['c'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  Future<List<AppCount>> _perApp(String where, List<Object?> args) async {
    final rows = await _db.rawQuery('''
      SELECT
        n.package_name AS package_name,
        COALESCE(a.app_label, n.package_name) AS app_label,
        COUNT(*) AS c
      FROM notification_items n
      LEFT JOIN app_sources a ON a.package_name = n.package_name
      WHERE $where
      GROUP BY n.package_name, app_label
      ORDER BY c DESC
    ''', args);

    return rows
        .map(
          (row) => AppCount(
            packageName: row['package_name'] as String,
            appLabel: row['app_label'] as String,
            count: (row['c'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  Future<List<CategoryCount>> _perCategory(
    String where,
    List<Object?> args,
  ) async {
    final rows = await _db.rawQuery('''
      SELECT
        n.category_id AS category_id,
        COALESCE(c.name, 'Uncategorised') AS name,
        COALESCE(c.color_value, 0xFF8B8D98) AS color_value,
        COUNT(*) AS c
      FROM notification_items n
      LEFT JOIN categories c ON c.id = n.category_id
      WHERE $where
      GROUP BY n.category_id, name, color_value
      ORDER BY c DESC
    ''', args);

    return rows
        .map(
          (row) => CategoryCount(
            categoryId: row['category_id'] as int?,
            name: row['name'] as String,
            colorValue: (row['color_value'] as int?) ?? 0xFF8B8D98,
            count: (row['c'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  Future<Map<NotificationPriority, int>> _perPriority(
    String where,
    List<Object?> args,
  ) async {
    final rows = await _db.rawQuery('''
      SELECT priority, COUNT(*) AS c
      FROM notification_items
      WHERE $where
      GROUP BY priority
    ''', args);

    return {
      for (final row in rows)
        NotificationPriority.fromIndex((row['priority'] as int?) ?? 1):
            (row['c'] as int?) ?? 0,
    };
  }
}
