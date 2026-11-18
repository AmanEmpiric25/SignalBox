import 'package:sqflite/sqflite.dart';

import '../../../shared/models/notification_item.dart';
import '../../../shared/models/notification_priority.dart';
import '../domain/notification_filter.dart';
import '../domain/notification_query.dart';

/// Read and write access to the `notification_items` table.
///
/// The repository owns every SQL statement that touches notifications. UI and
/// providers never build SQL themselves.
class NotificationRepository {
  const NotificationRepository(this._db);

  final Database _db;

  static const String _table = 'notification_items';

  /// One page of the inbox, newest first.
  ///
  /// This is the inbox view, so notifications from muted applications are left
  /// out. They are still stored, still listed by [forPackage] and still
  /// counted in Statistics.
  Future<List<NotificationItem>> page({
    NotificationFilter filter = NotificationFilter.empty,
    required int limit,
    required int offset,
  }) async {
    final (where, args) = NotificationQuery.where(filter, excludeMuted: true);
    final rows = await _db.query(
      _table,
      where: where,
      whereArgs: args,
      orderBy: 'posted_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(NotificationItem.fromMap).toList();
  }

  /// Every notification matching [filter] without paging.
  ///
  /// Unlike [page] this does **not** hide muted applications: it is the
  /// unscoped read, used where the caller wants the whole matching set rather
  /// than the inbox view.
  Future<List<NotificationItem>> all({
    NotificationFilter filter = NotificationFilter.empty,
  }) async {
    final (where, args) = NotificationQuery.where(filter);
    final rows = await _db.query(
      _table,
      where: where,
      whereArgs: args,
      orderBy: 'posted_at DESC, id DESC',
    );
    return rows.map(NotificationItem.fromMap).toList();
  }

  /// Notifications belonging to a single application, newest first.
  Future<List<NotificationItem>> forPackage(String packageName) async {
    final rows = await _db.query(
      _table,
      where: 'package_name = ? AND is_archived = 0',
      whereArgs: [packageName],
      orderBy: 'posted_at DESC, id DESC',
    );
    return rows.map(NotificationItem.fromMap).toList();
  }

  Future<NotificationItem?> byId(int id) async {
    final rows = await _db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return NotificationItem.fromMap(rows.first);
  }

  /// Number of notifications matching [filter].
  Future<int> count({
    NotificationFilter filter = NotificationFilter.empty,
  }) async {
    final (where, args) = NotificationQuery.where(filter);
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table WHERE $where',
      args,
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Number of unread, unarchived notifications shown in the inbox.
  ///
  /// This is the badge above the list, so it has to agree with [page]: muted
  /// applications are excluded. A badge that counted notifications the user
  /// cannot see in the list would be unexplainable. It shares [page]'s clause
  /// rather than hard-coding its own, so the two cannot drift apart.
  Future<int> unreadCount() async {
    final (where, args) = NotificationQuery.where(
      NotificationFilter.empty,
      excludeMuted: true,
    );
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table WHERE ($where) AND is_read = 0',
      args,
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Whether this notification has already been captured.
  ///
  /// Android re-posts a notification under the same key when it is updated, so
  /// the key alone is not unique; the key plus the post time is.
  Future<bool> existsByNativeKey(String? nativeKey, DateTime postedAt) async {
    if (nativeKey == null) return false;
    final rows = await _db.query(
      _table,
      columns: ['id'],
      where: 'native_key = ? AND posted_at = ?',
      whereArgs: [nativeKey, postedAt.millisecondsSinceEpoch],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> insert(NotificationItem item) =>
      _db.insert(_table, item.toMap()..remove('id'));

  Future<void> setRead(int id, {bool isRead = true}) async {
    await _db.update(
      _table,
      {'is_read': isRead ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marks the notifications matching the current view as read.
  ///
  /// [filter] is the inbox's active filter, so the button marks exactly what
  /// the user can see and nothing else. It is built from the same
  /// [NotificationQuery.where] clause the list itself uses, which means
  /// archived notifications are left alone unless `includeArchived` is set, and
  /// a notification that is still snoozed — and so absent from the list — is
  /// not marked either.
  ///
  /// With no filter active this marks every unread notification in the inbox,
  /// which is the behaviour the button has always advertised.
  ///
  /// Muted applications are excluded, matching [page] and [unreadCount]. The
  /// button sits above the inbox, so marking notifications that are not in the
  /// inbox — and are not in the badge either — would be the same confusion this
  /// method was fixed for in the first place.
  Future<void> markAllAsRead(NotificationFilter filter) async {
    final (where, args) = NotificationQuery.where(filter, excludeMuted: true);
    await _db.update(
      _table,
      {'is_read': 1},
      where: '($where) AND is_read = 0',
      whereArgs: args,
    );
  }

  Future<void> setArchived(int id, {bool isArchived = true}) async {
    await _db.update(
      _table,
      {'is_archived': isArchived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setPriority(int id, NotificationPriority priority) async {
    await _db.update(
      _table,
      {'priority': priority.index},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setCategory(int id, int? categoryId) async {
    await _db.update(
      _table,
      {'category_id': categoryId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hides a notification from the inbox for [duration].
  Future<void> snooze(int id, Duration duration) async {
    final until = DateTime.now().add(duration);
    await _db.update(
      _table,
      {'snooze_until': until.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearSnooze(int id) async {
    await _db.update(
      _table,
      {'snooze_until': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Notifications whose snooze window is still open, soonest first.
  Future<List<NotificationItem>> snoozed() async {
    final rows = await _db.query(
      _table,
      where: 'snooze_until IS NOT NULL AND snooze_until > ?',
      whereArgs: [DateTime.now().millisecondsSinceEpoch],
      orderBy: 'snooze_until ASC',
    );
    return rows.map(NotificationItem.fromMap).toList();
  }

  Future<void> delete(int id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMany(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await _db.delete(
      _table,
      where: 'id IN ($placeholders)',
      whereArgs: ids.toList(),
    );
  }

  /// Removes notifications older than [days]. Used by data retention.
  Future<int> deleteOlderThan(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _db.delete(
      _table,
      where: 'posted_at < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }

  Future<void> deleteAll() async => _db.delete(_table);
}
