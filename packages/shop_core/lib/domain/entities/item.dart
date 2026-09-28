/// A single product in inventory (e.g. "TShirt", "Skirt/Short").
/// Pure business object — no persistence concerns here; see
/// data/models/item_model.dart for the SQLite mapping.
class Item {
  const Item({
    required this.id,
    required this.name,
    required this.category,
    required this.unitPrice,
    required this.qtyOnHand,
    this.onSale = false,
    this.salePercent,
    this.salePrice,
    this.imagePath,
    this.unitCost,
  });

  final String id;
  final String name;
  final String category; // e.g. "T-Shirt", "Skirt", "Kids"

  /// The regular price. What it sells for right now is [sellingPrice].
  final double unitPrice;
  final int qtyOnHand;

  /// Marked down. The discount is [salePercent] or [salePrice], whichever
  /// the owners set. Items tagged "Bargain" before sales had a discount have
  /// neither, and sell at [unitPrice] with only the tag.
  ///
  /// Stored in the isBargain / is_bargain column, its name from then.
  final bool onSale;

  /// Percent off [unitPrice] while [onSale], e.g. 20 for 20% off.
  final double? salePercent;

  /// A set sale price while [onSale], instead of a percent.
  final double? salePrice;

  /// Local filesystem path to a copy this app made under its own storage
  /// (see ItemImageStorage) — never a path chosen by the user directly, so
  /// it stays valid even if they move or delete the original file. Null
  /// means no photo.
  final String? imagePath;

  /// What one piece cost the shop, averaged across every lot it came from
  /// (see blendUnitCost). Null means never recorded — stock on hand from
  /// before cost tracking started, which the books count at ₱0.
  final double? unitCost;

  /// What a piece sells for now — the sale price while on sale. A percent
  /// off rounds to the whole peso (20% off ₱249 is ₱199), the way prices
  /// are written on the rack.
  double get sellingPrice {
    if (!onSale) return unitPrice;
    if (salePrice != null) return salePrice!;
    if (salePercent != null) return (unitPrice * (100 - salePercent!) / 100).roundToDouble();
    return unitPrice;
  }

  /// Whether the sale actually lowers the price (a bare "Bargain" tag doesn't).
  bool get isMarkedDown => sellingPrice < unitPrice;

  /// How much is off, as a whole percent, e.g. "20% off". Null when nothing is.
  int? get percentOff =>
      isMarkedDown && unitPrice > 0 ? ((unitPrice - sellingPrice) / unitPrice * 100).round() : null;

  /// Threshold is a configurable, store-wide setting (see SettingsViewModel)
  /// — not fixed on the item — so it's passed in rather than hardcoded.
  bool isLowStock(int threshold) => qtyOnHand <= threshold;

  /// Keeps the sale as it is; build a new Item to change or end one.
  Item copyWith({
    String? name,
    String? category,
    double? unitPrice,
    int? qtyOnHand,
    String? imagePath,
    double? unitCost,
  }) {
    return Item(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      unitPrice: unitPrice ?? this.unitPrice,
      qtyOnHand: qtyOnHand ?? this.qtyOnHand,
      onSale: onSale,
      salePercent: salePercent,
      salePrice: salePrice,
      imagePath: imagePath ?? this.imagePath,
      unitCost: unitCost ?? this.unitCost,
    );
  }
}
