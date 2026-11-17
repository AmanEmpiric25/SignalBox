import 'package:sqflite/sqflite.dart';

import '../../shared/models/notification_priority.dart';
import '../../shared/models/rule_models.dart';

/// Deterministic demo data.
///
/// SignalBox is local-first and, on a fresh install without the Android
/// notification-listener permission, there is nothing to show. The seed gives
/// every contributor the same inbox so that issues can be reproduced with
/// identical steps on any machine.
class SeedData {
  const SeedData._();

  static const List<(String packageName, String label)> apps = [
    ('com.whatsapp', 'WhatsApp'),
    ('com.google.android.gm', 'Gmail'),
    ('com.slack', 'Slack'),
    ('com.instagram.android', 'Instagram'),
    ('com.hdfcbank.payzapp', 'HDFC Bank'),
    ('in.swiggy.android', 'Swiggy'),
    ('com.android.systemui', 'System UI'),
  ];

  static Future<void> insertSystemCategories(Database db) async {
    const seeds = <(String, int)>[
      ('Messages', 0xFF3E63DD),
      ('Social', 0xFF8E4EC6),
      ('Finance', 0xFF2E9E5B),
      ('Promotions', 0xFFE5A32A),
      ('System', 0xFF8B8D98),
    ];
    final batch = db.batch();
    for (final seed in seeds) {
      batch.insert('categories', {
        'name': seed.$1,
        'color_value': seed.$2,
        'is_system': 1,
      });
    }
    await batch.commit(noResult: true);
  }

