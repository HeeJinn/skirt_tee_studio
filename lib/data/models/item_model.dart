import '../../domain/entities/item.dart';

class ItemModel extends Item {
  const ItemModel({
    required super.id,
    required super.name,
    required super.category,
    required super.unitPrice,
    required super.qtyOnHand,
    super.isBargain,
    super.imagePath,
    super.unitCost,
  });

  factory ItemModel.fromEntity(Item item) => ItemModel(
        id: item.id,
        name: item.name,
        category: item.category,
        unitPrice: item.unitPrice,
        qtyOnHand: item.qtyOnHand,
        isBargain: item.isBargain,
        imagePath: item.imagePath,
        unitCost: item.unitCost,
      );

  factory ItemModel.fromMap(Map<String, dynamic> map) => ItemModel(
        id: map['id'] as String,
        name: map['name'] as String,
        category: map['category'] as String,
        unitPrice: (map['unitPrice'] as num).toDouble(),
        qtyOnHand: map['qtyOnHand'] as int,
        isBargain: (map['isBargain'] as int) == 1,
        imagePath: map['imagePath'] as String?,
        unitCost: (map['unitCost'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'unitPrice': unitPrice,
        'qtyOnHand': qtyOnHand,
        'isBargain': isBargain ? 1 : 0,
        'imagePath': imagePath,
        'unitCost': unitCost,
      };
}
