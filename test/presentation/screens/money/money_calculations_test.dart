import 'package:flutter_test/flutter_test.dart';
import 'package:skirt_tee_studio/domain/entities/item.dart';
import 'package:skirt_tee_studio/domain/entities/money_entry.dart';
import 'package:skirt_tee_studio/domain/entities/sale.dart';
import 'package:skirt_tee_studio/domain/entities/stock.dart';
import 'package:skirt_tee_studio/presentation/screens/money/money_calculations.dart';

void main() {
  final sep1 = DateTime(2026, 9, 1);
  final sep20 = DateTime(2026, 9, 20);

  Sale sale(DateTime at, List<SaleLineItem> lines) => Sale(id: 'sale-$at', dateTime: at, lineItems: lines);

  MoneyEntry entry(
    MoneyEntryKind kind,
    double amount, {
    DateTime? at,
    ExpenseCategory? category,
    PaidFrom paidFrom = PaidFrom.shop,
    String? person,
  }) =>
      MoneyEntry(
        id: '$kind-$amount-$at',
        at: at ?? sep1,
        kind: kind,
        amount: amount,
        category: category,
        paidFrom: paidFrom,
        person: person,
      );

  StockMovement movement(StockMovementType type, int qty, double cost, {DateTime? at}) => StockMovement(
        at: at ?? sep1,
        itemId: 'i',
        itemName: 'Tee',
        type: type,
        qty: qty,
        unitCost: cost,
      );

  group('profitStatement', () {
    test('sales − cost of what sold − expenses − losses = net profit', () {
      final statement = profitStatement(
        sales: [
          sale(sep1, const [
            SaleLineItem(itemId: 'tee', itemName: 'Tee', unitPrice: 150, qty: 40, unitCost: 120),
            SaleLineItem(itemId: 'skirt', itemName: 'Skirt', unitPrice: 250, qty: 4, unitCost: 200),
          ]),
        ],
        entries: [
          entry(MoneyEntryKind.expense, 500, category: ExpenseCategory.packaging),
          entry(MoneyEntryKind.expense, 3000, category: ExpenseCategory.rent),
          entry(MoneyEntryKind.expense, 200, category: ExpenseCategory.packaging),
          // Neither of these is a cost of running the shop.
          entry(MoneyEntryKind.capitalIn, 50000),
          entry(MoneyEntryKind.ownerDraw, 2000),
        ],
        movements: [
          movement(StockMovementType.writeOff, 2, 120),
          movement(StockMovementType.found, 1, 120),
          // Buying stock is not a cost until it sells.
          movement(StockMovementType.received, 30, 120),
        ],
      );

      expect(statement.revenue, 7000);
      expect(statement.costOfGoodsSold, 5600);
      expect(statement.grossProfit, 1400);
      expect(statement.grossMargin, closeTo(0.2, 1e-9));
      expect(statement.expensesByCategory.keys, [ExpenseCategory.rent, ExpenseCategory.packaging]);
      expect(statement.expensesByCategory[ExpenseCategory.packaging], 700);
      expect(statement.totalExpenses, 3700);
      expect(statement.stockLosses, 120);
      expect(statement.netProfit, 1400 - 3700 - 120);
    });

    test('pre-tracking stock counts at ₱0 cost and is reported separately', () {
      final statement = profitStatement(
        sales: [
          sale(sep1, const [
            SaleLineItem(itemId: 'old', itemName: 'Old Tee', unitPrice: 100, qty: 3),
            SaleLineItem(itemId: 'new', itemName: 'New Tee', unitPrice: 100, qty: 1, unitCost: 60),
          ]),
        ],
        entries: const [],
        movements: const [],
      );

      expect(statement.costOfGoodsSold, 60);
      expect(statement.unknownCostRevenue, 300);
    });

    test('since scopes sales, expenses, and losses alike', () {
      final statement = profitStatement(
        sales: [
          sale(sep1, const [SaleLineItem(itemId: 'a', itemName: 'A', unitPrice: 100, qty: 1, unitCost: 50)]),
          sale(sep20, const [SaleLineItem(itemId: 'a', itemName: 'A', unitPrice: 100, qty: 2, unitCost: 50)]),
        ],
        entries: [
          entry(MoneyEntryKind.expense, 1000, at: sep1, category: ExpenseCategory.rent),
          entry(MoneyEntryKind.expense, 40, at: sep20, category: ExpenseCategory.fees),
        ],
        movements: [
          movement(StockMovementType.writeOff, 1, 50, at: sep1),
          movement(StockMovementType.writeOff, 1, 30, at: sep20),
        ],
        since: DateTime(2026, 9, 20),
      );

      expect(statement.revenue, 200);
      expect(statement.totalExpenses, 40);
      expect(statement.stockLosses, 30);
      expect(statement.netProfit, 200 - 100 - 40 - 30);
    });

    test('an expense with no category lands in Other', () {
      final statement = profitStatement(
        sales: const [],
        entries: [entry(MoneyEntryKind.expense, 99)],
        movements: const [],
      );
      expect(statement.expensesByCategory, {ExpenseCategory.other: 99});
    });

    test('margin is zero, not NaN, with no sales', () {
      expect(profitStatement(sales: const [], entries: const [], movements: const []).grossMargin, 0);
    });
  });

  group('payback', () {
    test('invested counts money put in plus anything the owners paid for themselves', () {
      final result = payback(
        sales: const [],
        entries: [
          entry(MoneyEntryKind.capitalIn, 50000, person: 'Ana'),
          entry(MoneyEntryKind.capitalIn, 30000, person: 'Ben'),
          entry(MoneyEntryKind.expense, 8000, category: ExpenseCategory.rent, paidFrom: PaidFrom.owners, person: 'Ben'),
          // Paid from shop money: a cost, but not new investment.
          entry(MoneyEntryKind.expense, 500, category: ExpenseCategory.fees),
        ],
        movements: const [],
        lots: [
          StockLot(id: 'l1', at: sep1, supplier: 'Bale', itemsCost: 8000, fees: 400, paidFrom: PaidFrom.owners),
          StockLot(id: 'l2', at: sep1, supplier: 'Bale', itemsCost: 5000),
        ],
      );

      expect(result.invested, 50000 + 30000 + 8000 + 8400);
      expect(result.investedByPerson, {'Ana': 50000, 'Ben': 38000, Payback.bothOwners: 8400});
    });

    test('earned is all-time net profit; recovered share and what\'s left follow from it', () {
      final result = payback(
        sales: [
          sale(sep1, const [SaleLineItem(itemId: 'a', itemName: 'A', unitPrice: 150, qty: 100, unitCost: 100)]),
        ],
        entries: [
          entry(MoneyEntryKind.capitalIn, 20000),
          entry(MoneyEntryKind.expense, 1000, category: ExpenseCategory.rent),
          entry(MoneyEntryKind.ownerDraw, 3000),
        ],
        movements: const [],
        lots: const [],
      );

      expect(result.earned, 4000);
      expect(result.takenHome, 3000);
      expect(result.recoveredShare, closeTo(0.2, 1e-9));
      expect(result.remainingToRecover, 16000);
      expect(result.stillInShop, 20000 + 4000 - 3000);
    });

    test('taking money home doesn\'t change what the shop earned', () {
      final before = payback(
        sales: const [],
        entries: [entry(MoneyEntryKind.capitalIn, 1000)],
        movements: const [],
        lots: const [],
      );
      final after = payback(
        sales: const [],
        entries: [entry(MoneyEntryKind.capitalIn, 1000), entry(MoneyEntryKind.ownerDraw, 700)],
        movements: const [],
        lots: const [],
      );
      expect(after.earned, before.earned);
      expect(after.stillInShop, before.stillInShop - 700);
    });

    test('nothing to recover until something has been put in', () {
      final result = payback(sales: const [], entries: const [], movements: const [], lots: const []);
      expect(result.recoveredShare, isNull);
      expect(result.remainingToRecover, 0);
    });

    test('past the investment, nothing is left to recover', () {
      final result = payback(
        sales: [
          sale(sep1, const [SaleLineItem(itemId: 'a', itemName: 'A', unitPrice: 200, qty: 10, unitCost: 0)]),
        ],
        entries: [entry(MoneyEntryKind.capitalIn, 1000)],
        movements: const [],
        lots: const [],
      );
      expect(result.recoveredShare, 2);
      expect(result.remainingToRecover, 0);
    });
  });

  test('profitStatement before is an exclusive end', () {
    final statement = profitStatement(
      sales: [
        sale(DateTime(2026, 9, 30, 23), const [SaleLineItem(itemId: 'a', itemName: 'A', unitPrice: 100, qty: 1)]),
        sale(DateTime(2026, 10, 1), const [SaleLineItem(itemId: 'a', itemName: 'A', unitPrice: 100, qty: 5)]),
      ],
      entries: const [],
      movements: const [],
      before: DateTime(2026, 10, 1),
    );
    expect(statement.revenue, 100);
  });

  test('payback ignores sales from before the books started', () {
    final result = payback(
      sales: [
        // Years of trading before tracking — must not count as earned back.
        sale(DateTime(2025, 3, 1), const [SaleLineItem(itemId: 'a', itemName: 'A', unitPrice: 500, qty: 100)]),
        sale(sep20, const [SaleLineItem(itemId: 'a', itemName: 'A', unitPrice: 500, qty: 2, unitCost: 300)]),
      ],
      entries: [entry(MoneyEntryKind.capitalIn, 10000)],
      movements: const [],
      lots: const [],
      booksStartedAt: sep1,
    );
    expect(result.earned, 400);
  });

  group('monthlyProfit', () {
    final now = DateTime(2026, 12, 15);

    test('one bar per month from the books\' start, costs = what sold + expenses + losses', () {
      final months = monthlyProfit(
        sales: [
          sale(DateTime(2026, 10, 5), const [SaleLineItem(itemId: 'a', itemName: 'A', unitPrice: 200, qty: 10, unitCost: 120)]),
          sale(DateTime(2026, 12, 1), const [SaleLineItem(itemId: 'a', itemName: 'A', unitPrice: 200, qty: 1, unitCost: 120)]),
        ],
        entries: [entry(MoneyEntryKind.expense, 500, at: DateTime(2026, 10, 20), category: ExpenseCategory.rent)],
        movements: [movement(StockMovementType.writeOff, 1, 120, at: DateTime(2026, 11, 2))],
        booksStartedAt: DateTime(2026, 10, 3),
        now: now,
      );

      expect(months.map((m) => m.month), [DateTime(2026, 10), DateTime(2026, 11), DateTime(2026, 12)]);
      expect(months[0].sales, 2000);
      expect(months[0].costs, 1200 + 500);
      expect(months[0].profit, 300);
      expect(months[1].sales, 0);
      expect(months[1].costs, 120);
      expect(months[2].sales, 200);
    });

    test('the books\' first month leaves out sales from before they started', () {
      final months = monthlyProfit(
        sales: [
          sale(DateTime(2026, 12, 2), const [SaleLineItem(itemId: 'a', itemName: 'A', unitPrice: 999, qty: 1)]),
          sale(DateTime(2026, 12, 10), const [SaleLineItem(itemId: 'a', itemName: 'A', unitPrice: 100, qty: 1)]),
        ],
        entries: const [],
        movements: const [],
        booksStartedAt: DateTime(2026, 12, 5),
        now: now,
      );

      expect(months.single.sales, 100);
    });

    test('caps at the most recent months', () {
      final months = monthlyProfit(
        sales: const [],
        entries: const [],
        movements: const [],
        booksStartedAt: DateTime(2025, 1, 1),
        now: now,
        maxMonths: 6,
      );

      expect(months, hasLength(6));
      expect(months.first.month, DateTime(2026, 7));
      expect(months.last.month, DateTime(2026, 12));
    });
  });

  test('stockValueAtCost values the shelf at cost, unknown cost as ₱0', () {
    expect(
      stockValueAtCost(const [
        Item(id: 'a', name: 'A', category: 'T-Shirt', unitPrice: 150, qtyOnHand: 10, unitCost: 90),
        Item(id: 'b', name: 'B', category: 'Skirt', unitPrice: 250, qtyOnHand: 4),
        Item(id: 'c', name: 'C', category: 'Kids', unitPrice: 100, qtyOnHand: -1, unitCost: 80),
      ]),
      900,
    );
  });
}
