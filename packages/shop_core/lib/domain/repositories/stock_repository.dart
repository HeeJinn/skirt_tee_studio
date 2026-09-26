import '../entities/item.dart';
import '../entities/stock.dart';

/// Thrown when a stock change can't apply as asked — the item is gone, or
/// more pieces are being removed than are on hand. Callers show [message].
class StockChangeException implements Exception {
  StockChangeException(this.message);
  final String message;
}

/// Every change to stock other than a sale. Each one is atomic and keeps
/// the item's quantity and average cost in step with the movement it
/// records, so stock value on the books always matches the shelf.
abstract class StockRepository {
  /// Records a purchase: splits its cost across [lines] by selling value,
  /// adds the pieces to stock, and re-averages each item's cost.
  /// [newItems] are created first (their own quantity is ignored), so a lot
  /// can introduce items that weren't in inventory yet.
  Future<void> receiveLot(StockLot lot, List<LotLine> lines, {List<Item> newItems = const []});

  /// Removes [qty] pieces as a loss, valued at the item's current cost.
  Future<void> writeOff(String itemId, int qty, WriteOffReason reason, {String note = '', DateTime? at});

  /// Adds back [qty] pieces a count said were gone, undoing that loss at
  /// the item's current cost.
  Future<void> markFound(String itemId, int qty, {String note = '', DateTime? at});

  /// Deletes an item, writing off any pieces still on hand first so their
  /// cost doesn't silently vanish from the books.
  Future<void> removeItem(String itemId);

  /// All purchases, newest first.
  Future<List<StockLot>> getLots();

  /// All non-sale stock movements, newest first.
  Future<List<StockMovement>> getMovements();
}
