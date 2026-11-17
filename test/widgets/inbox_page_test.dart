import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalbox/core/database/database_provider.dart';
import 'package:signalbox/core/services/preferences_provider.dart';
import 'package:signalbox/features/notifications/data/notification_repository.dart';
import 'package:signalbox/features/notifications/presentation/inbox_page.dart';
import 'package:signalbox/shared/models/notification_item.dart';
import 'package:signalbox/shared/models/notification_priority.dart';
import 'package:signalbox/shared/widgets/empty_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database.dart';

/// Pumping a full screen needs the database and preferences overrides that
/// `main()` normally installs. Use this as the template for regression tests
/// that reproduce an inbox bug end to end.
void main() {
  setUpAll(initTestDatabase);

  late Database db;
  late SharedPreferences prefs;

  setUp(() async {
    db = await openTestDatabase();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();

    await db.insert('app_sources', {
      'package_name': 'com.whatsapp',
      'app_label': 'WhatsApp',
      'is_muted': 0,
      'first_seen_at': DateTime.now().millisecondsSinceEpoch,
    });
  });

  tearDown(() async => db.close());

  Future<void> addNotification({
    String title = 'Priya Sharma',
    String body = 'Are we still meeting at 6?',
    bool isRead = false,
  }) {
    return NotificationRepository(db).insert(
      NotificationItem(
        id: 0,
        packageName: 'com.whatsapp',
        title: title,
        body: body,
        postedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        priority: NotificationPriority.normal,
        isRead: isRead,
      ),
    );
  }

  Future<void> pumpInbox(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: InboxPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state when nothing has been captured', (
    tester,
  ) async {
    await pumpInbox(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Your inbox is empty'), findsOneWidget);
  });

  testWidgets('lists captured notifications under a date header', (
    tester,
  ) async {
    await addNotification();
    await pumpInbox(tester);

    expect(find.byType(EmptyState), findsNothing);
    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('reports how many notifications are in the inbox', (
    tester,
  ) async {
    await addNotification(title: 'One');
    await addNotification(title: 'Two');
    await pumpInbox(tester);

    expect(find.text('2 notifications'), findsOneWidget);
  });

  testWidgets('uses the singular form for a single notification', (
    tester,
  ) async {
    await addNotification();
    await pumpInbox(tester);

    expect(find.text('1 notification'), findsOneWidget);
  });

  testWidgets('mark-all-as-read is disabled when nothing is unread', (
    tester,
  ) async {
    await addNotification(isRead: true);
    await pumpInbox(tester);

    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.done_all_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('mark-all-as-read is enabled when something is unread', (
    tester,
  ) async {
    await addNotification();
    await pumpInbox(tester);

    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.done_all_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('typing in the search field filters the list', (tester) async {
    await addNotification(title: 'Invoice for November');
    await addNotification(title: 'Priya Sharma');
    await pumpInbox(tester);

    await tester.enterText(find.byType(TextField), 'Invoice');
    await tester.pumpAndSettle();

    expect(find.text('Invoice for November'), findsOneWidget);
    expect(find.text('Priya Sharma'), findsNothing);
  });

  testWidgets('a search that matches nothing explains itself', (tester) async {
    await addNotification(title: 'Priya Sharma');
    await pumpInbox(tester);

    await tester.enterText(find.byType(TextField), 'zomato');
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No matches for "zomato"'), findsOneWidget);
    expect(
      find.text('No notification title or body contains this text.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Clear search'), findsOneWidget);
  });

  testWidgets('the no-match state does not claim the inbox is empty', (
    tester,
  ) async {
    await addNotification(title: 'Priya Sharma');
    await pumpInbox(tester);

    await tester.enterText(find.byType(TextField), 'zomato');
    await tester.pumpAndSettle();

    // The inbox is not empty - the query simply missed. Saying otherwise
    // reads as data loss, and Refresh would re-fetch nothing.
    expect(find.text('Your inbox is empty'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Refresh'), findsNothing);
  });

  testWidgets('the first-run empty state still appears with no query', (
    tester,
  ) async {
    await pumpInbox(tester);

    // The failure mode of splitting these two states is the new one
    // swallowing the old one, so assert the negative as well.
    expect(find.text('Your inbox is empty'), findsOneWidget);
    expect(find.textContaining('No matches for'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Refresh'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Clear search'), findsNothing);
  });

  testWidgets('clearing the search from the empty state restores the list', (
    tester,
  ) async {
    await addNotification(title: 'Priya Sharma');
    await pumpInbox(tester);

    await tester.enterText(find.byType(TextField), 'zomato');
    await tester.pumpAndSettle();
    expect(find.text('Priya Sharma'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear search'));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsNothing);
    expect(find.text('Priya Sharma'), findsOneWidget);
    // The action also has to clear the text field, not just the filter.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('a long query is truncated in the empty-state title', (
    tester,
  ) async {
    await addNotification(title: 'Priya Sharma');
    await pumpInbox(tester);

    await tester.enterText(
      find.byType(TextField),
      'a very long search query that nobody would ever type',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No matches for "a very long search q\u2026"'),
      findsOneWidget,
    );
  });

  testWidgets('a truncated multi-byte query is not corrupted', (tester) async {
    await addNotification(title: 'Priya Sharma');
    await pumpInbox(tester);

    // 26 grapheme clusters, 51 UTF-16 code units. The leading 'x' shifts the
    // cut onto an odd code-unit boundary, which is where substring(0, 20)
    // used to slice a surrogate pair in half.
    await tester.enterText(find.byType(TextField), 'x${'😀' * 25}');
    await tester.pumpAndSettle();

    final title = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .firstWhere((t) => t.startsWith('No matches for'));

    // Assert the string is well formed, not merely short: a cut that corrupts
    // the text can still satisfy a length check.
    expect(title, isNot(contains('\ufffd')));
    expect(
      title.codeUnits.where((u) => u >= 0xD800 && u <= 0xDFFF).length.isEven,
      isTrue,
      reason: 'surrogates must remain in matched pairs',
    );
    // 20 characters kept, so 'x' plus 19 emoji, then the ellipsis.
    expect(title, 'No matches for "x${'😀' * 19}\u2026"');
  });

  testWidgets('truncation counts characters, not UTF-16 code units', (
    tester,
  ) async {
    await addNotification(title: 'Priya Sharma');
    await pumpInbox(tester);

    // 15 emoji is 30 code units but only 15 characters, so it is under the
    // limit and must come back whole.
    final query = '😀' * 15;
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();

    expect(find.text('No matches for "$query"'), findsOneWidget);
  });

  testWidgets('a whitespace-only query is not treated as a search', (
    tester,
  ) async {
    await pumpInbox(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pumpAndSettle();

    // A blank query matches everything, so this is still the first-run state.
    expect(find.text('Your inbox is empty'), findsOneWidget);
    expect(find.textContaining('No matches for'), findsNothing);
  });

  testWidgets('a filter badge appears once a filter is active', (tester) async {
    await addNotification();
    await pumpInbox(tester);

    expect(find.text('1'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Priya');
    await tester.pumpAndSettle();

    // The badge on the filter button counts the active constraints.
    expect(find.text('1'), findsWidgets);
  });
}
