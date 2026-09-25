import 'dart:math' as math;

import '../../../domain/entities/sale.dart';

enum ReportRange { today, last7Days, last30Days, allTime }

/// Headline numbers for the selected range — the KPI row a report leads with.
class ReportSummary {
  const ReportSummary({
    required this.revenue,
    required this.saleCount,
    required this.itemsSold,
    required this.cashRevenue,
    required this.cashlessRevenue,
  });

  final double revenue;
  final int saleCount;
  final int itemsSold;

  /// Should match the drawer.
  final double cashRevenue;

  /// Every recorded non-cash method. Sales with no recorded method (from
  /// before it was tracked) count in neither split — only in [revenue].
  final double cashlessRevenue;

  double get averageSale => saleCount == 0 ? 0 : revenue / saleCount;
}

ReportSummary summarize(List<Sale> sales) {
  double sumWhere(bool Function(Sale) test) => sales.where(test).fold(0, (sum, s) => sum + s.totalAmount);
  return ReportSummary(
    revenue: sumWhere((_) => true),
    saleCount: sales.length,
    itemsSold: sales.fold(0, (sum, s) => sum + s.totalItemsSold),
    cashRevenue: sumWhere((s) => s.paymentMethod == PaymentMethod.cash),
    cashlessRevenue: sumWhere((s) => s.paymentMethod != null && s.paymentMethod != PaymentMethod.cash),
  );
}

/// A "nice" axis step (1, 2, 2.5, or 5 × a power of ten) so ticks land on
/// round numbers like 0 / 500 / 1,000 rather than 0 / 489 / 978.
double niceStep(double maxValue, {int targetTicks = 4}) {
  if (maxValue <= 0) return 1;
  final raw = maxValue / targetTicks;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final normalized = raw / magnitude;
  final nice = normalized <= 1
      ? 1.0
      : normalized <= 2
          ? 2.0
          : normalized <= 2.5
              ? 2.5
              : normalized <= 5
                  ? 5.0
                  : 10.0;
  return nice * magnitude;
}

/// The axis ceiling: the smallest multiple of [niceStep] at or above [maxValue].
double niceCeiling(double maxValue, {int targetTicks = 4}) {
  final step = niceStep(maxValue, targetTicks: targetTicks);
  return math.max(step, (maxValue / step).ceil() * step);
}

extension ReportRangeX on ReportRange {
  String get description => switch (this) {
        ReportRange.today => 'Today',
        ReportRange.last7Days => 'Last 7 days',
        ReportRange.last30Days => 'Last 30 days',
        ReportRange.allTime => 'All time',
      };

  String get label => switch (this) {
        ReportRange.today => 'TODAY',
        ReportRange.last7Days => '7 DAYS',
        ReportRange.last30Days => '30 DAYS',
        ReportRange.allTime => 'ALL TIME',
      };

  /// Inclusive start-of-day; null for allTime (bounded by the data itself).
  DateTime? startDate(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      ReportRange.today => today,
      ReportRange.last7Days => today.subtract(const Duration(days: 6)),
      ReportRange.last30Days => today.subtract(const Duration(days: 29)),
      ReportRange.allTime => null,
    };
  }
}

class DailyRevenue {
  const DailyRevenue({required this.date, required this.amount});
  final DateTime date;
  final double amount;
}

class ItemSales {
  const ItemSales({required this.itemName, required this.qty});
  final String itemName;
  final int qty;
}

class CategoryRevenue {
  const CategoryRevenue({required this.category, required this.amount});
  final String category;
  final double amount;
}

List<Sale> filterSalesByRange(List<Sale> sales, ReportRange range, DateTime now) {
  final start = range.startDate(now);
  if (start == null) return sales;
  return sales.where((s) => !s.dateTime.isBefore(start)).toList();
}

/// Buckets sales by calendar day and fills gaps with zero, so a trend chart
/// shows every day in range rather than skipping days with no sales.
/// allTime is bounded by the earliest sale actually on record, not a fixed
/// window — this is a young store, not a year of history to render.
List<DailyRevenue> dailyRevenue(List<Sale> sales, ReportRange range, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  var start = range.startDate(now);
  if (start == null) {
    if (sales.isEmpty) return const [];
    final earliest = sales.map((s) => s.dateTime).reduce((a, b) => a.isBefore(b) ? a : b);
    start = DateTime(earliest.year, earliest.month, earliest.day);
  }

  final totalsByDay = <DateTime, double>{};
  for (final sale in sales) {
    final day = DateTime(sale.dateTime.year, sale.dateTime.month, sale.dateTime.day);
    totalsByDay.update(day, (v) => v + sale.totalAmount, ifAbsent: () => sale.totalAmount);
  }

  final days = <DailyRevenue>[];
  for (var day = start; !day.isAfter(today); day = day.add(const Duration(days: 1))) {
    days.add(DailyRevenue(date: day, amount: totalsByDay[day] ?? 0));
  }
  return days;
}

List<ItemSales> topSellingItems(List<Sale> sales, {int limit = 5}) {
  final qtyByName = <String, int>{};
  for (final sale in sales) {
    for (final line in sale.lineItems) {
      qtyByName.update(line.itemName, (v) => v + line.qty, ifAbsent: () => line.qty);
    }
  }
  final ranked = qtyByName.entries.map((e) => ItemSales(itemName: e.key, qty: e.value)).toList()
    ..sort((a, b) => b.qty.compareTo(a.qty));
  return ranked.take(limit).toList();
}

/// [categoryByItemId] is the live inventory's itemId -> category lookup;
/// a line item whose product has since been deleted from inventory falls
/// back to "Other" rather than being dropped from the total.
List<CategoryRevenue> revenueByCategory(List<Sale> sales, Map<String, String> categoryByItemId) {
  final totals = <String, double>{};
  for (final sale in sales) {
    for (final line in sale.lineItems) {
      final category = categoryByItemId[line.itemId] ?? 'Other';
      totals.update(category, (v) => v + line.subtotal, ifAbsent: () => line.subtotal);
    }
  }
  final ranked = totals.entries.map((e) => CategoryRevenue(category: e.key, amount: e.value)).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  return ranked;
}
