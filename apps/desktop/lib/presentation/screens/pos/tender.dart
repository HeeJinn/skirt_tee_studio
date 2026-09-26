/// Whole centavos — money comparisons in doubles misfire (0.1 + 0.2 ≠ 0.3).
int toCentavos(double pesos) => (pesos * 100).round();

bool coversTotal(double received, double total) => toCentavos(received) >= toCentavos(total);

double changeDue(double received, double total) => (toCentavos(received) - toCentavos(total)) / 100;

/// Circulating Philippine bills and coins, largest first, in centavos.
/// ₱20 is both a bill and a coin; it's listed once.
const kPesoDenominations = [100000, 50000, 20000, 10000, 5000, 2000, 1000, 500, 100, 25, 5, 1];

/// What a customer can hand over, for tap-to-count on the cash pad. Centavo
/// coins are left out — nobody pays in them, they only come back as change.
const kTenderDenominations = [100000, 50000, 20000, 10000, 5000, 2000, 1000, 500, 100];

/// Bills are ₱20 and up; everything smaller is a coin.
bool isBill(int centavos) => centavos >= 2000;

/// How to hand back [change] using the fewest bills and coins, as
/// (denomination in centavos, count) pairs, largest first. Greedy is optimal
/// here because the peso series (1-2-5 steps plus 25¢) is canonical.
List<(int, int)> changeBreakdown(double change) {
  var remaining = toCentavos(change);
  final result = <(int, int)>[];
  for (final d in kPesoDenominations) {
    if (remaining < d) continue;
    result.add((d, remaining ~/ d));
    remaining %= d;
  }
  return result;
}

/// Quick "amount received" buttons: exact, then the next round amounts a
/// customer is likely to hand over, above the total.
List<double> quickTenderAmounts(double total) {
  final amounts = <int>{toCentavos(total)};
  for (final step in const [10000, 50000, 100000]) {
    // ₱100 / ₱500 / ₱1,000 in centavos
    final rounded = (toCentavos(total) / step).ceil() * step;
    if (rounded > toCentavos(total)) amounts.add(rounded);
  }
  return (amounts.toList()..sort()).map((c) => c / 100).toList();
}
