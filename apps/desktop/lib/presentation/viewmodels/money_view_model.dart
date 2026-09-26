import 'package:flutter/foundation.dart';

import 'package:shop_core/domain/entities/money_entry.dart';
import 'package:shop_core/domain/entities/stock.dart';
import 'package:shop_core/domain/repositories/money_repository.dart';
import 'package:shop_core/domain/repositories/stock_repository.dart';

/// The owners' money log, plus the stock history the profit figures need.
/// Lots and movements are written by InventoryViewModel, so the Money
/// screen reloads this when it opens rather than relying on a push.
class MoneyViewModel extends ChangeNotifier {
  MoneyViewModel(this._repository, this._stockRepository);
  final MoneyRepository _repository;
  final StockRepository _stockRepository;

  List<MoneyEntry> _entries = [];
  List<MoneyEntry> get entries => List.unmodifiable(_entries);

  List<StockLot> _lots = [];
  List<StockLot> get lots => List.unmodifiable(_lots);

  List<StockMovement> _movements = [];
  List<StockMovement> get movements => List.unmodifiable(_movements);

  DateTime? _booksStartedAt;

  /// Profit and payback count from here. Null only before the first load.
  DateTime? get booksStartedAt => _booksStartedAt;

  Future<void> load() async {
    final results = await Future.wait([
      _repository.getAll(),
      _stockRepository.getLots(),
      _stockRepository.getMovements(),
      _repository.booksStartedAt(),
    ]);
    _entries = results[0] as List<MoneyEntry>;
    _lots = results[1] as List<StockLot>;
    _movements = results[2] as List<StockMovement>;
    _booksStartedAt = results[3] as DateTime;
    notifyListeners();
  }

  Future<void> addEntry(MoneyEntry entry) async {
    await _repository.add(entry);
    await load();
  }

  Future<void> updateEntry(MoneyEntry entry) async {
    await _repository.update(entry);
    await load();
  }

  Future<void> deleteEntry(String id) async {
    await _repository.delete(id);
    await load();
  }
}
