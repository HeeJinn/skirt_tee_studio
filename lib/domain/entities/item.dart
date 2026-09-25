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
    this.isBargain = false,
    this.imagePath,
    this.unitCost,
  });

  final String id;
  final String name;
  final String category; // e.g. "T-Shirt", "Skirt", "Kids"
  final double unitPrice;
  final int qtyOnHand;
  final bool isBargain;

  /// Local filesystem path to a copy this app made under its own storage
  /// (see ItemImageStorage) — never a path chosen by the user directly, so
  /// it stays valid even if they move or delete the original file. Null
  /// means no photo.
  final String? imagePath;

  /// What one piece cost the shop, averaged across every lot it came from
  /// (see blendUnitCost). Null means never recorded — stock on hand from
  /// before cost tracking started, which the books count at ₱0.
  final double? unitCost;

  /// Threshold is a configurable, store-wide setting (see SettingsViewModel)
  /// — not fixed on the item — so it's passed in rather than hardcoded.
  bool isLowStock(int threshold) => qtyOnHand <= threshold;

  Item copyWith({
    String? name,
    String? category,
    double? unitPrice,
    int? qtyOnHand,
    bool? isBargain,
    String? imagePath,
    double? unitCost,
  }) {
    return Item(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      unitPrice: unitPrice ?? this.unitPrice,
      qtyOnHand: qtyOnHand ?? this.qtyOnHand,
      isBargain: isBargain ?? this.isBargain,
      imagePath: imagePath ?? this.imagePath,
      unitCost: unitCost ?? this.unitCost,
    );
  }
}
