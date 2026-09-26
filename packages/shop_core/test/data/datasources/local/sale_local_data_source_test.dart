import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/data/datasources/local/item_local_data_source.dart';
import 'package:shop_core/data/datasources/local/sale_local_data_source.dart';
import 'package:shop_core/data/datasources/local/sql_helpers.dart';
import 'package:shop_core/data/models/item_model.dart';
import 'package:shop_core/data/models/sale_model.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:sqlite_async/sqlite_async.dart';

import '../../../test_helpers.dart';

void main() {
  late SqliteConnection db;
  late ItemLocalDataSourceImpl itemDataSource;
  late SaleLocalDataSourceImpl saleDataSource;

  setUp(() async {
    db = await openTestDatabase();
    itemDataSource = ItemLocalDataSourceImpl(db);
    saleDataSource = SaleLocalDataSourceImpl(db);
    await itemDataSource.insert(const ItemModel(
      id: 'item-1',
      name: 'Basic Tee',
      category: 'T-Shirt',
      unitPrice: 199,
      qtyOnHand: 10,
    ));
  });

  test('recordSale deducts stock for each line item', () async {
    final sale = SaleModel(
      id: 'sale-1',
      dateTime: DateTime(2026, 1, 1),
      lineItems: const [
        SaleLineItem(itemId: 'item-1', itemName: 'Basic Tee', unitPrice: 199, qty: 3),
      ],
    );

    await saleDataSource.recordSale(sale);

    final items = await itemDataSource.getAll();
    expect(items.single.qtyOnHand, 7);
  });

  test('recordSale writes sale + line item rows', () async {
    final sale = SaleModel(
      id: 'sale-1',
      dateTime: DateTime(2026, 1, 1),
      lineItems: const [
        SaleLineItem(itemId: 'item-1', itemName: 'Basic Tee', unitPrice: 199, qty: 2),
      ],
    );

    await saleDataSource.recordSale(sale);

    final salesRows = await db.query('sales');
    final lineRows = await db.query('sale_line_items');
    expect(salesRows, hasLength(1));
    expect(lineRows, hasLength(1));
    expect(lineRows.single['qty'], 2);
  });

  test('getAll returns sales newest first, with their line items', () async {
    await saleDataSource.recordSale(SaleModel(
      id: 'sale-1',
      dateTime: DateTime(2026, 1, 1),
      lineItems: const [
        SaleLineItem(itemId: 'item-1', itemName: 'Basic Tee', unitPrice: 199, qty: 1),
      ],
    ));
    await saleDataSource.recordSale(SaleModel(
      id: 'sale-2',
      dateTime: DateTime(2026, 1, 2),
      lineItems: const [
        SaleLineItem(itemId: 'item-1', itemName: 'Basic Tee', unitPrice: 199, qty: 2),
      ],
    ));

    final sales = await saleDataSource.getAll();

    expect(sales.map((s) => s.id).toList(), ['sale-2', 'sale-1']);
    expect(sales.first.lineItems.single.qty, 2);
  });

  test('voidSale restores stock and removes the sale + its line items', () async {
    final sale = SaleModel(
      id: 'sale-1',
      dateTime: DateTime(2026, 1, 1),
      lineItems: const [
        SaleLineItem(itemId: 'item-1', itemName: 'Basic Tee', unitPrice: 199, qty: 3),
      ],
    );
    await saleDataSource.recordSale(sale);

    await saleDataSource.voidSale('sale-1');

    final items = await itemDataSource.getAll();
    expect(items.single.qtyOnHand, 10);
    expect(await saleDataSource.getAll(), isEmpty);
    expect(await db.query('sale_line_items'), isEmpty);
  });

  test('recordSale books the item\'s cost at the time of sale, whatever the caller passed', () async {
    await db.update('items', {'unitCost': 80}, where: 'id = ?', whereArgs: ['item-1']);

    await saleDataSource.recordSale(SaleModel(
      id: 'sale-1',
      dateTime: DateTime(2026, 1, 1),
      lineItems: const [SaleLineItem(itemId: 'item-1', itemName: 'Basic Tee', unitPrice: 199, qty: 2, unitCost: 1)],
    ));
    // A later change of cost must not rewrite the sale.
    await db.update('items', {'unitCost': 120}, where: 'id = ?', whereArgs: ['item-1']);

    final line = (await saleDataSource.getAll()).single.lineItems.single;
    expect(line.unitCost, 80);
    expect(line.costOfGoods, 160);
  });

  test('recordSale leaves cost unknown for stock that never had one', () async {
    await saleDataSource.recordSale(SaleModel(
      id: 'sale-1',
      dateTime: DateTime(2026, 1, 1),
      lineItems: const [SaleLineItem(itemId: 'item-1', itemName: 'Basic Tee', unitPrice: 199, qty: 1)],
    ));

    final line = (await saleDataSource.getAll()).single.lineItems.single;
    expect(line.unitCost, isNull);
    expect(line.costOfGoods, 0);
  });

  test('voidSale returns pieces at the cost they sold at, re-averaging the item', () async {
    await db.update('items', {'qtyOnHand': 4, 'unitCost': 100}, where: 'id = ?', whereArgs: ['item-1']);
    await saleDataSource.recordSale(SaleModel(
      id: 'sale-1',
      dateTime: DateTime(2026, 1, 1),
      lineItems: const [SaleLineItem(itemId: 'item-1', itemName: 'Basic Tee', unitPrice: 199, qty: 2)],
    ));
    // A pricier lot arrives after the sale: 2 left @100 + 2 new @200 = avg 150.
    await db.update('items', {'qtyOnHand': 4, 'unitCost': 150}, where: 'id = ?', whereArgs: ['item-1']);

    await saleDataSource.voidSale('sale-1');

    final item = (await itemDataSource.getAll()).single;
    expect(item.qtyOnHand, 6);
    // (4 × 150 + 2 × 100) / 6
    expect(item.unitCost, closeTo(133.33, 0.01));
  });

  test('payment method round-trips; sales from before it existed read back as null', () async {
    await saleDataSource.recordSale(SaleModel(
      id: 'new',
      dateTime: DateTime(2026, 1, 2),
      paymentMethod: PaymentMethod.cashless,
      lineItems: const [SaleLineItem(itemId: 'item-1', itemName: 'Basic Tee', unitPrice: 199, qty: 1)],
    ));
    await db.insert('sales', {'id': 'legacy', 'dateTime': DateTime(2026, 1, 1).toIso8601String()});

    final byId = {for (final s in await saleDataSource.getAll()) s.id: s};
    expect(byId['new']!.paymentMethod, PaymentMethod.cashless);
    expect(byId['legacy']!.paymentMethod, isNull);
  });

  test('amount tendered round-trips; non-cash and older sales read back as null', () async {
    await saleDataSource.recordSale(SaleModel(
      id: 'cash',
      dateTime: DateTime(2026, 1, 2),
      paymentMethod: PaymentMethod.cash,
      amountTendered: 1000,
      lineItems: const [SaleLineItem(itemId: 'item-1', itemName: 'Basic Tee', unitPrice: 199, qty: 1)],
    ));
    await saleDataSource.recordSale(SaleModel(
      id: 'card',
      dateTime: DateTime(2026, 1, 2),
      paymentMethod: PaymentMethod.card,
      lineItems: const [SaleLineItem(itemId: 'item-1', itemName: 'Basic Tee', unitPrice: 199, qty: 1)],
    ));

    final byId = {for (final s in await saleDataSource.getAll()) s.id: s};
    expect(byId['cash']!.amountTendered, 1000);
    expect(byId['cash']!.changeGiven, 801);
    expect(byId['card']!.amountTendered, isNull);
    expect(byId['card']!.changeGiven, isNull);
  });
}
