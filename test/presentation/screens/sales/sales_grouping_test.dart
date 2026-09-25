import 'package:flutter_test/flutter_test.dart';
import 'package:skirt_tee_studio/domain/entities/sale.dart';
import 'package:skirt_tee_studio/presentation/screens/sales/sales_grouping.dart';

void main() {
  Sale sale(String id, DateTime at, List<SaleLineItem> lines) => Sale(id: id, dateTime: at, lineItems: lines);
  const tee = SaleLineItem(itemId: 'i1', itemName: 'Tee', unitPrice: 100, qty: 1);
  const skirt = SaleLineItem(itemId: 'i2', itemName: 'Skirt', unitPrice: 300, qty: 2);

  test('groups by calendar day, newest day first, newest sale first within a day', () {
    final days = groupSalesByDay([
      sale('a', DateTime(2026, 3, 9, 10), const [tee]),
      sale('b', DateTime(2026, 3, 10, 9), const [tee]),
      sale('c', DateTime(2026, 3, 10, 16), const [skirt]),
    ]);

    expect(days.map((d) => d.day), [DateTime(2026, 3, 10), DateTime(2026, 3, 9)]);
    expect(days.first.sales.map((s) => s.id), ['c', 'b']);
    expect(days.first.total, 700);
  });

  test('dayLabel says Today / Yesterday, then a weekday date', () {
    final now = DateTime(2026, 3, 10, 18);
    expect(dayLabel(DateTime(2026, 3, 10), now), 'Today');
    expect(dayLabel(DateTime(2026, 3, 9), now), 'Yesterday');
    expect(dayLabel(DateTime(2026, 3, 6), now), 'Fri, Mar 6');
  });

  test('saleSummary lists items, with a quantity only when more than one', () {
    expect(saleSummary(sale('a', DateTime(2026), const [tee, skirt])), 'Tee, Skirt ×2');
  });
}
