import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalbox/features/statistics/presentation/widgets/breakdown_bar.dart';

void main() {
  Future<void> pump(WidgetTester tester, int value, int total) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BreakdownBar(
            label: 'WhatsApp',
            value: value,
            total: total,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the label and value', (tester) async {
    await pump(tester, 12, 40);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('computes the proportion', (tester) async {
    await pump(tester, 10, 40);
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, closeTo(0.25, 0.0001));
  });

  testWidgets('a zero total does not divide by zero', (tester) async {
    await pump(tester, 0, 0);
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, 0.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a value above the total is clamped', (tester) async {
    await pump(tester, 50, 40);
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, 1.0);
  });
}
