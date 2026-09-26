import 'package:intl/intl.dart';

final peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
final pesoWhole = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);

/// "−₱1,200.00" with a true minus sign (the default "-₱" hyphen reads as a
/// dash in a column of figures); positives unchanged.
String signedPeso(double v, {bool whole = false}) {
  final format = whole ? pesoWhole : peso;
  return v < 0 ? '−${format.format(-v)}' : format.format(v);
}

/// An amount being taken away ("−₱500.00"), with no sign on zero.
String minusPeso(double v) => v == 0 ? peso.format(0) : '−${peso.format(v)}';

/// Compact axis label on round numbers: ₱0, ₱500, ₱1K, ₱1.5K, ₱12K.
String axisPeso(double v) {
  if (v >= 1000) {
    final k = v / 1000;
    return '₱${k == k.roundToDouble() ? k.toInt() : k.toStringAsFixed(1)}K';
  }
  return '₱${v.toInt()}';
}
