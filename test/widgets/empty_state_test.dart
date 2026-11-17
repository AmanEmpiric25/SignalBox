import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalbox/shared/widgets/empty_state.dart';

void main() {
  testWidgets('renders the icon and title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.inbox_rounded,
            title: 'Your inbox is empty',
          ),
        ),
      ),
    );

    expect(find.text('Your inbox is empty'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
  });

  testWidgets('renders the optional message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.inbox_rounded,
            title: 'Your inbox is empty',
            message: 'Captured notifications will appear here.',
          ),
        ),
      ),
    );

    expect(
      find.text('Captured notifications will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets('renders and wires the optional action', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.inbox_rounded,
            title: 'Nothing here',
            action: OutlinedButton(
              onPressed: () => pressed++,
              child: const Text('Refresh'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Refresh'));
    expect(pressed, 1);
  });

  testWidgets('omits the message and action when not provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(icon: Icons.inbox_rounded, title: 'Nothing here'),
        ),
      ),
    );

    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text('Nothing here'), findsOneWidget);
  });
}
