import '../../domain/entities/sale.dart';

class SaleModel extends Sale {
  const SaleModel({
    required super.id,
    required super.dateTime,
    required super.lineItems,
    super.paymentMethod,
    super.amountTendered,
  });

  factory SaleModel.fromEntity(Sale sale) => SaleModel(
        id: sale.id,
        dateTime: sale.dateTime,
        lineItems: sale.lineItems,
        paymentMethod: sale.paymentMethod,
        amountTendered: sale.amountTendered,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'paymentMethod': paymentMethod?.name,
        'amountTendered': amountTendered,
      };
}

/// SQLite row for one sale_line_items entry, keyed to its parent sale.
Map<String, dynamic> saleLineItemToMap(String saleId, SaleLineItem line) => {
      'saleId': saleId,
      'itemId': line.itemId,
      'itemName': line.itemName,
      'unitPrice': line.unitPrice,
      'qty': line.qty,
      'unitCost': line.unitCost,
    };

SaleLineItem saleLineItemFromMap(Map<String, dynamic> map) => SaleLineItem(
      itemId: map['itemId'] as String,
      itemName: map['itemName'] as String,
      unitPrice: (map['unitPrice'] as num).toDouble(),
      qty: map['qty'] as int,
      unitCost: (map['unitCost'] as num?)?.toDouble(),
    );
