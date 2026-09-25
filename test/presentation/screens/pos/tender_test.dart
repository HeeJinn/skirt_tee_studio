import 'package:flutter_test/flutter_test.dart';
import 'package:skirt_tee_studio/presentation/screens/pos/tender.dart';

void main() {
  test('quick amounts: exact, then next ₱100 / ₱500 / ₱1,000 above the total, no duplicates', () {
    expect(quickTenderAmounts(857), [857, 900, 1000]);
    expect(quickTenderAmounts(1000), [1000]);
    expect(quickTenderAmounts(1250.50), [1250.50, 1300, 1500, 2000]);
  });

  test('coverage and change are exact to the centavo despite float error', () {
    expect(coversTotal(0.3, 0.1 + 0.2), isTrue);
    expect(coversTotal(856.99, 857), isFalse);
    expect(changeDue(1000, 857), 143);
    expect(changeDue(0.3, 0.1 + 0.2), 0);
  });

  test('change breakdown uses the fewest bills and coins, largest first', () {
    // ₱143 = ₱100 + 2×₱20 + 3×₱1
    expect(changeBreakdown(143), [(10000, 1), (2000, 2), (100, 3)]);
    // ₱1,888 = ₱1,000 + ₱500 + ₱200 + ₱100 + ₱50 + ₱20 + ₱10 + ₱5 + 3×₱1
    expect(changeBreakdown(1888), [
      (100000, 1), (50000, 1), (20000, 1), (10000, 1), (5000, 1), (2000, 1), (1000, 1), (500, 1), (100, 3),
    ]);
    // Centavos: ₱0.80 = 3×25¢ + 5¢
    expect(changeBreakdown(0.80), [(25, 3), (5, 1)]);
    expect(changeBreakdown(0), isEmpty);
  });

  test('change breakdown always adds back up to the change, to the centavo', () {
    for (final change in [0.01, 0.99, 7.37, 142.5, 999.99, 4321.76]) {
      final sum = changeBreakdown(change).fold(0, (s, e) => s + e.$1 * e.$2);
      expect(sum, toCentavos(change), reason: '₱$change');
    }
  });
}
