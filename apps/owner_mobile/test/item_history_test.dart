import 'package:flutter_test/flutter_test.dart';
import 'package:owner_mobile/presentation/screens/stock/item_history.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:shop_core/domain/entities/stock.dart';

StockMovement movement(DateTime at, StockMovementType type, int qty,
        {String itemId = 'skirt', WriteOffReason? reason, String? lotId, String note = ''}) =>
    StockMovement(
      at: at,
      itemId: itemId,
      itemName: 'Pleated skirt',
      type: type,
      qty: qty,
      unitCost: 200,
      reason: reason,
      lotId: lotId,
      note: note,
    );

Sale sale(DateTime at, List<(String, int)> lines) => Sale(
      id: '$at',
      dateTime: at,
      lineItems: [
        for (final (id, qty) in lines) SaleLineItem(itemId: id, itemName: id, unitPrice: 100, qty: qty),
      ],
    );

void main() {
  test('merges lots, write-offs, finds, and sales for one item, newest first', () {
    final history = itemHistory(
      itemId: 'skirt',
      lots: [StockLot(id: 'lot-1', at: DateTime(2026, 9, 1), supplier: 'Divisoria bale', itemsCost: 1000)],
      movements: [
        movement(DateTime(2026, 9, 1), StockMovementType.received, 10, lotId: 'lot-1'),
        movement(DateTime(2026, 9, 3), StockMovementType.writeOff, 1, reason: WriteOffReason.damaged, note: 'Torn'),
        movement(DateTime(2026, 9, 4), StockMovementType.found, 1),
        movement(DateTime(2026, 9, 5), StockMovementType.received, 5, itemId: 'tee'),
      ],
      sales: [
        sale(DateTime(2026, 9, 2), [('skirt', 2), ('tee', 1)]),
        sale(DateTime(2026, 9, 6), [('tee', 3)]),
      ],
    );

    expect(history.map((e) => (e.title, e.change)), [
      ('Found', 1),
      ('Damaged', -1),
      ('Sold', -2),
      ('Received from Divisoria bale', 10),
    ]);
    expect(history[1].detail, 'Torn');
  });

  test('pieces received without a known lot just say received', () {
    final history = itemHistory(
      itemId: 'skirt',
      lots: const [],
      movements: [movement(DateTime(2026, 9, 1), StockMovementType.received, 3, lotId: 'gone')],
      sales: const [],
    );
    expect(history.single.title, 'Received');
  });

  test('sums up a stretch of history by what happened', () {
    final history = itemHistory(
      itemId: 'skirt',
      lots: const [],
      movements: [
        movement(DateTime(2026, 9, 1), StockMovementType.received, 10),
        movement(DateTime(2026, 9, 2), StockMovementType.received, 4),
        movement(DateTime(2026, 9, 3), StockMovementType.writeOff, 1, reason: WriteOffReason.damaged),
      ],
      sales: [
        sale(DateTime(2026, 9, 4), [('skirt', 2)]),
        sale(DateTime(2026, 9, 5), [('skirt', 1), ('tee', 5)]),
      ],
    );
    expect(historySummary(history), '3 sold · 14 received · 1 written off');
    expect(historySummary(history.where((e) => e.kind == ItemChangeKind.sold)), '3 sold');
    expect(historySummary(const []), isNull);
  });

  test('counts pieces sold from a date on', () {
    final sales = [
      sale(DateTime(2026, 8, 31, 23), [('skirt', 5)]),
      sale(DateTime(2026, 9, 1), [('skirt', 2)]),
      sale(DateTime(2026, 9, 10), [('skirt', 1), ('tee', 4)]),
    ];
    expect(piecesSoldSince('skirt', sales, DateTime(2026, 9, 1)), 3);
  });
}
