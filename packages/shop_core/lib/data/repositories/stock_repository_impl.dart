import 'package:sqlite_async/sqlite_async.dart';

import '../../domain/costing.dart';
import '../../domain/entities/item.dart';
import '../../domain/entities/stock.dart';
import '../../domain/repositories/stock_repository.dart';
import '../datasources/local/sql_helpers.dart';
import '../models/item_model.dart';
import '../models/money_models.dart';

class StockRepositoryImpl implements StockRepository {
  StockRepositoryImpl(this._db);
  final SqliteConnection _db;

  @override
  Future<void> receiveLot(StockLot lot, List<LotLine> lines, {List<Item> newItems = const []}) async {
    if (lines.isEmpty || lines.any((l) => l.qty <= 0)) {
      throw StockChangeException('Add at least one piece to every item in the lot.');
    }
    final unitCosts = allocateLotCost(lot.totalCost, lines);

    await _db.writeTransaction((txn) async {
      for (final item in newItems) {
        await txn.insert('items', ItemModel.fromEntity(item.copyWith(qtyOnHand: 0)).toMap());
      }
      await txn.insert('stock_lots', stockLotToMap(lot));
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final item = await _currentStock(txn, line.itemId, line.itemName);
        final unitCost = blendUnitCost(
          onHand: item.qty,
          currentCost: item.unitCost,
          addedQty: line.qty,
          addedCost: unitCosts[i],
        );
        await txn.execute(
          'UPDATE items SET qtyOnHand = qtyOnHand + ?, unitCost = ? WHERE id = ?',
          [line.qty, unitCost, line.itemId],
        );
        await txn.insert(
          'stock_movements',
          stockMovementToMap(StockMovement(
            at: lot.at,
            itemId: line.itemId,
            itemName: line.itemName,
            type: StockMovementType.received,
            qty: line.qty,
            unitCost: unitCosts[i],
            lotId: lot.id,
          )),
        );
      }
    });
  }

  @override
  Future<void> writeOff(String itemId, int qty, WriteOffReason reason, {String note = '', DateTime? at}) async {
    if (qty <= 0) throw StockChangeException('Enter how many pieces to remove.');
    await _db.writeTransaction((txn) async {
      final item = await _currentStock(txn, itemId);
      if (qty > item.qty) {
        throw StockChangeException('Only ${item.qty} of "${item.name}" in stock — can\'t remove $qty.');
      }
      await txn.execute('UPDATE items SET qtyOnHand = qtyOnHand - ? WHERE id = ?', [qty, itemId]);
      await txn.insert('stock_movements', stockMovementToMap(item.movement(StockMovementType.writeOff, qty, at, note, reason)));
    });
  }

  @override
  Future<void> markFound(String itemId, int qty, {String note = '', DateTime? at}) async {
    if (qty <= 0) throw StockChangeException('Enter how many pieces were found.');
    await _db.writeTransaction((txn) async {
      final item = await _currentStock(txn, itemId);
      await txn.execute('UPDATE items SET qtyOnHand = qtyOnHand + ? WHERE id = ?', [qty, itemId]);
      await txn.insert('stock_movements', stockMovementToMap(item.movement(StockMovementType.found, qty, at, note)));
    });
  }

  @override
  Future<void> removeItem(String itemId) async {
    await _db.writeTransaction((txn) async {
      final rows = await txn.query('items', columns: ['id'], where: 'id = ?', whereArgs: [itemId]);
      if (rows.isEmpty) return;
      final item = await _currentStock(txn, itemId);
      if (item.qty > 0) {
        await txn.insert(
          'stock_movements',
          stockMovementToMap(item.movement(StockMovementType.writeOff, item.qty, null, '', WriteOffReason.removed)),
        );
      }
      await txn.delete('items', where: 'id = ?', whereArgs: [itemId]);
    });
  }

  @override
  Future<List<StockLot>> getLots() async {
    final rows = await _db.query('stock_lots', orderBy: 'at DESC');
    return rows.map(stockLotFromMap).toList();
  }

  @override
  Future<List<StockMovement>> getMovements() async {
    final rows = await _db.query('stock_movements', orderBy: 'at DESC');
    return rows.map(stockMovementFromMap).toList();
  }

  Future<_Stock> _currentStock(SqliteReadContext txn, String itemId, [String? nameForError]) async {
    final rows = await txn.query(
      'items',
      columns: ['name', 'qtyOnHand', 'unitCost'],
      where: 'id = ?',
      whereArgs: [itemId],
    );
    if (rows.isEmpty) {
      throw StockChangeException('"${nameForError ?? 'That item'}" is no longer in inventory.');
    }
    final row = rows.single;
    return _Stock(
      id: itemId,
      name: row['name'] as String,
      qty: row['qtyOnHand'] as int,
      unitCost: (row['unitCost'] as num?)?.toDouble(),
    );
  }
}

/// An item's stock as it stands inside a transaction.
class _Stock {
  const _Stock({required this.id, required this.name, required this.qty, required this.unitCost});
  final String id;
  final String name;
  final int qty;
  final double? unitCost;

  StockMovement movement(StockMovementType type, int qty, DateTime? at, String note, [WriteOffReason? reason]) =>
      StockMovement(
        at: at ?? DateTime.now(),
        itemId: id,
        itemName: name,
        type: type,
        qty: qty,
        unitCost: unitCost ?? 0,
        reason: reason,
        note: note,
      );
}
