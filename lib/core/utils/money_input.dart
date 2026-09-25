/// Parses a peso amount as typed into a form: tolerates thousands commas,
/// a leading ₱, and surrounding spaces ("₱ 50,000" → 50000). Null if it
/// isn't a number.
double? parseAmount(String? text) {
  if (text == null) return null;
  final cleaned = text.replaceAll(RegExp(r'[₱,\s]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Form-field text for a stored amount: whole pesos without a trailing
/// ".0", centavos kept when there are any.
String formatAmountInput(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
