import 'entities/stock.dart';

/// Splits a lot's [totalCost] across its lines in proportion to what each
/// line will sell for, and returns the resulting cost per piece for each
/// line (same order as [lines]).
///
/// Splitting by selling value rather than evenly per piece is what keeps a
/// mixed lot honest: an even split makes cheap pieces look like losses and
/// expensive ones look like stars, when the whole lot earns the same margin.
/// If nothing in the lot has a selling price yet, falls back to an even
/// split so the cost still lands somewhere.
List<double> allocateLotCost(double totalCost, List<LotLine> lines) {
  final pieces = lines.fold<int>(0, (sum, l) => sum + l.qty);
  if (pieces == 0) return [for (final _ in lines) 0];

  final sellingValue = lines.fold<double>(0, (sum, l) => sum + l.qty * l.sellingPrice);
  if (sellingValue <= 0) {
    return [for (final _ in lines) totalCost / pieces];
  }
  // Each piece costs the same fraction of its selling price.
  final costRatio = totalCost / sellingValue;
  return [for (final l in lines) l.sellingPrice * costRatio];
}

/// The new average cost per piece after [addedQty] pieces costing
/// [addedCost] each join [onHand] pieces costing [currentCost] each.
///
/// Unknown cost (null) counts as ₱0 — stock from before cost tracking
/// started is free in these books, since the money that bought it isn't
/// counted either. Stays null only when neither side has a cost.
double? blendUnitCost({
  required int onHand,
  required double? currentCost,
  required int addedQty,
  required double? addedCost,
}) {
  final existing = onHand < 0 ? 0 : onHand;
  if (currentCost == null && addedCost == null) return null;
  if (existing == 0) return addedCost ?? currentCost;
  if (addedQty <= 0) return currentCost;
  final total = existing * (currentCost ?? 0) + addedQty * (addedCost ?? 0);
  return total / (existing + addedQty);
}
