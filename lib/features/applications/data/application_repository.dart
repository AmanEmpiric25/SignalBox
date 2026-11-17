import 'package:sqflite/sqflite.dart';

import '../../../shared/models/app_source.dart';
import '../domain/app_summary.dart';

/// Read and write access to `app_sources`, plus the per-application rollups
/// shown on the Applications screen.
class ApplicationRepository {
  const ApplicationRepository(this._db);

  final Database _db;

  static const String _table = 'app_sources';

  Future<List<AppSource>> all() async {
    final rows = await _db.query(
      _table,
      orderBy: 'app_label COLLATE NOCASE ASC',
    );
    return rows.map(AppSource.fromMap).toList();
  }

  Future<AppSource?> byPackage(String packageName) async {
    final rows = await _db.query(
      _table,
      where: 'package_name = ?',
      whereArgs: [packageName],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppSource.fromMap(rows.first);
  }

  /// Registers an application the first time a notification arrives from it.
  Future<void> upsert({
    required String packageName,
    required String appLabel,
  }) async {
    await _db.insert(_table, {
      'package_name': packageName,
      'app_label': appLabel,
      'is_muted': 0,
      'first_seen_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> setMuted(String packageName, bool isMuted) async {
    await _db.update(
      _table,
      {'is_muted': isMuted ? 1 : 0},
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  /// Per-application rollup: totals, unread counts, last activity and how many
  /// enabled rules target the package.
  ///
  /// Sorted by most recent activity.
  Future<List<AppSummary>> summaries() async {
    final rows = await _db.rawQuery('''
      SELECT
        a.package_name       AS package_name,
        a.app_label          AS app_label,
        a.is_muted           AS is_muted,
        COUNT(n.id)          AS total,
        SUM(CASE WHEN n.is_read = 0 THEN 1 ELSE 0 END) AS unread,
        MAX(n.posted_at)     AS last_posted_at,
        COUNT(DISTINCT r.id) AS matching_rules
      FROM app_sources a
      LEFT JOIN notification_items n
        ON n.package_name = a.package_name AND n.is_archived = 0
      LEFT JOIN rules r
        ON r.is_enabled = 1
       AND r.match_field = 0
       AND r.match_value = a.package_name
      GROUP BY a.package_name, a.app_label, a.is_muted
      ORDER BY last_posted_at DESC
    ''');

    return rows.map((row) {
      final last = row['last_posted_at'] as int?;
      return AppSummary(
        packageName: row['package_name'] as String,
        appLabel: row['app_label'] as String,
        total: (row['total'] as int?) ?? 0,
        unread: (row['unread'] as int?) ?? 0,
        lastPostedAt: last == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(last),
        isMuted: ((row['is_muted'] as int?) ?? 0) == 1,
        matchingRules: (row['matching_rules'] as int?) ?? 0,
      );
    }).toList();
  }
}
