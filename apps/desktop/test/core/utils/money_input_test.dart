import 'package:flutter_test/flutter_test.dart';
import 'package:skirt_tee_studio/core/utils/money_input.dart';

void main() {
  test('parseAmount accepts commas, a peso sign, and spaces', () {
    expect(parseAmount('50,000'), 50000);
    expect(parseAmount(' ₱ 1,250.50 '), 1250.5);
    expect(parseAmount('199'), 199);
  });

  test('parseAmount is null for blanks and non-numbers', () {
    expect(parseAmount(null), isNull);
    expect(parseAmount('  '), isNull);
    expect(parseAmount('abc'), isNull);
  });

  test('formatAmountInput drops a trailing .0 but keeps centavos', () {
    expect(formatAmountInput(120), '120');
    expect(formatAmountInput(133.3333), '133.33');
  });
}
