import 'package:flutter_test/flutter_test.dart';
import 'package:skirt_tee_studio/core/utils/csv.dart';

void main() {
  test('joins headers and rows with commas', () {
    final csv = buildCsv(
      ['Name', 'Qty'],
      [
        ['Basic Tee', 3],
        ['Denim Skirt', 1],
      ],
    );

    expect(csv, 'Name,Qty\nBasic Tee,3\nDenim Skirt,1\n');
  });

  test('quotes a field containing a comma', () {
    final csv = buildCsv(['Name'], [
      ['Tee, Basic'],
    ]);

    expect(csv, 'Name\n"Tee, Basic"\n');
  });

  test('quotes and doubles embedded quotes', () {
    final csv = buildCsv(['Name'], [
      ['12" Hem'],
    ]);

    expect(csv, 'Name\n"12"" Hem"\n');
  });

  test('quotes a field containing a newline', () {
    final csv = buildCsv(['Notes'], [
      ['line one\nline two'],
    ]);

    expect(csv, 'Notes\n"line one\nline two"\n');
  });

  test('null becomes an empty field', () {
    final csv = buildCsv(['A', 'B'], [
      [null, 'x'],
    ]);

    expect(csv, 'A,B\n,x\n');
  });
}
