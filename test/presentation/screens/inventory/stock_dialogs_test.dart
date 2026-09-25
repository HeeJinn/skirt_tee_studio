import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skirt_tee_studio/core/theme/app_theme.dart';
import 'package:skirt_tee_studio/domain/entities/item.dart';
import 'package:skirt_tee_studio/domain/entities/money_entry.dart';
import 'package:skirt_tee_studio/domain/entities/stock.dart';
import 'package:skirt_tee_studio/presentation/screens/inventory/widgets/adjust_stock_dialog.dart';
import 'package:skirt_tee_studio/presentation/screens/inventory/widgets/item_form_dialog.dart';
import 'package:skirt_tee_studio/presentation/screens/inventory/widgets/receive_stock_dialog.dart';

const _tee = Item(id: 'tee', name: 'Basic Tee', category: 'T-Shirt', unitPrice: 150, qtyOnHand: 4, unitCost: 100);
const _skirt = Item(id: 'skirt', name: 'A-line Skirt', category: 'Skirt', unitPrice: 250, qtyOnHand: 0);

/// Opens [dialog] from a button and returns a getter for what it popped.
Future<T? Function()> _open<T>(WidgetTester tester, Widget dialog) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  T? result;
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showDialog<T>(context: context, builder: (_) => dialog),
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

/// The lot's per-line piece counts, in line order.
final _qtyFields = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '0');

Future<void> _pickItem(WidgetTester tester, String name) async {
  await tester.enterText(find.widgetWithText(TextField, 'Add an item from inventory'), name.substring(0, 4));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  group('ReceiveStockDialog', () {
    testWidgets('previews each item\'s cost, split by selling price, and returns the lot', (tester) async {
      final result = await _open<ReceivedLot>(
        tester,
        const ReceiveStockDialog(items: [_tee, _skirt], ownerNames: ['Ana', 'Ben']),
      );

      await tester.enterText(_field('Supplier or source'), 'Divisoria');
      await tester.enterText(_field('Price paid for the lot (₱)'), '3,000');
      await tester.enterText(_field('Shipping & other fees (₱)'), '200');
      await _pickItem(tester, 'Basic Tee');
      await _pickItem(tester, 'A-line Skirt');
      await tester.enterText(_qtyFields.at(0), '10'); // sells for 1,500
      await tester.enterText(_qtyFields.at(1), '10'); // sells for 2,500
      await tester.pumpAndSettle();

      // ₱3,200 over ₱4,000 of selling value = 80% of price.
      expect(find.text('₱120.00'), findsOneWidget);
      expect(find.text('₱200.00'), findsOneWidget);
      expect(find.text('₱800.00 · 20%'), findsOneWidget);

      await tester.tap(find.text('Our own money'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RECEIVE 20 PIECES'));
      await tester.pumpAndSettle();

      final lot = result()!;
      expect(lot.lot.supplier, 'Divisoria');
      expect(lot.lot.itemsCost, 3000);
      expect(lot.lot.fees, 200);
      expect(lot.lot.paidFrom, PaidFrom.owners);
      expect(lot.lot.person, 'Ana');
      expect(lot.lines.map((l) => (l.itemId, l.qty)), [('tee', 10), ('skirt', 10)]);
      expect(lot.newItems, isEmpty);
    });

    testWidgets('won\'t save a lot with no items in it', (tester) async {
      final result = await _open<ReceivedLot>(tester, const ReceiveStockDialog(items: [_tee], ownerNames: []));

      await tester.enterText(_field('Price paid for the lot (₱)'), '500');
      await tester.tap(find.text('RECEIVE'));
      await tester.pumpAndSettle();

      expect(find.text('Add the items this lot was sorted into.'), findsOneWidget);
      expect(result(), isNull);
    });

    testWidgets('warns when the lot costs more than it can sell for', (tester) async {
      await _open<ReceivedLot>(tester, const ReceiveStockDialog(items: [_tee], ownerNames: []));

      await tester.enterText(_field('Price paid for the lot (₱)'), '2000');
      await _pickItem(tester, 'Basic Tee');
      await tester.enterText(_qtyFields, '10');
      await tester.pumpAndSettle();

      expect(find.text('This lot costs more than it can sell for at current prices.'), findsOneWidget);
    });

    testWidgets('with one owner, doesn\'t ask whose money it was', (tester) async {
      await _open<ReceivedLot>(tester, const ReceiveStockDialog(items: [_tee], ownerNames: ['Ana']));

      await tester.tap(find.text('Our own money'));
      await tester.pumpAndSettle();

      expect(find.text('Both of us'), findsNothing);
      expect(find.text('Counts toward what you\'ve put into the shop.'), findsOneWidget);
    });
  });

  group('AdjustStockDialog', () {
    testWidgets('states the loss at cost, and can\'t remove more than is in stock', (tester) async {
      final result = await _open<StockAdjustment>(tester, const AdjustStockDialog(item: _tee));

      await tester.enterText(_field('Pieces'), '5');
      await tester.pumpAndSettle();
      expect(find.text('Records a ₱500.00 loss at cost.'), findsOneWidget);
      await tester.tap(find.text('REMOVE'));
      await tester.pumpAndSettle();
      expect(find.text('Only 4 in stock'), findsOneWidget);

      await tester.enterText(_field('Pieces'), '2');
      await tester.tap(find.text('REMOVE'));
      await tester.pumpAndSettle();
      expect(result()!.qty, 2);
      expect(result()!.reason, WriteOffReason.damaged);
    });

    testWidgets('found pieces have no reason and no stock cap', (tester) async {
      final result = await _open<StockAdjustment>(tester, const AdjustStockDialog(item: _tee));

      await tester.tap(find.text('Found pieces'));
      await tester.pumpAndSettle();
      expect(find.text('Why'), findsNothing);
      await tester.enterText(_field('Pieces'), '9');
      await tester.tap(find.text('ADD BACK'));
      await tester.pumpAndSettle();

      expect(result()!.isFound, isTrue);
      expect(result()!.qty, 9);
    });
  });

  group('ItemFormDialog', () {
    testWidgets('an existing item\'s stock is read-only, but its cost can be corrected', (tester) async {
      final result = await _open<Item>(tester, const ItemFormDialog(item: _tee));

      final stockField = tester.widget<TextFormField>(_field('In stock'));
      expect(stockField.enabled, isFalse);
      await tester.enterText(_field('Cost each (₱)'), '90');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(result()!.unitCost, 90);
      expect(result()!.qtyOnHand, 4);
    });

    testWidgets('clearing the cost leaves it unknown', (tester) async {
      final result = await _open<Item>(tester, const ItemFormDialog(item: _tee));

      await tester.enterText(_field('Cost each (₱)'), '');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(result()!.unitCost, isNull);
    });

    testWidgets('a new item for a lot asks for neither stock nor cost', (tester) async {
      final result = await _open<Item>(tester, const ItemFormDialog(forLot: true));

      expect(find.text('NEW ITEM IN THIS LOT'), findsOneWidget);
      expect(_field('Cost each (₱)'), findsNothing);
      expect(_field('Already in stock'), findsNothing);
      await tester.enterText(_field('Name'), 'Kids Tee');
      await tester.enterText(_field('Price (₱)'), '100');
      await tester.tap(find.text('ADD TO LOT'));
      await tester.pumpAndSettle();

      expect(result()!.qtyOnHand, 0);
      expect(result()!.unitCost, isNull);
    });
  });
}
