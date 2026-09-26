import 'package:shop_core/domain/entities/sale.dart';
import 'package:shop_core/domain/entities/stock.dart';

/// One change to an item's stock, from any source: received in a lot,
/// written off, found, or sold.
class ItemHistoryEntry {
  const ItemHistoryEntry({required this.at, required this.title, required this.change, this.detail});

  final DateTime at;

  /// "Received from Divisoria bale", "Sold", "Damaged".
  final String title;

  /// Pieces in (positive) or out (negative).
  final int change;

  /// A note, or the cost the pieces came in at.
  final String? detail;
}

/// The item's stock history, newest first. Sales aren't stock movements
/// (each sale carries its own cost), so they're merged in here.
List<ItemHistoryEntry> itemHistory({
  required String itemId,
  required List<StockMovement> movements,
  required List<StockLot> lots,
  required List<Sale> sales,
}) {
  final supplierByLot = {for (final lot in lots) lot.id: lot.supplier};
  final entries = <ItemHistoryEntry>[
    for (final m in movements)
      if (m.itemId == itemId)
        switch (m.type) {
          StockMovementType.received => ItemHistoryEntry(
              at: m.at,
              title: switch (supplierByLot[m.lotId]) {
                final supplier? when supplier.isNotEmpty => 'Received from $supplier',
                _ => 'Received',
              },
              change: m.qty,
              detail: m.note.isEmpty ? null : m.note,
            ),
          StockMovementType.writeOff => ItemHistoryEntry(
              at: m.at,
              title: m.reason?.label ?? 'Written off',
              change: -m.qty,
              detail: m.note.isEmpty ? null : m.note,
            ),
          StockMovementType.found => ItemHistoryEntry(
              at: m.at,
              title: 'Found',
              change: m.qty,
              detail: m.note.isEmpty ? null : m.note,
            ),
        },
    for (final sale in sales)
      for (final line in sale.lineItems)
        if (line.itemId == itemId) ItemHistoryEntry(at: sale.dateTime, title: 'Sold', change: -line.qty),
  ]..sort((a, b) => b.at.compareTo(a.at));
  return entries;
}

/// Pieces of the item sold from [since] on.
int piecesSoldSince(String itemId, List<Sale> sales, DateTime since) => sales
    .where((s) => !s.dateTime.isBefore(since))
    .expand((s) => s.lineItems)
    .where((l) => l.itemId == itemId)
    .fold(0, (sum, l) => sum + l.qty);
