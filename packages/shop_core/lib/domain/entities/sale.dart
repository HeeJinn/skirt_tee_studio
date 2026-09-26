/// One line in a transaction (one item + qty at the price it sold for).
/// Price/name are captured at sale time so editing an Item later doesn't
/// rewrite history.
class SaleLineItem {
  const SaleLineItem({
    required this.itemId,
    required this.itemName,
    required this.unitPrice,
    required this.qty,
    this.unitCost,
  });

  final String itemId;
  final String itemName;
  final double unitPrice;
  final int qty;

  /// The item's average cost at the moment of sale, captured by the data
  /// layer when the sale is recorded (callers never set it). Null for sales
  /// from before cost tracking, and for stock that never had a cost.
  final double? unitCost;

  double get subtotal => unitPrice * qty;

  /// Cost of goods sold for this line; unknown cost counts as ₱0, matching
  /// how the books treat stock from before tracking started.
  double get costOfGoods => (unitCost ?? 0) * qty;
}

enum PaymentMethod {
  cash('Cash'),
  gcash('GCash'),
  maya('Maya'),
  card('Card'),

  /// Legacy: sales recorded before e-wallets were split out. Still readable,
  /// never offered at checkout.
  cashless('Cashless');

  const PaymentMethod(this.label);
  final String label;

  static const selectable = [cash, gcash, maya, card];
}

/// One completed transaction. Created when the cashier completes a sale on
/// the POS screen; this is also what deducts stock from Inventory.
class Sale {
  const Sale({
    required this.id,
    required this.dateTime,
    required this.lineItems,
    this.paymentMethod,
    this.amountTendered,
  });

  final String id;
  final DateTime dateTime;
  final List<SaleLineItem> lineItems;

  /// Null only for sales recorded before payment methods were tracked —
  /// deliberately not back-filled with a guess.
  final PaymentMethod? paymentMethod;

  /// Cash handed over by the customer. Null for non-cash sales and for cash
  /// sales recorded before this was tracked.
  final double? amountTendered;

  /// Change handed back, to the centavo. Null whenever [amountTendered] is.
  double? get changeGiven =>
      amountTendered == null ? null : ((amountTendered! * 100).round() - (totalAmount * 100).round()) / 100;

  double get totalAmount => lineItems.fold(0, (sum, line) => sum + line.subtotal);
  int get totalItemsSold => lineItems.fold(0, (sum, line) => sum + line.qty);
}
