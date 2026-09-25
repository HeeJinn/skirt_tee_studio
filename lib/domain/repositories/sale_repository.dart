import '../entities/sale.dart';

abstract class SaleRepository {
  /// Records a completed sale and deducts stock for every line item.
  /// Must happen atomically — this is the fix for the store's core pain
  /// point (inventory drifting out of sync with sales).
  Future<void> recordSale(Sale sale);

  /// All recorded sales, newest first.
  Future<List<Sale>> getAll();

  /// Restores stock for the sale's line items and removes it — for
  /// correcting a cashier mistake at checkout.
  Future<void> voidSale(String id);
}
