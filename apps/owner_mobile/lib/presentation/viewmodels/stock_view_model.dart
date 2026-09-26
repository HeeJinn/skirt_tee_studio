import 'package:flutter/foundation.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:shop_core/domain/entities/stock.dart';
import 'package:shop_core/domain/repositories/item_repository.dart';
import 'package:shop_core/domain/repositories/sale_repository.dart';
import 'package:shop_core/domain/repositories/settings_repository.dart';
import 'package:shop_core/domain/repositories/stock_repository.dart';

import '../screens/stock/item_history.dart';

enum StockFilter { all, low, soldOut }

/// The Stock tab: every item, searchable and filtered by how much is left,
/// plus each item's history. Read-only.
class StockViewModel extends ChangeNotifier {
  StockViewModel(
    this._items,
    this._stock,
    this._sales,
    this._settings, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ItemRepository _items;
  final StockRepository _stock;
  final SaleRepository _sales;
  final SettingsRepository _settings;
  final DateTime Function() _clock;

  List<Item> _all = const [];
  List<StockMovement> _movements = const [];
  List<StockLot> _lots = const [];
  List<Sale> _salesList = const [];
  int _threshold = SettingsRepository.defaultLowStockThreshold;
  bool _loaded = false;
  StockFilter _filter = StockFilter.all;
  String _query = '';

  bool get loaded => _loaded;
  StockFilter get filter => _filter;
  String get query => _query;
  int get lowStockThreshold => _threshold;

  bool isSoldOut(Item item) => item.qtyOnHand <= 0;

  /// Low but not sold out — sold-out items are their own group.
  bool isLow(Item item) => item.qtyOnHand > 0 && item.isLowStock(_threshold);

  int count(StockFilter filter) => _all.where((i) => _matchesFilter(i, filter)).length;

  /// The filtered, searched items, by name.
  List<Item> get items {
    final q = _query.trim().toLowerCase();
    return _all
        .where((i) => _matchesFilter(i, _filter))
        .where((i) => q.isEmpty || i.name.toLowerCase().contains(q) || i.category.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  int get totalPieces => _all.fold(0, (sum, i) => sum + (i.qtyOnHand > 0 ? i.qtyOnHand : 0));

  /// Null once the item is gone, e.g. deleted on the shop computer.
  Item? byId(String id) {
    for (final item in _all) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<ItemHistoryEntry> historyOf(String itemId) =>
      itemHistory(itemId: itemId, movements: _movements, lots: _lots, sales: _salesList);

  int soldInLast30Days(String itemId) {
    final now = _clock();
    final since = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
    return piecesSoldSince(itemId, _salesList, since);
  }

  void selectFilter(StockFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    notifyListeners();
  }

  void search(String query) {
    if (query == _query) return;
    _query = query;
    notifyListeners();
  }

  Future<void> load() async {
    final (items, movements, lots, sales, threshold) = await (
      _items.getAll(),
      _stock.getMovements(),
      _stock.getLots(),
      _sales.getAll(),
      _settings.getLowStockThreshold(),
    ).wait;
    _all = items;
    _movements = movements;
    _lots = lots;
    _salesList = sales;
    _threshold = threshold;
    _loaded = true;
    notifyListeners();
  }

  bool _matchesFilter(Item item, StockFilter filter) => switch (filter) {
        StockFilter.all => true,
        StockFilter.low => isLow(item),
        StockFilter.soldOut => isSoldOut(item),
      };
}
