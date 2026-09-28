import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/money_entry.dart';
import 'package:shop_core/domain/entities/stock.dart';
import 'package:skirt_tee_studio/presentation/screens/inventory/widgets/adjust_stock_dialog.dart';
import 'package:skirt_tee_studio/presentation/screens/inventory/widgets/category_field.dart';
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

const _costLabel = 'What you paid for each (₱)';

/// The lot's per-line piece counts, in line order.
final _qtyFields = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '0');

/// A field of Receive stock's quick-add line.
Finder _quick(String label) => find.widgetWithText(TextField, label);

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
      await tester.tap(find.text('Receive 20 Pieces'));
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
      await tester.tap(find.text('Receive'));
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

    testWidgets('a mixed bundle goes in one kind per quick line', (tester) async {
      final result = await _open<ReceivedLot>(tester, const ReceiveStockDialog(items: [_tee], ownerNames: []));
      await tester.enterText(_field('Price paid for the lot (₱)'), '2000');

      // No name: named after the category (the first one, T-Shirt).
      await tester.enterText(_quick('Sells for ₱'), '150');
      await tester.enterText(_quick('Pieces'), '12');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CategoryField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Long Sleeves').last);
      await tester.pumpAndSettle();
      await tester.enterText(_quick('Sells for ₱'), '180');
      await tester.enterText(_quick('Pieces'), '5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // A name already in inventory tops up that item, at its own price.
      await tester.enterText(_quick('Item name'), 'basic tee');
      await tester.enterText(_quick('Pieces'), '3');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('In this bundle: 15 T-Shirt · 5 Long Sleeves'), findsOneWidget);
      await tester.tap(find.text('Receive 20 Pieces'));
      await tester.pumpAndSettle();

      final lot = result()!;
      expect(lot.newItems.map((i) => (i.name, i.category, i.unitPrice)), [
        ('T-Shirt', 'T-Shirt', 150),
        ('Long Sleeves', 'Long Sleeves', 180),
      ]);
      expect(lot.lines.map((l) => (l.itemName, l.qty)), [('T-Shirt', 12), ('Long Sleeves', 5), ('Basic Tee', 3)]);
    });

    testWidgets('a quick line at a different price than the item with that name is refused', (tester) async {
      await _open<ReceivedLot>(tester, const ReceiveStockDialog(items: [_tee], ownerNames: []));

      await tester.enterText(_quick('Item name'), 'Basic Tee');
      await tester.enterText(_quick('Sells for ₱'), '200');
      await tester.enterText(_quick('Pieces'), '3');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.textContaining('"Basic Tee" already sells for ₱150.00'), findsOneWidget);
      expect(_qtyFields, findsNothing);
    });

    testWidgets('a filled-in quick line not yet added is received too', (tester) async {
      final result = await _open<ReceivedLot>(tester, const ReceiveStockDialog(items: [], ownerNames: []));

      await tester.enterText(_field('Price paid for the lot (₱)'), '500');
      await tester.enterText(_quick('Sells for ₱'), '100');
      await tester.enterText(_quick('Pieces'), '8');
      await tester.tap(find.text('Receive'));
      await tester.pumpAndSettle();

      expect(result()!.lines.single.qty, 8);
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
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Only 4 in stock'), findsOneWidget);

      await tester.enterText(_field('Pieces'), '2');
      await tester.tap(find.text('Remove'));
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
      await tester.tap(find.text('Add Back'));
      await tester.pumpAndSettle();

      expect(result()!.isFound, isTrue);
      expect(result()!.qty, 9);
    });
  });

  group('ItemFormDialog', () {
    testWidgets('a new item only asks what was paid once it has pieces on hand', (tester) async {
      final result = await _open<Item>(tester, const ItemFormDialog());

      expect(_field(_costLabel), findsNothing);
      await tester.enterText(_field('Name'), 'Basic Tee');
      await tester.enterText(_field('Sells for (₱)'), '150');
      await tester.enterText(_field('Already in stock'), '6');
      await tester.pumpAndSettle();
      await tester.enterText(_field(_costLabel), '60');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(result()!.qtyOnHand, 6);
      expect(result()!.unitCost, 60);
    });

    testWidgets('a cost typed for pieces that were then cleared is dropped', (tester) async {
      final result = await _open<Item>(tester, const ItemFormDialog());

      await tester.enterText(_field('Name'), 'Basic Tee');
      await tester.enterText(_field('Sells for (₱)'), '150');
      await tester.enterText(_field('Already in stock'), '6');
      await tester.pumpAndSettle();
      await tester.enterText(_field(_costLabel), '60');
      await tester.enterText(_field('Already in stock'), '0');
      await tester.pumpAndSettle();
      expect(_field(_costLabel), findsNothing);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(result()!.unitCost, isNull);
    });

    testWidgets('an item goes on sale by a percent off, previewing the price', (tester) async {
      final result = await _open<Item>(tester, const ItemFormDialog(item: _tee));

      await tester.tap(find.text('On sale'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('% off'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Percent off (%)'), '20');
      await tester.pumpAndSettle();
      expect(find.text('Sells for ₱120.00 instead of ₱150.00.'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result()!.onSale, isTrue);
      expect(result()!.salePercent, 20);
      expect(result()!.salePrice, isNull);
      expect(result()!.sellingPrice, 120);
    });

    testWidgets('a sale price has to be below the regular price', (tester) async {
      final result = await _open<Item>(tester, const ItemFormDialog(item: _tee));

      await tester.tap(find.text('On sale'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Sale price (₱)'), '150');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Less than the regular ₱150.00'), findsOneWidget);
      expect(result(), isNull);

      await tester.enterText(_field('Sale price (₱)'), '99');
      await tester.pumpAndSettle();
      expect(find.text('Sells for ₱99.00 instead of ₱150.00 — 34% off.'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result()!.salePrice, 99);
    });

    testWidgets('turning a sale off ends it', (tester) async {
      const onSale = Item(
        id: 'tee',
        name: 'Basic Tee',
        category: 'T-Shirt',
        unitPrice: 150,
        qtyOnHand: 4,
        onSale: true,
        salePercent: 20,
      );
      final result = await _open<Item>(tester, const ItemFormDialog(item: onSale));

      expect(find.text('Sells for ₱120.00 instead of ₱150.00.'), findsOneWidget);
      await tester.tap(find.text('On sale'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result()!.onSale, isFalse);
      expect(result()!.sellingPrice, 150);
    });

    testWidgets('an old Bargain tag asks for a discount', (tester) async {
      const tagged = Item(id: 'b', name: 'Bin Tee', category: 'T-Shirt', unitPrice: 50, qtyOnHand: 4, onSale: true);
      await _open<Item>(tester, const ItemFormDialog(item: tagged));

      expect(find.text('Tagged Sale with no discount yet — set one, or turn On sale off.'), findsOneWidget);
    });

    testWidgets('a category not on the list can be added from the form', (tester) async {
      final result = await _open<Item>(tester, const ItemFormDialog());

      await tester.tap(find.byType(CategoryField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New category…').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Name').last, 'Dress');
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();

      await tester.enterText(_field('Name'), 'Floral dress');
      await tester.enterText(_field('Sells for (₱)'), '600');
      await tester.enterText(_field('Already in stock'), '0');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(result()!.category, 'Dress');
    });

    testWidgets('typing a category that exists reuses its spelling', (tester) async {
      final result = await _open<Item>(tester, const ItemFormDialog());

      await tester.tap(find.byType(CategoryField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New category…').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Name').last, ' long sleeves ');
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
      await tester.enterText(_field('Name'), 'Striped top');
      await tester.enterText(_field('Sells for (₱)'), '180');
      await tester.enterText(_field('Already in stock'), '0');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(result()!.category, 'Long Sleeves');
    });

    testWidgets('an existing item shows its cost as text and keeps it unless changed', (tester) async {
      final result = await _open<Item>(tester, const ItemFormDialog(item: _tee));

      final stockField = tester.widget<TextFormField>(_field('In stock'));
      expect(stockField.enabled, isFalse);
      expect(_field(_costLabel), findsNothing);
      expect(find.text('You paid ₱100.00 each.'), findsOneWidget);
      await tester.enterText(_field('Sells for (₱)'), '160');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result()!.unitPrice, 160);
      expect(result()!.unitCost, 100);
      expect(result()!.qtyOnHand, 4);
    });

    testWidgets('an existing item\'s cost can be corrected behind Change', (tester) async {
      final result = await _open<Item>(tester, const ItemFormDialog(item: _tee));

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.enterText(_field(_costLabel), '90');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result()!.unitCost, 90);
    });

    testWidgets('old stock with no cost offers to set one', (tester) async {
      const oldStock = Item(id: 'old', name: 'Old Skirt', category: 'Skirt', unitPrice: 200, qtyOnHand: 3);
      final result = await _open<Item>(tester, const ItemFormDialog(item: oldStock));

      expect(find.text('No cost yet, so profit on these isn\'t counted.'), findsOneWidget);
      await tester.tap(find.text('Set Cost'));
      await tester.pumpAndSettle();
      await tester.enterText(_field(_costLabel), '80');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result()!.unitCost, 80);
    });

    testWidgets('an item with no pieces and no cost says nothing about cost', (tester) async {
      await _open<Item>(tester, const ItemFormDialog(item: _skirt));

      expect(find.text('Set Cost'), findsNothing);
      expect(find.textContaining('No cost yet'), findsNothing);
    });

    testWidgets('a new item for a lot asks for neither stock nor cost', (tester) async {
      final result = await _open<Item>(tester, const ItemFormDialog(forLot: true));

      expect(find.text('New Item in This Lot'), findsOneWidget);
      expect(_field(_costLabel), findsNothing);
      expect(_field('Already in stock'), findsNothing);
      await tester.enterText(_field('Name'), 'Kids Tee');
      await tester.enterText(_field('Sells for (₱)'), '100');
      await tester.tap(find.text('Add to Lot'));
      await tester.pumpAndSettle();

      expect(result()!.qtyOnHand, 0);
      expect(result()!.unitCost, isNull);
    });
  });
}
