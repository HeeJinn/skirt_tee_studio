import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'package:skirt_tee_studio/presentation/screens/pos/cash_tender_dialog.dart';

void main() {
  Future<Future<double?>> open(WidgetTester tester, double total) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late Future<double?> result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => result = showCashTenderDialog(context, total: total),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  Finder completeButton() => find.widgetWithText(ElevatedButton, 'Complete Sale');

  testWidgets('tapping bills adds them up, shows change with a breakdown, returns the amount', (tester) async {
    final result = await open(tester, 657);

    // Blocked until the customer's cash covers the total.
    await tester.tap(find.text('₱500'));
    await tester.pump();
    expect(find.text('Short by'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(completeButton()).onPressed, isNull);

    await tester.tap(find.text('₱100'));
    await tester.tap(find.text('₱100'));
    await tester.pump();

    expect(find.text('×2'), findsOneWidget); // ₱100 tapped twice
    expect(find.text('₱43.00'), findsOneWidget);
    expect(find.text('2 × ₱20'), findsOneWidget);
    expect(find.text('3 × ₱1'), findsOneWidget);

    await tester.tap(completeButton());
    await tester.pumpAndSettle();
    expect(await result, 700);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing replaces the tapped tally; Enter completes', (tester) async {
    final result = await open(tester, 857);

    await tester.tap(find.text('₱1,000'));
    await tester.pump();
    expect(find.text('×1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '900');
    await tester.pump();
    expect(find.text('×1'), findsNothing);
    expect(find.text('₱43.00'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(await result, 900);
  });

  testWidgets('exact amount completes with no change', (tester) async {
    final result = await open(tester, 250.75);

    await tester.tap(find.text('Exact'));
    await tester.pump();
    expect(find.text('Exact amount — no change'), findsOneWidget);

    await tester.tap(completeButton());
    await tester.pumpAndSettle();
    expect(await result, 250.75);
  });
}
