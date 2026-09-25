import '../../domain/entities/money_entry.dart';
import '../../domain/entities/stock.dart';

/// SQLite mappings for the money log and stock history. Enums are stored by
/// name, like PaymentMethod on sales.

Map<String, dynamic> moneyEntryToMap(MoneyEntry e) => {
      'id': e.id,
      'at': e.at.toIso8601String(),
      'kind': e.kind.name,
      'amount': e.amount,
      'category': e.category?.name,
      'paidFrom': e.paidFrom.name,
      'person': e.person,
      'note': e.note,
    };

MoneyEntry moneyEntryFromMap(Map<String, dynamic> map) {
  final category = map['category'] as String?;
  return MoneyEntry(
    id: map['id'] as String,
    at: DateTime.parse(map['at'] as String),
    kind: MoneyEntryKind.values.byName(map['kind'] as String),
    amount: (map['amount'] as num).toDouble(),
    category: category == null ? null : ExpenseCategory.values.byName(category),
    paidFrom: PaidFrom.values.byName(map['paidFrom'] as String),
    person: map['person'] as String?,
    note: map['note'] as String,
  );
}

Map<String, dynamic> stockLotToMap(StockLot lot) => {
      'id': lot.id,
      'at': lot.at.toIso8601String(),
      'supplier': lot.supplier,
      'itemsCost': lot.itemsCost,
      'fees': lot.fees,
      'paidFrom': lot.paidFrom.name,
      'person': lot.person,
      'note': lot.note,
    };

StockLot stockLotFromMap(Map<String, dynamic> map) => StockLot(
      id: map['id'] as String,
      at: DateTime.parse(map['at'] as String),
      supplier: map['supplier'] as String,
      itemsCost: (map['itemsCost'] as num).toDouble(),
      fees: (map['fees'] as num).toDouble(),
      paidFrom: PaidFrom.values.byName(map['paidFrom'] as String),
      person: map['person'] as String?,
      note: map['note'] as String,
    );

Map<String, dynamic> stockMovementToMap(StockMovement m) => {
      'at': m.at.toIso8601String(),
      'itemId': m.itemId,
      'itemName': m.itemName,
      'type': m.type.name,
      'qty': m.qty,
      'unitCost': m.unitCost,
      'reason': m.reason?.name,
      'lotId': m.lotId,
      'note': m.note,
    };

StockMovement stockMovementFromMap(Map<String, dynamic> map) {
  final reason = map['reason'] as String?;
  return StockMovement(
    at: DateTime.parse(map['at'] as String),
    itemId: map['itemId'] as String,
    itemName: map['itemName'] as String,
    type: StockMovementType.values.byName(map['type'] as String),
    qty: map['qty'] as int,
    unitCost: (map['unitCost'] as num).toDouble(),
    reason: reason == null ? null : WriteOffReason.values.byName(reason),
    lotId: map['lotId'] as String?,
    note: map['note'] as String,
  );
}
