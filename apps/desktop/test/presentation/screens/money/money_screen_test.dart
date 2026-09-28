// Widget-level test for MoneyScreen: the figures are computed by
// money_calculations (tested on its own); this checks they reach the
// screen, that the books' start date bounds them, and that the log and its
// dialogs are wired up.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/money_entry.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:shop_core/domain/entities/staff.dart';
import 'package:shop_core/domain/entities/stock.dart';
import 'package:skirt_tee_studio/presentation/screens/money/money_screen.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/inventory_view_model.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/money_view_model.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/sales_view_model.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/session_view_model.dart';

import 'package:shop_core/testing/fake_item_repository.dart';
import 'package:shop_core/testing/fake_money_repository.dart';
import 'package:shop_core/testing/fake_sale_repository.dart';
import '../../../fakes/fake_staff_repository.dart';
import 'package:shop_core/testing/fake_stock_repository.dart';

late SessionViewModel _session;

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final now = DateTime.now();
  DateTime daysAgo(int d) => now.subtract(Duration(days: d));

  final items = FakeItemRepository();
  await items.add(const Item(id: 'tee', name: 'Basic Tee', category: 'T-Shirt', unitPrice: 200, qtyOnHand: 15, unitCost: 120));
  final stock = FakeStockRepository(items);
  stock.lots.add(StockLot(id: 'lot-1', at: daysAgo(15), supplier: 'Bale', itemsCost: 3000));
  for (final qty in [15, 10]) {
    stock.movements.add(StockMovement(
      at: daysAgo(15),
      itemId: 'tee',
      itemName: 'Basic Tee',
      type: StockMovementType.received,
      qty: qty,
      unitCost: 120,
      lotId: 'lot-1',
    ));
  }

  final moneyRepo = FakeMoneyRepository(booksStartedAt: daysAgo(20));
  await moneyRepo.add(MoneyEntry(id: 'in', at: daysAgo(19), kind: MoneyEntryKind.capitalIn, amount: 10000));
  await moneyRepo.add(MoneyEntry(
    id: 'rent',
    at: daysAgo(10),
    kind: MoneyEntryKind.expense,
    amount: 500,
    category: ExpenseCategory.rent,
  ));

  final saleRepo = FakeSaleRepository();
  // From before the books started: must not count as earned back.
  await saleRepo.recordSale(Sale(
    id: 'old',
    dateTime: daysAgo(90),
    lineItems: const [SaleLineItem(itemId: 'tee', itemName: 'Basic Tee', unitPrice: 500, qty: 50)],
  ));
  await saleRepo.recordSale(Sale(
    id: 'new',
    dateTime: daysAgo(2),
    lineItems: const [SaleLineItem(itemId: 'tee', itemName: 'Basic Tee', unitPrice: 200, qty: 10, unitCost: 120)],
  ));

  final inventory = InventoryViewModel(items, stock);
  await inventory.load();
  final sales = SalesViewModel(saleRepo);
  await sales.load();
  final money = MoneyViewModel(moneyRepo, stock);
  await money.load();
  _session = await signedInSession();

  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: inventory),
      ChangeNotifierProvider.value(value: sales),
      ChangeNotifierProvider.value(value: money),
      ChangeNotifierProvider.value(value: _session),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: MoneyScreen())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('payback counts only what the shop earned since the books started', (tester) async {
    await _pump(tester);

    expect(tester.takeException(), isNull);
    // Sales ₱2,000 − cost ₱1,200 − rent ₱500 = ₱300 of the ₱10,000 put in.
    expect(find.text('3%'), findsOneWidget);
    expect(find.textContaining('earned ₱300 of the ₱10,000'), findsOneWidget);
    expect(find.text('Net profit'), findsWidgets);
    expect(find.text('₱1,800'), findsOneWidget, reason: 'stock on the rack: 15 × ₱120');
  });

  testWidgets('the log shows entries and lots, and filters by kind', (tester) async {
    await _pump(tester);

    expect(find.text('Stock · Bale'), findsOneWidget);
    expect(find.textContaining('25 pieces'), findsOneWidget);
    expect(find.text('Money put in'), findsOneWidget);

    await tester.tap(find.text('Expenses').last);
    await tester.pumpAndSettle();
    expect(find.text('Stock · Bale'), findsNothing);
    expect(find.text('Money put in'), findsNothing);
    expect(find.text('₱500.00 total'), findsOneWidget);
  });

  testWidgets('recording an expense adds it to the log and the activity trail', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Record Expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount (₱)'), '250');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('₱250.00'), findsOneWidget);
    expect(_session.activity.first.action, 'Recorded expense ₱250.00 · Rent');
  });

  testWidgets('deleting an entry asks first, then removes it', (tester) async {
    await _pump(tester);

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    expect(find.text('Delete Entry'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Delete'), findsOneWidget, reason: 'one of two entries left; lots aren\'t deletable here');
    expect(_session.activity.first.action, startsWith('Deleted '));
  });

  testWidgets('taking money home offers each owner by name', (tester) async {
    await _pump(tester);
    await _session.addStaff('Ben', StaffRole.owner, '9999');

    await tester.tap(find.text('Take Home'));
    await tester.pumpAndSettle();

    expect(find.text('Taken by'), findsOneWidget);
    expect(find.text('Ben'), findsOneWidget);
    expect(find.text('Olivia Owner'), findsOneWidget);
  });
}