  /// True when the database has never been seeded.
  static Future<bool> isEmpty(Database db) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM notification_items',
    );
    return ((rows.first['c'] as int?) ?? 0) == 0;
  }

  /// Inserts the demo apps, notifications and rules.
  ///
  /// Safe to call repeatedly: it returns immediately when data already exists.
  static Future<void> insert(Database db) async {
    if (!await SeedData.isEmpty(db)) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final appBatch = db.batch();
    for (final app in apps) {
      appBatch.insert('app_sources', {
        'package_name': app.$1,
        'app_label': app.$2,
        'is_muted': app.$1 == 'com.android.systemui' ? 1 : 0,
        'first_seen_at': today
            .subtract(const Duration(days: 45))
            .millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await appBatch.commit(noResult: true);

    final categories = await db.query('categories');
    int categoryId(String name) =>
        categories.firstWhere(
              (c) => c['name'] == name,
              orElse: () => categories.first,
            )['id']
            as int;

    final batch = db.batch();

    void add({
      required String package,
      required String title,
      required String body,
      required DateTime postedAt,
      NotificationPriority priority = NotificationPriority.normal,
      String? category,
      bool isRead = false,
      bool isArchived = false,
      DateTime? snoozeUntil,
    }) {
      batch.insert('notification_items', {
        'package_name': package,
        'title': title,
        'body': body,
        'posted_at': postedAt.millisecondsSinceEpoch,
        'priority': priority.index,
        'category_id': category == null ? null : categoryId(category),
        'is_read': isRead ? 1 : 0,
        'is_archived': isArchived ? 1 : 0,
        'snooze_until': snoozeUntil?.millisecondsSinceEpoch,
        'native_key': '0|$package|${postedAt.millisecondsSinceEpoch}',
      });
    }

    // --- Today -------------------------------------------------------------
    add(
      package: 'com.whatsapp',
      title: 'Priya Sharma',
      body: 'Are we still meeting at 6? Let me know.',
      postedAt: today.add(const Duration(hours: 9, minutes: 12)),
      category: 'Messages',
      priority: NotificationPriority.high,
    );
    add(
      package: 'com.whatsapp',
      title: 'Design Team (4 messages)',
      body: 'Rohan: pushed the updated inbox mockups to Figma',
      postedAt: today.add(const Duration(hours: 9, minutes: 40)),
      category: 'Messages',
    );
    add(
      package: 'com.hdfcbank.payzapp',
      title: 'Payment received',
      body: 'Your UPI transaction of INR 2,400 was credited successfully.',
      postedAt: today.add(const Duration(hours: 10, minutes: 5)),
      category: 'Finance',
      priority: NotificationPriority.high,
    );
    add(
      package: 'com.google.android.gm',
      title: 'Invoice for November',
      body: 'Your subscription receipt is attached. Amount: INR 499.',
      postedAt: today.add(const Duration(hours: 10, minutes: 30)),
      category: 'Finance',
      isRead: true,
    );
    add(
      package: 'com.slack',
      title: 'mentioned you in #release',
      body: 'Aman: can you review the signalbox changelog before the cut?',
      postedAt: today.add(const Duration(hours: 11, minutes: 15)),
      category: 'Messages',
      priority: NotificationPriority.high,
    );
    add(
      package: 'in.swiggy.android',
      title: 'Flat 60% off on your next order',
      body: 'Use code SIGNAL60. Valid until midnight.',
      postedAt: today.add(const Duration(hours: 12)),
      category: 'Promotions',
      priority: NotificationPriority.low,
    );
    add(
      package: 'com.instagram.android',
      title: 'nikhil started following you',
      body: 'Tap to see their profile.',
      postedAt: today.add(const Duration(hours: 13, minutes: 20)),
      category: 'Social',
      priority: NotificationPriority.low,
      isRead: true,
    );

    // Two notifications with an identical timestamp: used to reproduce the
    // unstable-sort issue.
    final tie = today.add(const Duration(hours: 14));
    add(
      package: 'com.slack',
      title: 'Build passed',
      body: 'signalbox/main finished in 2m 14s.',
      postedAt: tie,
      category: 'System',
    );
    add(
      package: 'com.google.android.gm',
      title: 'Weekly report is ready',
      body: 'Your notification digest for this week is available.',
      postedAt: tie,
      category: 'System',
    );

    // A notification snoozed into the future: used to reproduce the snooze
    // boundary issue.
    add(
      package: 'in.swiggy.android',
      title: 'Rate your last order',
      body: 'How was the food from Burma Burma?',
      postedAt: today.add(const Duration(hours: 15)),
      category: 'Promotions',
      priority: NotificationPriority.low,
      snoozeUntil: now.add(const Duration(hours: 3)),
    );

    // --- Yesterday and the past month -------------------------------------
    const bodies = <String>[
      'Tap to open the conversation.',
      'You have a new update waiting.',
      'Your order is out for delivery.',
      'Someone commented on your post.',
      'A debit of INR 320 was made from your account.',
      'Storage is almost full.',
      'Two new messages in this chat.',
    ];
    const titles = <String>[
      'New message',
      'Update available',
      'Order on the way',
      'New comment',
      'Transaction alert',
      'Low storage',
      'Unread messages',
    ];
    const categoryNames = <String>[
      'Messages',
      'System',
      'Promotions',
      'Social',
      'Finance',
      'System',
      'Messages',
    ];

    for (var day = 1; day <= 29; day++) {
      final perDay = 1 + (day % 3);
      for (var n = 0; n < perDay; n++) {
        final idx = (day + n) % apps.length;
        add(
          package: apps[idx].$1,
          title: titles[idx],
          body: bodies[idx],
          postedAt: today
              .subtract(Duration(days: day))
              .add(Duration(hours: 8 + n * 4, minutes: 10 * n + day % 50)),
          priority: NotificationPriority.fromIndex((day + n) % 3),
          category: categoryNames[idx],
          isRead: day > 3,
          isArchived: day > 20 && n == 0,
        );
      }
    }

    await batch.commit(noResult: true);

    // --- Rules -------------------------------------------------------------
    final ruleBatch = db.batch();
    void addRule({
      required String name,
      required RuleMatchField field,
      required String value,
      required RuleAction action,
      required String actionValue,
      bool enabled = true,
      int order = 0,
    }) {
      ruleBatch.insert('rules', {
        'name': name,
        'match_field': field.index,
        'match_value': value,
        'action_type': action.index,
        'action_value': actionValue,
        'is_enabled': enabled ? 1 : 0,
        'sort_order': order,
      });
    }

    addRule(
      name: 'Bank alerts are high priority',
      field: RuleMatchField.packageName,
      value: 'com.hdfcbank.payzapp',
      action: RuleAction.setPriority,
      actionValue: '${NotificationPriority.high.index}',
      order: 0,
    );
    addRule(
      name: 'Offers are low priority',
      field: RuleMatchField.title,
      value: 'off on your next order',
      action: RuleAction.setPriority,
      actionValue: '${NotificationPriority.low.index}',
      order: 1,
    );
    addRule(
      name: 'WhatsApp goes to Messages',
      field: RuleMatchField.packageName,
      value: 'com.whatsapp',
      action: RuleAction.assignCategory,
      actionValue: 'Messages',
      order: 2,
    );
    addRule(
      name: 'WhatsApp is high priority',
      field: RuleMatchField.packageName,
      value: 'com.whatsapp',
      action: RuleAction.setPriority,
      actionValue: '${NotificationPriority.high.index}',
      order: 3,
    );
    addRule(
      name: 'Mute system UI',
      field: RuleMatchField.packageName,
      value: 'com.android.systemui',
      action: RuleAction.mute,
      actionValue: '',
      enabled: false,
      order: 4,
    );
    await ruleBatch.commit(noResult: true);
  }
}
