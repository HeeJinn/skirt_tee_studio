import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skirt_tee_studio/core/theme/app_theme.dart';
import 'package:skirt_tee_studio/domain/entities/money_entry.dart';
import 'package:skirt_tee_studio/presentation/screens/money/widgets/money_entry_dialog.dart';

Future<MoneyEntry? Function()> _open(WidgetTester tester, MoneyEntryDialog dialog) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  MoneyEntry? result;
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showDialog<MoneyEntry>(context: context, builder: (_) => dialog),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => result;
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  testWidgets('an expense paid from the shop has a category and no owner', (tester) async {
    final result = await _open(
      tester,
      const MoneyEntryDialog(kind: MoneyEntryKind.expense, ownerNames: ['Ana', 'Ben']),
    );

    expect(find.text('WHOSE MONEY'), findsNothing);
    await tester.enterText(_field('Amount (₱)'), '8,000');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    final entry = result()!;
    expect(entry.kind, MoneyEntryKind.expense);
    expect(entry.amount, 8000);
    expect(entry.category, ExpenseCategory.rent);
    expect(entry.paidFrom, PaidFrom.shop);
    expect(entry.person, isNull);
    expect(entry.isOwnersMoneyIn, isFalse);
  });

  testWidgets('an expense the owners paid themselves asks whose money, and counts as money in', (tester) async {
    final result = await _open(
      tester,
      const MoneyEntryDialog(kind: MoneyEntryKind.expense, ownerNames: ['Ana', 'Ben']),
    );

    await tester.enterText(_field('Amount (₱)'), '1500');
    await tester.tap(find.text('Our own money'));
    await tester.pumpAndSettle();
    expect(find.text('Also counts toward what you\'ve put into the shop.'), findsOneWidget);
    await tester.tap(find.text('Ben'));
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(result()!.person, 'Ben');
    expect(result()!.isOwnersMoneyIn, isTrue);
  });

  testWidgets('taken home asks who took it, with no category', (tester) async {
    final result = await _open(
      tester,
      const MoneyEntryDialog(kind: MoneyEntryKind.ownerDraw, ownerNames: ['Ana', 'Ben']),
    );

    expect(find.text('What for'), findsNothing);
    expect(find.text('TAKEN BY'), findsOneWidget);
    await tester.enterText(_field('Amount (₱)'), '5000');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(result()!.kind, MoneyEntryKind.ownerDraw);
    expect(result()!.category, isNull);
    expect(result()!.person, isNull, reason: 'defaults to both');
  });

  testWidgets('refuses a missing or zero amount', (tester) async {
    final result = await _open(tester, const MoneyEntryDialog(kind: MoneyEntryKind.capitalIn, ownerNames: []));

    await tester.enterText(_field('Amount (₱)'), '0');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an amount'), findsOneWidget);
    expect(result(), isNull);
  });

  testWidgets('editing keeps the entry\'s id and kind', (tester) async {
    final existing = MoneyEntry(
      id: 'e1',
      at: DateTime(2026, 9, 1),
      kind: MoneyEntryKind.capitalIn,
      amount: 50000,
      person: 'Ana',
    );
    final result = await _open(
      tester,
      MoneyEntryDialog(kind: MoneyEntryKind.expense, ownerNames: const ['Ana', 'Ben'], entry: existing),
    );

    expect(find.text('EDIT · MONEY PUT IN'), findsOneWidget);
    await tester.enterText(_field('Amount (₱)'), '60000');
    await tester.tap(find.text('SAVE CHANGES'));
    await tester.pumpAndSettle();

    expect(result()!.id, 'e1');
    expect(result()!.kind, MoneyEntryKind.capitalIn);
    expect(result()!.amount, 60000);
    expect(result()!.person, 'Ana');
  });
}
