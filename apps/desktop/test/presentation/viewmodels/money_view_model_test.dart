import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/domain/entities/money_entry.dart';
import 'package:shop_core/domain/entities/stock.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/money_view_model.dart';

import '../../fakes/fake_money_repository.dart';
import '../../fakes/fake_stock_repository.dart';

void main() {
  late FakeStockRepository stock;
  late MoneyViewModel viewModel;

  setUp(() {
    stock = FakeStockRepository();
    viewModel = MoneyViewModel(FakeMoneyRepository(), stock);
  });

  MoneyEntry entry(String id, double amount, {DateTime? at}) =>
      MoneyEntry(id: id, at: at ?? DateTime(2026, 9, 1), kind: MoneyEntryKind.capitalIn, amount: amount);

  test('add, update, and delete each reload the log', () async {
    await viewModel.addEntry(entry('a', 1000));
    await viewModel.addEntry(entry('b', 500, at: DateTime(2026, 9, 5)));
    expect(viewModel.entries.map((e) => e.id), ['b', 'a']);

    await viewModel.updateEntry(entry('a', 1200));
    expect(viewModel.entries.last.amount, 1200);

    await viewModel.deleteEntry('b');
    expect(viewModel.entries.map((e) => e.id), ['a']);
  });

  test('load also picks up lots and movements recorded from Inventory', () async {
    stock.lots.add(StockLot(id: 'lot', at: DateTime(2026, 9, 1), supplier: 'Bale', itemsCost: 800));
    stock.movements.add(StockMovement(
      at: DateTime(2026, 9, 2),
      itemId: 'i',
      itemName: 'Tee',
      type: StockMovementType.writeOff,
      qty: 1,
      unitCost: 80,
    ));

    await viewModel.load();

    expect(viewModel.lots.single.id, 'lot');
    expect(viewModel.movements.single.value, 80);
  });
}
