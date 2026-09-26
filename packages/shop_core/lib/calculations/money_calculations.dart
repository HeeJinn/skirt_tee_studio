import '../domain/entities/item.dart';
import '../domain/entities/money_entry.dart';
import '../domain/entities/sale.dart';
import '../domain/entities/stock.dart';

/// Profit for a period, laid out the way an income statement reads:
/// sales − cost of what sold = gross profit, − expenses − stock losses =
/// net profit. Buying stock appears nowhere here — it only becomes a cost
/// when the pieces sell or are written off.
class ProfitStatement {
  const ProfitStatement({
    required this.revenue,
    required this.costOfGoodsSold,
    required this.expensesByCategory,
    required this.stockLosses,
    required this.unknownCostRevenue,
  });

  final double revenue;
  final double costOfGoodsSold;

  /// Only categories with spending, largest first.
  final Map<ExpenseCategory, double> expensesByCategory;

  /// Write-offs net of pieces later found, at cost.
  final double stockLosses;

  /// Sales of pieces with no recorded cost (stock from before tracking
  /// started), counted at ₱0 cost — so this much of the revenue is also
  /// pure gross profit, flattering the margin until that stock sells out.
  final double unknownCostRevenue;

  double get grossProfit => revenue - costOfGoodsSold;
  double get grossMargin => revenue == 0 ? 0 : grossProfit / revenue;
  double get totalExpenses => expensesByCategory.values.fold(0, (sum, v) => sum + v);
  double get netProfit => grossProfit - totalExpenses - stockLosses;
}

/// [since] is an inclusive start, [before] an exclusive end; null leaves
/// that side open.
ProfitStatement profitStatement({
  required List<Sale> sales,
  required List<MoneyEntry> entries,
  required List<StockMovement> movements,
  DateTime? since,
  DateTime? before,
}) {
  bool inRange(DateTime at) => (since == null || !at.isBefore(since)) && (before == null || at.isBefore(before));

  var revenue = 0.0;
  var cogs = 0.0;
  var unknownCostRevenue = 0.0;
  for (final sale in sales.where((s) => inRange(s.dateTime))) {
    for (final line in sale.lineItems) {
      revenue += line.subtotal;
      cogs += line.costOfGoods;
      if (line.unitCost == null) unknownCostRevenue += line.subtotal;
    }
  }

  final expenses = <ExpenseCategory, double>{};
  for (final e in entries.where((e) => e.kind == MoneyEntryKind.expense && inRange(e.at))) {
    final category = e.category ?? ExpenseCategory.other;
    expenses.update(category, (v) => v + e.amount, ifAbsent: () => e.amount);
  }
  final ranked = expenses.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  var losses = 0.0;
  for (final m in movements.where((m) => inRange(m.at))) {
    if (m.type == StockMovementType.writeOff) losses += m.value;
    if (m.type == StockMovementType.found) losses -= m.value;
  }

  return ProfitStatement(
    revenue: revenue,
    costOfGoodsSold: cogs,
    expensesByCategory: Map.fromEntries(ranked),
    stockLosses: losses,
    unknownCostRevenue: unknownCostRevenue,
  );
}

/// Whether the owners have earned back what they put in. Always all-time —
/// an investment isn't recovered "this week".
class Payback {
  const Payback({
    required this.invested,
    required this.earned,
    required this.takenHome,
    required this.investedByPerson,
  });

  /// Money put in, plus every expense and lot the owners paid for from
  /// their own pockets.
  final double invested;

  /// All-time net profit.
  final double earned;
  final double takenHome;

  /// [invested] split by which owner put it in; entries with no person are
  /// under [bothOwners].
  final Map<String, double> investedByPerson;

  static const bothOwners = 'Both';

  /// Fraction of [invested] earned back (can pass 1, or go negative while
  /// the shop is losing money). Null until anything has been put in.
  double? get recoveredShare => invested <= 0 ? null : earned / invested;

  double get remainingToRecover => invested - earned > 0 ? invested - earned : 0;

  /// What's still in the shop, as cash or stock: everything put in and
  /// earned, minus what was taken home.
  double get stillInShop => invested + earned - takenHome;
}

/// [booksStartedAt] bounds what counts as earned: sales from before the
/// books started would otherwise count as profit against money put in
/// after it.
Payback payback({
  required List<Sale> sales,
  required List<MoneyEntry> entries,
  required List<StockMovement> movements,
  required List<StockLot> lots,
  DateTime? booksStartedAt,
}) {
  final byPerson = <String, double>{};
  void addIn(String? person, double amount) =>
      byPerson.update(person ?? Payback.bothOwners, (v) => v + amount, ifAbsent: () => amount);

  for (final e in entries.where((e) => e.isOwnersMoneyIn)) {
    addIn(e.person, e.amount);
  }
  for (final lot in lots.where((l) => l.paidFrom == PaidFrom.owners)) {
    addIn(lot.person, lot.totalCost);
  }

  return Payback(
    invested: byPerson.values.fold(0, (sum, v) => sum + v),
    earned: profitStatement(sales: sales, entries: entries, movements: movements, since: booksStartedAt).netProfit,
    takenHome: entries.where((e) => e.kind == MoneyEntryKind.ownerDraw).fold(0, (sum, e) => sum + e.amount),
    investedByPerson: byPerson,
  );
}

/// One month's sales against everything that month cost the shop.
class MonthlyProfit {
  const MonthlyProfit({required this.month, required this.sales, required this.costs});

  /// First day of the month.
  final DateTime month;
  final double sales;

  /// Cost of what sold + expenses + stock losses — everything that came
  /// off profit. Stock bought isn't in it; it's a cost only once it sells.
  final double costs;

  double get profit => sales - costs;
}

/// The last [maxMonths] calendar months up to [now], but none before the
/// books started — months before that have no costs recorded and would
/// show as pure profit.
List<MonthlyProfit> monthlyProfit({
  required List<Sale> sales,
  required List<MoneyEntry> entries,
  required List<StockMovement> movements,
  required DateTime booksStartedAt,
  required DateTime now,
  int maxMonths = 6,
}) {
  final firstAllowed = DateTime(now.year, now.month - (maxMonths - 1));
  final booksMonth = DateTime(booksStartedAt.year, booksStartedAt.month);
  var month = booksMonth.isAfter(firstAllowed) ? booksMonth : firstAllowed;
  final result = <MonthlyProfit>[];
  while (!month.isAfter(now)) {
    final next = DateTime(month.year, month.month + 1);
    final statement = profitStatement(
      sales: sales,
      entries: entries,
      movements: movements,
      since: month.isBefore(booksStartedAt) ? booksStartedAt : month,
      before: next,
    );
    result.add(MonthlyProfit(
      month: month,
      sales: statement.revenue,
      costs: statement.costOfGoodsSold + statement.totalExpenses + statement.stockLosses,
    ));
    month = next;
  }
  return result;
}

/// What the stock on the shelf cost — money sitting on the rack. Items with
/// no recorded cost count at ₱0.
double stockValueAtCost(List<Item> items) =>
    items.where((i) => i.qtyOnHand > 0).fold(0, (sum, i) => sum + i.qtyOnHand * (i.unitCost ?? 0));
