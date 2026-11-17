import 'package:sqflite/sqflite.dart';

import '../../../shared/models/notification_category.dart';

/// Read and write access to the `categories` table.
class CategoryRepository {
  const CategoryRepository(this._db);

  final Database _db;

  static const String _table = 'categories';

  Future<List<NotificationCategory>> all() async {
    final rows = await _db.query(_table, orderBy: 'is_system DESC, name ASC');
    return rows.map(NotificationCategory.fromMap).toList();
  }

  Future<NotificationCategory?> byId(int id) async {
    final rows = await _db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return NotificationCategory.fromMap(rows.first);
  }

  /// How many unarchived notifications are assigned to each category id.
  Future<Map<int, int>> countsByCategory() async {
    final rows = await _db.rawQuery('''
      SELECT category_id AS id, COUNT(*) AS c
      FROM notification_items
      WHERE is_archived = 0 AND category_id IS NOT NULL
      GROUP BY category_id
    ''');
    return {for (final row in rows) row['id'] as int: (row['c'] as int?) ?? 0};
  }

  /// TODO(#custom-categories): user created categories are not implemented.
  /// The table and this method exist, but no screen calls them yet and there
  /// is no name/colour validation. See the "custom categories" issue.
  Future<int> create({required String name, required int colorValue}) async {
    return _db.insert(_table, {
      'name': name,
      'color_value': colorValue,
      'is_system': 0,
    });
  }

  /// TODO(#custom-categories): renaming and recolouring is not wired up.
  Future<void> update(NotificationCategory category) async {
    await _db.update(
      _table,
      {'name': category.name, 'color_value': category.colorValue},
      where: 'id = ? AND is_system = 0',
      whereArgs: [category.id],
    );
  }

  /// System categories are protected and cannot be removed.
  Future<void> delete(int id) async {
    await _db.delete(
      _table,
      where: 'id = ? AND is_system = 0',
      whereArgs: [id],
    );
  }
}
