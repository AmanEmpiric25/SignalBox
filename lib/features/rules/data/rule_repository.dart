import 'package:sqflite/sqflite.dart';

import '../../../shared/models/notification_rule.dart';

/// Read and write access to the `rules` table.
class RuleRepository {
  const RuleRepository(this._db);

  final Database _db;

  static const String _table = 'rules';

  Future<List<NotificationRule>> all() async {
    final rows = await _db.query(_table, orderBy: 'sort_order ASC, id ASC');
    return rows.map(NotificationRule.fromMap).toList();
  }

  Future<List<NotificationRule>> enabled() async {
    final rows = await _db.query(
      _table,
      where: 'is_enabled = 1',
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(NotificationRule.fromMap).toList();
  }

  Future<int> insert(NotificationRule rule) =>
      _db.insert(_table, rule.toMap()..remove('id'));

  Future<void> update(NotificationRule rule) async {
    await _db.update(
      _table,
      rule.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [rule.id],
    );
  }

  Future<void> setEnabled(int id, bool isEnabled) async {
    await _db.update(
      _table,
      {'is_enabled': isEnabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
