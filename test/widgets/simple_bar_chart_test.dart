import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalbox/shared/widgets/simple_bar_chart.dart';

void main() {
  testWidgets('shows a placeholder when there is no data', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SimpleBarChart(data: <BarDatum>[])),
      ),
    );

    expect(find.text('No data for this range'), findsOneWidget);
  });

  testWidgets('renders one labelled bar per datum', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SimpleBarChart(
            data: <BarDatum>[
              BarDatum(label: '03-10', value: 4),
              BarDatum(label: '03-11', value: 7, highlight: true),
            ],
          ),
        ),
      ),
    );

    expect(find.text('03-10'), findsOneWidget);
    expect(find.text('03-11'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('handles an all-zero series without dividing by zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SimpleBarChart(
            data: <BarDatum>[
              BarDatum(label: 'a', value: 0),
              BarDatum(label: 'b', value: 0),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AnimatedContainer), findsNWidgets(2));
  });
}
