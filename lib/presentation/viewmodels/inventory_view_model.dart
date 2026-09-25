import 'package:flutter/foundation.dart';

import '../../domain/entities/item.dart';
import '../../domain/entities/stock.dart';
import '../../domain/repositories/item_repository.dart';
import '../../domain/repositories/stock_repository.dart';

class InventoryViewModel extends ChangeNotifier {
  InventoryViewModel(this._repository, this._stockRepository);
  final ItemRepository _repository;
  final StockRepository _stockRepository;

  List<Item> _items = [];
  List<Item> get items => List.unmodifiable(_items);

  Future<void> load() async {
    _items = await _repository.getAll();
    notifyListeners();
  }

  Future<void> addItem(Item item) async {
    await _repository.add(item);
    await load();
  }

  /// For name/price/photo/cost edits. Stock quantity changes go through
  /// [receiveLot] and [adjustStock] instead, so each one is costed.
  Future<void> updateItem(Item item) async {
    await _repository.update(item);
    await load();
  }

  /// Any stock still on hand is written off as a loss before the item goes.
  Future<void> deleteItem(String id) async {
    await _stockRepository.removeItem(id);
    await load();
  }

  /// Throws [StockChangeException] if the lot can't be applied.
  Future<void> receiveLot(StockLot lot, List<LotLine> lines, {List<Item> newItems = const []}) async {
    await _stockRepository.receiveLot(lot, lines, newItems: newItems);
    await load();
  }

  /// Removes pieces as a loss ([reason] given) or adds back pieces that
  /// turned up ([reason] null). Throws [StockChangeException] if more are
  /// removed than are on hand.
  Future<void> adjustStock(String itemId, int qty, {WriteOffReason? reason, String note = ''}) async {
    if (reason == null) {
      await _stockRepository.markFound(itemId, qty, note: note);
    } else {
      await _stockRepository.writeOff(itemId, qty, reason, note: note);
    }
    await load();
  }
}
