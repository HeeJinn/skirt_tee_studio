import 'package:skirt_tee_studio/domain/entities/item.dart';
import 'package:skirt_tee_studio/domain/entities/stock.dart';
import 'package:skirt_tee_studio/domain/repositories/stock_repository.dart';

import 'fake_item_repository.dart';

/// Records every call, and keeps [items] quantities in step so a
/// ViewModel reloading after a stock change sees the result. Costing itself
/// is covered against the real repository.
class FakeStockRepository implements StockRepository {
  FakeStockRepository([FakeItemRepository? items]) : items = items ?? FakeItemRepository();

  final FakeItemRepository items;
  final List<StockLot> lots = [];
  final List<StockMovement> movements = [];

  /// Set to make the next change fail the way the real one does.
  StockChangeException? failWith;

  Future<void> _changeQty(String itemId, int delta) async {
    final item = (await items.getAll()).firstWhere((i) => i.id == itemId);
    await items.update(item.copyWith(qtyOnHand: item.qtyOnHand + delta));
  }

  void _maybeFail() {
    final failure = failWith;
    failWith = null;
    if (failure != null) throw failure;
  }

  StockMovement _movement(String itemId, StockMovementType type, int qty, {WriteOffReason? reason}) =>
      StockMovement(at: DateTime.now(), itemId: itemId, itemName: itemId, type: type, qty: qty, unitCost: 0, reason: reason);

  @override
  Future<void> receiveLot(StockLot lot, List<LotLine> lines, {List<Item> newItems = const []}) async {
    _maybeFail();
    for (final item in newItems) {
      await items.add(item.copyWith(qtyOnHand: 0));
    }
    lots.add(lot);
    for (final line in lines) {
      await _changeQty(line.itemId, line.qty);
      movements.add(_movement(line.itemId, StockMovementType.received, line.qty));
    }
  }

  @override
  Future<void> writeOff(String itemId, int qty, WriteOffReason reason, {String note = '', DateTime? at}) async {
    _maybeFail();
    await _changeQty(itemId, -qty);
    movements.add(_movement(itemId, StockMovementType.writeOff, qty, reason: reason));
  }

  @override
  Future<void> markFound(String itemId, int qty, {String note = '', DateTime? at}) async {
    _maybeFail();
    await _changeQty(itemId, qty);
    movements.add(_movement(itemId, StockMovementType.found, qty));
  }

  @override
  Future<void> removeItem(String itemId) async => items.delete(itemId);

  @override
  Future<List<StockLot>> getLots() async => List.unmodifiable(lots);

  @override
  Future<List<StockMovement>> getMovements() async => List.unmodifiable(movements);
}
