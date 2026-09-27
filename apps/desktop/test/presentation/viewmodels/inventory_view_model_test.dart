import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/stock.dart';
import 'package:shop_core/domain/repositories/stock_repository.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/inventory_view_model.dart';

import 'package:shop_core/testing/fake_item_repository.dart';
import 'package:shop_core/testing/fake_stock_repository.dart';

void main() {
  late FakeItemRepository repository;
  late FakeStockRepository stock;
  late InventoryViewModel viewModel;

  setUp(() {
    repository = FakeItemRepository();
    stock = FakeStockRepository(repository);
    viewModel = InventoryViewModel(repository, stock);
  });

  const item = Item(
    id: '1',
    name: 'Basic Tee',
    category: 'T-Shirt',
    unitPrice: 199,
    qtyOnHand: 3,
  );

  test('addItem persists then reloads the list', () async {
    await viewModel.addItem(item);

    expect(viewModel.items, [item]);
  });

  test('updateItem reflects changes after reload', () async {
    await viewModel.addItem(item);
    await viewModel.updateItem(item.copyWith(unitPrice: 249));

    expect(viewModel.items.single.unitPrice, 249);
  });

  test('deleteItem goes through the stock repository, so remaining stock is written off', () async {
    await viewModel.addItem(item);
    await viewModel.deleteItem(item.id);

    expect(viewModel.items, isEmpty);
  });

  test('isLowStock compares qty against the given threshold', () async {
    await viewModel.addItem(item);

    expect(viewModel.items.single.isLowStock(5), isTrue);
    expect(viewModel.items.single.isLowStock(2), isFalse);
  });

  test('receiveLot adds the lot\'s pieces, including new items, and reloads', () async {
    await viewModel.addItem(item);
    const kids = Item(id: 'k', name: 'Kids Tee', category: 'Kids', unitPrice: 100, qtyOnHand: 0);

    await viewModel.receiveLot(
      StockLot(id: 'lot', at: DateTime(2026, 9, 1), supplier: 'Bale', itemsCost: 1000),
      const [
        LotLine(itemId: '1', itemName: 'Basic Tee', qty: 5, sellingPrice: 199),
        LotLine(itemId: 'k', itemName: 'Kids Tee', qty: 4, sellingPrice: 100),
      ],
      newItems: const [kids],
    );

    final byId = {for (final i in viewModel.items) i.id: i.qtyOnHand};
    expect(byId, {'1': 8, 'k': 4});
    expect(stock.lots.single.id, 'lot');
  });

  test('adjustStock writes off with a reason, marks found without one', () async {
    await viewModel.addItem(item);

    await viewModel.adjustStock('1', 2, reason: WriteOffReason.damaged);
    expect(viewModel.items.single.qtyOnHand, 1);

    await viewModel.adjustStock('1', 1);
    expect(viewModel.items.single.qtyOnHand, 2);
    expect(stock.movements.map((m) => m.type), [StockMovementType.writeOff, StockMovementType.found]);
  });

  test('a refused stock change surfaces to the caller', () async {
    await viewModel.addItem(item);
    stock.failWith = StockChangeException('Only 3 in stock');

    await expectLater(
      viewModel.adjustStock('1', 9, reason: WriteOffReason.lost),
      throwsA(isA<StockChangeException>()),
    );
    expect(viewModel.items.single.qtyOnHand, 3);
  });
}
