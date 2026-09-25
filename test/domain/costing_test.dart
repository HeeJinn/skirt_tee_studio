import 'package:flutter_test/flutter_test.dart';
import 'package:skirt_tee_studio/domain/costing.dart';
import 'package:skirt_tee_studio/domain/entities/stock.dart';

void main() {
  LotLine line(String id, int qty, double price) =>
      LotLine(itemId: id, itemName: id, qty: qty, sellingPrice: price);

  group('allocateLotCost', () {
    test('splits a mixed lot by selling value, so every piece carries the same margin', () {
      // ₱8,000 bale + ₱400 shipping; would sell for ₱10,500 in total.
      final costs = allocateLotCost(8400, [
        line('tee', 30, 150),
        line('skirt', 20, 250),
        line('kids', 10, 100),
      ]);

      expect(costs[0], closeTo(120, 1e-9));
      expect(costs[1], closeTo(200, 1e-9));
      expect(costs[2], closeTo(80, 1e-9));
    });

    test('the split adds back up to the lot\'s full cost', () {
      final lines = [line('a', 7, 199), line('b', 3, 349), line('c', 11, 99)];
      final costs = allocateLotCost(5000, lines);

      var total = 0.0;
      for (var i = 0; i < lines.length; i++) {
        total += costs[i] * lines[i].qty;
      }
      expect(total, closeTo(5000, 1e-6));
    });

    test('falls back to an even split when nothing has a selling price', () {
      expect(allocateLotCost(1000, [line('a', 4, 0), line('b', 6, 0)]), [100, 100]);
    });

    test('an empty lot allocates nothing, rather than dividing by zero', () {
      expect(allocateLotCost(1000, const []), isEmpty);
    });
  });

  group('blendUnitCost', () {
    test('weights the average by quantity', () {
      expect(blendUnitCost(onHand: 10, currentCost: 300, addedQty: 10, addedCost: 350), 325);
      expect(blendUnitCost(onHand: 30, currentCost: 100, addedQty: 10, addedCost: 200), 125);
    });

    test('an empty shelf takes the new cost outright', () {
      expect(blendUnitCost(onHand: 0, currentCost: 999, addedQty: 5, addedCost: 120), 120);
    });

    test('stock with no recorded cost counts as free', () {
      expect(blendUnitCost(onHand: 10, currentCost: null, addedQty: 10, addedCost: 300), 150);
    });

    test('stays unknown only when neither side has a cost', () {
      expect(blendUnitCost(onHand: 3, currentCost: null, addedQty: 2, addedCost: null), isNull);
    });

    test('negative stock on hand is treated as empty', () {
      expect(blendUnitCost(onHand: -2, currentCost: 50, addedQty: 4, addedCost: 80), 80);
    });
  });
}
