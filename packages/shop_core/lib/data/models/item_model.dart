import '../../domain/entities/item.dart';
import '../datasources/local/item_image_storage.dart';

class ItemModel extends Item {
  const ItemModel({
    required super.id,
    required super.name,
    required super.category,
    required super.unitPrice,
    required super.qtyOnHand,
    super.onSale,
    super.salePercent,
    super.salePrice,
    super.imagePath,
    super.unitCost,
  });

  factory ItemModel.fromEntity(Item item) => ItemModel(
        id: item.id,
        name: item.name,
        category: item.category,
        unitPrice: item.unitPrice,
        qtyOnHand: item.qtyOnHand,
        onSale: item.onSale,
        salePercent: item.salePercent,
        salePrice: item.salePrice,
        imagePath: item.imagePath,
        unitCost: item.unitCost,
      );

  factory ItemModel.fromMap(Map<String, dynamic> map) => ItemModel(
        id: map['id'] as String,
        name: map['name'] as String,
        category: map['category'] as String,
        unitPrice: (map['unitPrice'] as num).toDouble(),
        qtyOnHand: map['qtyOnHand'] as int,
        // The column kept its name from when a sale was a "Bargain" tag.
        onSale: (map['isBargain'] as int) == 1,
        salePercent: (map['salePercent'] as num?)?.toDouble(),
        salePrice: (map['salePrice'] as num?)?.toDouble(),
        imagePath: switch (map['imageKey'] as String?) {
          final key? => ItemImageStorage.instance.pathFor(key),
          null => null,
        },
        unitCost: (map['unitCost'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'unitPrice': unitPrice,
        'qtyOnHand': qtyOnHand,
        'isBargain': onSale ? 1 : 0,
        'salePercent': onSale ? salePercent : null,
        'salePrice': onSale ? salePrice : null,
        'imageKey': switch (imagePath) {
          final path? => ItemImageStorage.keyFor(path),
          null => null,
        },
        'unitCost': unitCost,
      };
}
