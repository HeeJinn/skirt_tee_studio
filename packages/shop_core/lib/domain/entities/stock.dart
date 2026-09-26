import 'money_entry.dart';

/// One purchase of stock — usually a mixed bulk lot (a bale or bundle
/// sorted into several items), sometimes a simple restock of one item.
class StockLot {
  const StockLot({
    required this.id,
    required this.at,
    required this.supplier,
    required this.itemsCost,
    this.fees = 0,
    this.paidFrom = PaidFrom.shop,
    this.person,
    this.note = '',
  });

  final String id;
  final DateTime at;
  final String supplier;

  /// The price paid for the goods themselves.
  final double itemsCost;

  /// Shipping, delivery, and other costs of getting the lot onto the rack.
  /// Part of what the pieces cost, so it's split across them too.
  final double fees;
  final PaidFrom paidFrom;

  /// Which owner paid, when [paidFrom] is the owners. Null means both.
  final String? person;
  final String note;

  double get totalCost => itemsCost + fees;
}

/// One item's share of a lot: how many sellable pieces it yielded and the
/// price they'll sell at (which is what the lot's cost is split by).
/// Rejects that won't be sold are simply left out, so their cost is carried
/// by the good pieces.
class LotLine {
  const LotLine({
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.sellingPrice,
  });

  final String itemId;
  final String itemName;
  final int qty;
  final double sellingPrice;
}

enum StockMovementType {
  /// Pieces coming in from a lot.
  received,

  /// Pieces leaving without a sale — the shop's losses.
  writeOff,

  /// Pieces turning up that the count said were gone; undoes a loss.
  found,
}

enum WriteOffReason {
  damaged('Damaged'),
  lost('Lost or stolen'),
  givenAway('Given away'),
  countShort('Count came up short'),
  removed('Item removed from inventory'),
  other('Other');

  const WriteOffReason(this.label);
  final String label;
}

/// A change to stock other than a sale, valued at cost. Sales carry their
/// own cost on the line item, so they aren't duplicated here.
class StockMovement {
  const StockMovement({
    required this.at,
    required this.itemId,
    required this.itemName,
    required this.type,
    required this.qty,
    required this.unitCost,
    this.reason,
    this.lotId,
    this.note = '',
  });

  final DateTime at;

  /// Snapshot, not a foreign key — the history must survive the item being
  /// deleted.
  final String itemId;
  final String itemName;
  final StockMovementType type;

  /// Always positive; [type] says the direction.
  final int qty;

  /// Cost per piece at the time, ₱0 for stock that never had a cost.
  final double unitCost;

  /// Set for write-offs only.
  final WriteOffReason? reason;

  /// Set for received pieces only.
  final String? lotId;
  final String note;

  double get value => qty * unitCost;
}
