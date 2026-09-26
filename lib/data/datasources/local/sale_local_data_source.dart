import 'package:sqlite_async/sqlite_async.dart';

import '../../../domain/costing.dart';
import '../../../domain/entities/sale.dart';
import '../../models/sale_model.dart';
import 'sql_helpers.dart';

abstract class SaleLocalDataSource {
  Future<void> recordSale(SaleModel model);
  Future<List<SaleModel>> getAll();

  /// Restores stock for every line item, then removes the sale. Assumes the
  /// underlying item still exists — voiding a sale for a since-deleted item
  /// is a no-op restore for that line, not an error.
  Future<void> voidSale(String saleId);
}

class SaleLocalDataSourceImpl implements SaleLocalDataSource {
  SaleLocalDataSourceImpl(this._db);
  final SqliteConnection _db;

  /// Cost is read from the item inside the transaction rather than trusted
  /// from the caller, so every path that records a sale (POS, reservation
  /// pickup) books the same cost of goods.
  @override
  Future<void> recordSale(SaleModel model) async {
    await _db.writeTransaction((txn) async {
      await txn.insert('sales', model.toMap());
      for (final line in model.lineItems) {
        final itemRows = await txn.query('items', columns: ['unitCost'], where: 'id = ?', whereArgs: [line.itemId]);
        final unitCost = itemRows.isEmpty ? null : (itemRows.single['unitCost'] as num?)?.toDouble();
        await txn.insert('sale_line_items', {...saleLineItemToMap(model.id, line), 'unitCost': unitCost});
        await txn.execute(
          'UPDATE items SET qtyOnHand = qtyOnHand - ? WHERE id = ?',
          [line.qty, line.itemId],
        );
      }
    });
  }

  @override
  Future<List<SaleModel>> getAll() async {
    final saleRows = await _db.query('sales', orderBy: 'dateTime DESC');
    final lineRows = await _db.query('sale_line_items');

    final linesBySale = <String, List<SaleLineItem>>{};
    for (final row in lineRows) {
      linesBySale.putIfAbsent(row['saleId'] as String, () => []).add(saleLineItemFromMap(row));
    }

    return saleRows.map((row) {
      final id = row['id'] as String;
      final method = row['paymentMethod'] as String?;
      return SaleModel(
        id: id,
        dateTime: DateTime.parse(row['dateTime'] as String),
        lineItems: linesBySale[id] ?? const [],
        paymentMethod: method == null ? null : PaymentMethod.values.byName(method),
        amountTendered: (row['amountTendered'] as num?)?.toDouble(),
      );
    }).toList();
  }

  @override
  Future<void> voidSale(String saleId) async {
    await _db.writeTransaction((txn) async {
      final lineRows = await txn.query('sale_line_items', where: 'saleId = ?', whereArgs: [saleId]);
      for (final row in lineRows) {
        final itemId = row['itemId'] as String;
        final qty = row['qty'] as int;
        final itemRows =
            await txn.query('items', columns: ['qtyOnHand', 'unitCost'], where: 'id = ?', whereArgs: [itemId]);
        if (itemRows.isEmpty) continue;
        // The pieces come back at what they cost, which may differ from the
        // item's average by now if a lot arrived since the sale.
        final unitCost = blendUnitCost(
          onHand: itemRows.single['qtyOnHand'] as int,
          currentCost: (itemRows.single['unitCost'] as num?)?.toDouble(),
          addedQty: qty,
          addedCost: (row['unitCost'] as num?)?.toDouble(),
        );
        await txn.execute(
          'UPDATE items SET qtyOnHand = qtyOnHand + ?, unitCost = ? WHERE id = ?',
          [qty, unitCost, itemId],
        );
      }
      await txn.delete('sale_line_items', where: 'saleId = ?', whereArgs: [saleId]);
      await txn.delete('sales', where: 'id = ?', whereArgs: [saleId]);
    });
  }
}
