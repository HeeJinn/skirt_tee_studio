import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:skirt_tee_studio/data/datasources/local/item_local_data_source.dart';
import 'package:skirt_tee_studio/data/models/item_model.dart';
import 'package:skirt_tee_studio/data/repositories/stock_repository_impl.dart';
import 'package:skirt_tee_studio/domain/entities/item.dart';
import 'package:skirt_tee_studio/domain/entities/money_entry.dart';
import 'package:skirt_tee_studio/domain/entities/stock.dart';
import 'package:skirt_tee_studio/domain/repositories/stock_repository.dart';

import '../../test_helpers.dart';

void main() {
  late Database db;
  late ItemLocalDataSourceImpl items;
  late StockRepositoryImpl stock;

  final lot = StockLot(
    id: 'lot-1',
    at: DateTime(2026, 9, 1),
    supplier: 'Divisoria bale',
    itemsCost: 8000,
    fees: 400,
    paidFrom: PaidFrom.owners,
    person: 'Ana',
  );

  Future<Item> item(String id) async => (await items.getAll()).firstWhere((i) => i.id == id);

  setUp(() async {
    db = await openTestDatabase();
    items = ItemLocalDataSourceImpl(db);
    stock = StockRepositoryImpl(db);
    // Pre-tracking stock: on the shelf, no cost recorded.
    await items.insert(const ItemModel(id: 'tee', name: 'Basic Tee', category: 'T-Shirt', unitPrice: 150, qtyOnHand: 10));
    await items.insert(const ItemModel(
      id: 'skirt',
      name: 'A-line Skirt',
      category: 'Skirt',
      unitPrice: 250,
      qtyOnHand: 0,
      unitCost: 180,
    ));
  });

  group('receiveLot', () {
    test('adds pieces, splits cost by selling value, and re-averages each item', () async {
      await stock.receiveLot(lot, const [
        LotLine(itemId: 'tee', itemName: 'Basic Tee', qty: 30, sellingPrice: 150),
        LotLine(itemId: 'skirt', itemName: 'A-line Skirt', qty: 20, sellingPrice: 250),
        LotLine(itemId: 'kids', itemName: 'Kids Tee', qty: 10, sellingPrice: 100),
      ], newItems: const [
        Item(id: 'kids', name: 'Kids Tee', category: 'Kids', unitPrice: 100, qtyOnHand: 99),
      ]);

      final tee = await item('tee');
      expect(tee.qtyOnHand, 40);
      // 10 free pre-tracking pieces + 30 @ ₱120.
      expect(tee.unitCost, closeTo(90, 1e-9));
      final skirt = await item('skirt');
      expect(skirt.qtyOnHand, 20);
      expect(skirt.unitCost, closeTo(200, 1e-9), reason: 'empty shelf takes the lot cost outright');
      final kids = await item('kids');
      expect(kids.qtyOnHand, 10, reason: 'a new item starts from the lot, not its own quantity');
      expect(kids.unitCost, closeTo(80, 1e-9));

      final lots = await stock.getLots();
      expect(lots.single.totalCost, 8400);
      expect(lots.single.paidFrom, PaidFrom.owners);
      expect(lots.single.person, 'Ana');

      final movements = await stock.getMovements();
      expect(movements, hasLength(3));
      expect(movements.every((m) => m.type == StockMovementType.received && m.lotId == 'lot-1'), isTrue);
      expect(movements.fold<double>(0, (sum, m) => sum + m.value), closeTo(8400, 1e-6));
    });

    test('is all-or-nothing: a missing item rolls back the whole lot', () async {
      await expectLater(
        stock.receiveLot(lot, const [
          LotLine(itemId: 'tee', itemName: 'Basic Tee', qty: 5, sellingPrice: 150),
          LotLine(itemId: 'ghost', itemName: 'Ghost', qty: 5, sellingPrice: 150),
        ]),
        throwsA(isA<StockChangeException>()),
      );

      expect((await item('tee')).qtyOnHand, 10);
      expect(await stock.getLots(), isEmpty);
      expect(await stock.getMovements(), isEmpty);
    });

    test('refuses a line with no pieces', () async {
      await expectLater(
        stock.receiveLot(lot, const [LotLine(itemId: 'tee', itemName: 'Basic Tee', qty: 0, sellingPrice: 150)]),
        throwsA(isA<StockChangeException>()),
      );
    });
  });

  group('writeOff / markFound', () {
    setUp(() => db.update('items', {'qtyOnHand': 5}, where: 'id = ?', whereArgs: ['skirt']));

    test('writeOff removes pieces and books the loss at current cost', () async {
      await stock.writeOff('skirt', 2, WriteOffReason.damaged, note: 'torn hem');

      expect((await item('skirt')).qtyOnHand, 3);
      final m = (await stock.getMovements()).single;
      expect(m.type, StockMovementType.writeOff);
      expect(m.reason, WriteOffReason.damaged);
      expect(m.value, 360);
      expect(m.note, 'torn hem');
    });

    test('writeOff can\'t remove more than is on hand', () async {
      await expectLater(
        stock.writeOff('skirt', 6, WriteOffReason.lost),
        throwsA(isA<StockChangeException>()),
      );
      expect((await item('skirt')).qtyOnHand, 5);
      expect(await stock.getMovements(), isEmpty);
    });

    test('write-offs of stock with no recorded cost are worth ₱0', () async {
      await stock.writeOff('tee', 1, WriteOffReason.givenAway);
      expect((await stock.getMovements()).single.value, 0);
    });

    test('markFound adds pieces back at current cost without changing it', () async {
      await stock.markFound('skirt', 1);

      final skirt = await item('skirt');
      expect(skirt.qtyOnHand, 6);
      expect(skirt.unitCost, 180);
      expect((await stock.getMovements()).single.type, StockMovementType.found);
    });
  });

  group('removeItem', () {
    test('writes off whatever is still on hand, then deletes the item', () async {
      await db.update('items', {'qtyOnHand': 3}, where: 'id = ?', whereArgs: ['skirt']);

      await stock.removeItem('skirt');

      expect((await items.getAll()).map((i) => i.id), isNot(contains('skirt')));
      final m = (await stock.getMovements()).single;
      expect(m.reason, WriteOffReason.removed);
      expect(m.itemName, 'A-line Skirt');
      expect(m.value, 540);
    });

    test('an item with nothing on hand leaves no loss behind', () async {
      await stock.removeItem('skirt');
      expect(await stock.getMovements(), isEmpty);
    });

    test('a missing item is a no-op', () async {
      await stock.removeItem('ghost');
      expect(await items.getAll(), hasLength(2));
    });
  });
}
