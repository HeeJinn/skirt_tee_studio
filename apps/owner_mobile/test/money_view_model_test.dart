import 'package:flutter_test/flutter_test.dart';
import 'package:owner_mobile/core/period.dart';
import 'package:owner_mobile/presentation/viewmodels/money_view_model.dart';
import 'package:shop_core/domain/entities/money_entry.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:shop_core/testing/fake_item_repository.dart';
import 'package:shop_core/testing/fake_money_repository.dart';
import 'package:shop_core/testing/fake_sale_repository.dart';
import 'package:shop_core/testing/fake_stock_repository.dart';

void main() {
  Sale sale(String id, DateTime at, double price) => Sale(
        id: id,
        dateTime: at,
        lineItems: [SaleLineItem(itemId: 'tee', itemName: 'Tee', unitPrice: price, qty: 1, unitCost: 100)],
      );

  /// Books started mid-August; it's now October.
  Future<MoneyViewModel> shop() async {
    final sales = FakeSaleRepository();
    await sales.recordSale(sale('aug', DateTime(2026, 8, 20), 300));
    await sales.recordSale(sale('sep', DateTime(2026, 9, 30, 23), 500));
    await sales.recordSale(sale('oct', DateTime(2026, 10, 1), 700));
    final money = FakeMoneyRepository(booksStartedAt: DateTime(2026, 8, 15));
    await money.add(MoneyEntry(
      id: 'rent',
      at: DateTime(2026, 9, 5),
      kind: MoneyEntryKind.expense,
      amount: 150,
      category: ExpenseCategory.rent,
    ));
    final items = FakeItemRepository();
    final vm = MoneyViewModel(money, sales, FakeStockRepository(items), items, clock: () => DateTime(2026, 10, 10));
    await vm.load();
    return vm;
  }

  test('opens on this month', () async {
    final vm = await shop();
    expect(vm.period, Period.month(DateTime(2026, 10)));
    expect(vm.statement.revenue, 700);
  });

  test("a past month counts that month's sales and costs, and no others", () async {
    final vm = await shop()
      ..selectPeriod(Period.month(DateTime(2026, 9)));
    expect(vm.statement.revenue, 500);
    expect(vm.statement.netProfit, 500 - 100 - 150);
    expect(vm.periodStart, DateTime(2026, 9));
  });

  test('the month the books started counts from that day', () async {
    final vm = await shop()
      ..selectPeriod(Period.month(DateTime(2026, 8)));
    expect(vm.periodStart, DateTime(2026, 8, 15));
    expect(vm.statement.revenue, 300);
  });

  test('since start counts everything from the books on', () async {
    final vm = await shop()
      ..selectPeriod(const Period.all());
    expect(vm.periodStart, DateTime(2026, 8, 15));
    expect(vm.statement.revenue, 1500);
  });
}
