import 'package:flutter/foundation.dart';
import 'package:shop_core/calculations/money_calculations.dart';
import 'package:shop_core/calculations/report_calculations.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/money_entry.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:shop_core/domain/entities/stock.dart';
import 'package:shop_core/domain/repositories/item_repository.dart';
import 'package:shop_core/domain/repositories/money_repository.dart';
import 'package:shop_core/domain/repositories/sale_repository.dart';
import 'package:shop_core/domain/repositories/stock_repository.dart';

/// The Money tab: payback, profit for a period, and sales against costs by
/// month. Every figure comes from shop_core's money calculations with the
/// same period rules as the shop computer's Money screen, so the two agree.
/// Read-only: never stamps the books' start date itself.
class MoneyViewModel extends ChangeNotifier {
  MoneyViewModel(
    this._money,
    this._sales,
    this._stock,
    this._items, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final MoneyRepository _money;
  final SaleRepository _sales;
  final StockRepository _stock;
  final ItemRepository _items;
  final DateTime Function() _clock;

  /// The periods the tab offers; allTime means since the books started.
  static const ranges = [ReportRange.last7Days, ReportRange.last30Days, ReportRange.allTime];

  List<MoneyEntry> _entries = const [];
  List<Sale> _salesList = const [];
  List<StockMovement> _movements = const [];
  List<StockLot> _lots = const [];
  List<Item> _itemList = const [];
  DateTime? _booksStartedAt;
  bool _loaded = false;
  ReportRange _range = ReportRange.last30Days;

  bool get loaded => _loaded;
  ReportRange get range => _range;

  /// Null until the shop computer's books have started and synced here.
  DateTime? get booksStartedAt => _booksStartedAt;

  DateTime get _booksStart => _booksStartedAt ?? _clock();

  /// Where the chosen period's profit counts from: its start, but never
  /// before the books did.
  DateTime get periodStart {
    final rangeStart = _range.startDate(_clock());
    return rangeStart == null || rangeStart.isBefore(_booksStart) ? _booksStart : rangeStart;
  }

  ProfitStatement get statement =>
      profitStatement(sales: _salesList, entries: _entries, movements: _movements, since: periodStart);

  /// Named apart from the shared payback() it calls.
  Payback get paybackStatus => payback(
        sales: _salesList,
        entries: _entries,
        movements: _movements,
        lots: _lots,
        booksStartedAt: _booksStart,
      );

  List<MonthlyProfit> get months => monthlyProfit(
        sales: _salesList,
        entries: _entries,
        movements: _movements,
        booksStartedAt: _booksStart,
        now: _clock(),
      );

  double get stockValue => stockValueAtCost(_itemList);

  /// The money log and stock purchases, newest first.
  List<MoneyLogEntry> get log => [
        for (final e in _entries) MoneyLogEntry.fromEntry(e),
        for (final lot in _lots) MoneyLogEntry.fromLot(lot),
      ]..sort((a, b) => b.at.compareTo(a.at));

  void selectRange(ReportRange range) {
    if (range == _range) return;
    _range = range;
    notifyListeners();
  }

  Future<void> load() async {
    final (entries, sales, movements, lots, items, booksStartedAt) = await (
      _money.getAll(),
      _sales.getAll(),
      _stock.getMovements(),
      _stock.getLots(),
      _items.getAll(),
      _money.booksStartedAtIfSet(),
    ).wait;
    _entries = entries;
    _salesList = sales;
    _movements = movements;
    _lots = lots;
    _itemList = items;
    _booksStartedAt = booksStartedAt;
    _loaded = true;
    notifyListeners();
  }
}

/// One line of the money log: an entry the owners recorded, or a stock lot.
class MoneyLogEntry {
  const MoneyLogEntry({
    required this.at,
    required this.title,
    required this.amount,
    required this.isMoneyIn,
    this.detail,
  });

  factory MoneyLogEntry.fromEntry(MoneyEntry e) => MoneyLogEntry(
        at: e.at,
        title: e.kind == MoneyEntryKind.expense ? (e.category?.label ?? 'Expense') : e.kind.label,
        amount: e.amount,
        isMoneyIn: e.kind == MoneyEntryKind.capitalIn,
        detail: [
          if (e.kind == MoneyEntryKind.expense) e.paidFrom.label,
          if (e.person != null) e.person!,
          if (e.note.isNotEmpty) e.note,
        ].join(' · '),
      );

  factory MoneyLogEntry.fromLot(StockLot lot) => MoneyLogEntry(
        at: lot.at,
        title: lot.supplier.isEmpty ? 'Stock bought' : 'Stock from ${lot.supplier}',
        amount: lot.totalCost,
        isMoneyIn: false,
        detail: [
          lot.paidFrom.label,
          if (lot.person != null) lot.person!,
          if (lot.note.isNotEmpty) lot.note,
        ].join(' · '),
      );

  final DateTime at;
  final String title;
  final double amount;

  /// Money the owners put into the shop; everything else is money going out.
  final bool isMoneyIn;
  final String? detail;
}
