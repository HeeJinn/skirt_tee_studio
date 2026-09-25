import 'package:flutter_test/flutter_test.dart';
import 'package:skirt_tee_studio/domain/entities/sale.dart';
import 'package:skirt_tee_studio/presentation/screens/reports/report_calculations.dart';

void main() {
  final now = DateTime(2026, 1, 10, 15, 0);

  Sale sale(DateTime dateTime, List<SaleLineItem> lineItems) =>
      Sale(id: 'sale-${dateTime.toIso8601String()}', dateTime: dateTime, lineItems: lineItems);

  group('summarize', () {
    test('totals revenue, sale count, items, and average sale', () {
      final summary = summarize([
        sale(now, const [SaleLineItem(itemId: 'i1', itemName: 'Tee', unitPrice: 100, qty: 3)]),
        sale(now, const [SaleLineItem(itemId: 'i2', itemName: 'Skirt', unitPrice: 500, qty: 1)]),
      ]);

      expect(summary.revenue, 800);
      expect(summary.saleCount, 2);
      expect(summary.itemsSold, 4);
      expect(summary.averageSale, 400);
    });

    test('average is zero, not NaN, with no sales', () {
      expect(summarize(const []).averageSale, 0);
    });

    test('cash vs cashless split; unrecorded method counts in neither', () {
      const line = SaleLineItem(itemId: 'i', itemName: 'Tee', unitPrice: 100, qty: 1);
      final summary = summarize([
        Sale(id: 'a', dateTime: now, lineItems: const [line], paymentMethod: PaymentMethod.cash),
        Sale(id: 'b', dateTime: now, lineItems: const [line], paymentMethod: PaymentMethod.gcash),
        Sale(id: 'c', dateTime: now, lineItems: const [line], paymentMethod: PaymentMethod.cashless),
        Sale(id: 'd', dateTime: now, lineItems: const [line]),
      ]);

      expect(summary.revenue, 400);
      expect(summary.cashRevenue, 100);
      expect(summary.cashlessRevenue, 200);
    });
  });

  group('niceStep / niceCeiling', () {
    test('steps land on 1/2/2.5/5 × a power of ten', () {
      expect(niceStep(1960), 500);
      expect(niceStep(97), 25);
      expect(niceStep(7), 2);
      expect(niceStep(40), 10);
    });

    test('ceiling is the next round multiple at or above the max', () {
      expect(niceCeiling(1960), 2000);
      expect(niceCeiling(2000), 2000);
      expect(niceCeiling(97), 100);
    });

    test('a zero max still yields a usable, non-zero axis', () {
      expect(niceStep(0), 1);
      expect(niceCeiling(0), 1);
    });
  });

  group('filterSalesByRange', () {
    final sales = [
      sale(DateTime(2026, 1, 1), const []), // 9 days before "now"
      sale(DateTime(2026, 1, 9), const []), // yesterday
      sale(DateTime(2026, 1, 10, 8), const []), // today, earlier
    ];

    test('last7Days keeps only sales within the trailing 7-day window', () {
      final result = filterSalesByRange(sales, ReportRange.last7Days, now);
      expect(result, hasLength(2));
    });

    test('allTime keeps everything', () {
      expect(filterSalesByRange(sales, ReportRange.allTime, now), hasLength(3));
    });

    test('today keeps only sales since midnight', () {
      expect(filterSalesByRange(sales, ReportRange.today, now), hasLength(1));
    });
  });

  group('dailyRevenue', () {
    test('last7Days fills every day in the window, zero where there were no sales', () {
      final sales = [
        sale(DateTime(2026, 1, 10), const [
          SaleLineItem(itemId: 'i1', itemName: 'Tee', unitPrice: 100, qty: 2),
        ]),
      ];

      final result = dailyRevenue(sales, ReportRange.last7Days, now);

      expect(result, hasLength(7));
      expect(result.first.date, DateTime(2026, 1, 4));
      expect(result.last.date, DateTime(2026, 1, 10));
      expect(result.last.amount, 200);
      expect(result.first.amount, 0);
    });

    test('same-day sales are summed into one bucket', () {
      final sales = [
        sale(DateTime(2026, 1, 10, 9), const [
          SaleLineItem(itemId: 'i1', itemName: 'Tee', unitPrice: 100, qty: 1),
        ]),
        sale(DateTime(2026, 1, 10, 14), const [
          SaleLineItem(itemId: 'i1', itemName: 'Tee', unitPrice: 100, qty: 1),
        ]),
      ];

      final result = dailyRevenue(sales, ReportRange.last7Days, now);

      expect(result.last.amount, 200);
    });

    test('allTime is empty when there are no sales', () {
      expect(dailyRevenue(const [], ReportRange.allTime, now), isEmpty);
    });

    test('allTime starts at the earliest sale, not a fixed window', () {
      final sales = [
        sale(DateTime(2026, 1, 8), const [
          SaleLineItem(itemId: 'i1', itemName: 'Tee', unitPrice: 50, qty: 1),
        ]),
      ];

      final result = dailyRevenue(sales, ReportRange.allTime, now);

      expect(result.first.date, DateTime(2026, 1, 8));
      expect(result.last.date, DateTime(2026, 1, 10));
    });
  });

  group('topSellingItems', () {
    test('sums quantity per item name across sales and ranks descending', () {
      final sales = [
        sale(now, const [
          SaleLineItem(itemId: 'i1', itemName: 'Tee', unitPrice: 100, qty: 3),
          SaleLineItem(itemId: 'i2', itemName: 'Skirt', unitPrice: 200, qty: 5),
        ]),
        sale(now, const [
          SaleLineItem(itemId: 'i1', itemName: 'Tee', unitPrice: 100, qty: 4),
        ]),
      ];

      final result = topSellingItems(sales);

      expect(result.map((r) => r.itemName).toList(), ['Tee', 'Skirt']);
      expect(result.first.qty, 7);
    });

    test('limit caps the result', () {
      final sales = [
        sale(now, const [
          SaleLineItem(itemId: 'i1', itemName: 'A', unitPrice: 1, qty: 3),
          SaleLineItem(itemId: 'i2', itemName: 'B', unitPrice: 1, qty: 2),
          SaleLineItem(itemId: 'i3', itemName: 'C', unitPrice: 1, qty: 1),
        ]),
      ];

      expect(topSellingItems(sales, limit: 2), hasLength(2));
    });
  });

  group('revenueByCategory', () {
    test('groups by category via the itemId lookup and ranks by revenue', () {
      final sales = [
        sale(now, const [
          SaleLineItem(itemId: 'i1', itemName: 'Tee', unitPrice: 100, qty: 2), // 200
          SaleLineItem(itemId: 'i2', itemName: 'Skirt', unitPrice: 300, qty: 1), // 300
        ]),
      ];
      final categoryByItemId = {'i1': 'T-Shirt', 'i2': 'Skirt'};

      final result = revenueByCategory(sales, categoryByItemId);

      expect(result.map((r) => r.category).toList(), ['Skirt', 'T-Shirt']);
      expect(result.first.amount, 300);
    });

    test('falls back to Other for an itemId missing from the lookup (deleted item)', () {
      final sales = [
        sale(now, const [
          SaleLineItem(itemId: 'gone', itemName: 'Discontinued Tee', unitPrice: 100, qty: 1),
        ]),
      ];

      final result = revenueByCategory(sales, const {});

      expect(result.single.category, 'Other');
      expect(result.single.amount, 100);
    });
  });
}
