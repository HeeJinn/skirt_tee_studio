import 'package:shop_core/calculations/report_calculations.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/reservation.dart';
import 'package:shop_core/domain/entities/sale.dart';

/// Everything the Today tab shows, worked out in one place from the shop's
/// data. Built on the shared report calculations, so its totals match the
/// shop computer's Reports screen.
class TodaySnapshot {
  const TodaySnapshot({
    required this.day,
    required this.today,
    required this.todayGrossProfit,
    required this.sameDayLastWeek,
    required this.sameDayLastWeekGrossProfit,
    required this.lastSevenDays,
    required this.lowStock,
    required this.soldOut,
    required this.pickupsDueToday,
    required this.pickupsOverdue,
    required this.latestSales,
    required this.hasUncostedSales,
  });

  factory TodaySnapshot.from({
    required List<Sale> sales,
    required List<Item> items,
    required List<Reservation> reservations,
    required int lowStockThreshold,
    required DateTime now,
  }) {
    final day = DateTime(now.year, now.month, now.day);
    final lastWeek = day.subtract(const Duration(days: 7));
    final todaySales = _onDay(sales, day);
    final lastWeekSales = _onDay(sales, lastWeek);

    final pending = reservations.where((r) => r.status == ReservationStatus.pending);
    DateTime dateOf(DateTime d) => DateTime(d.year, d.month, d.day);

    final latest = [...sales]..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return TodaySnapshot(
      day: day,
      today: summarize(todaySales),
      todayGrossProfit: _grossProfit(todaySales),
      sameDayLastWeek: summarize(lastWeekSales),
      sameDayLastWeekGrossProfit: _grossProfit(lastWeekSales),
      lastSevenDays: dailyRevenue(sales, ReportRange.last7Days, now),
      // Sold-out items are counted on their own, not also as "low".
      lowStock: [for (final i in items) if (i.qtyOnHand > 0 && i.isLowStock(lowStockThreshold)) i],
      soldOut: [for (final i in items) if (i.qtyOnHand <= 0) i],
      pickupsDueToday: pending.where((r) => dateOf(r.pickupDate) == day).length,
      pickupsOverdue: pending.where((r) => dateOf(r.pickupDate).isBefore(day)).length,
      latestSales: latest.take(5).toList(),
      hasUncostedSales: todaySales.any((s) => s.lineItems.any((l) => l.unitCost == null)),
    );
  }

  final DateTime day;
  final ReportSummary today;
  final double todayGrossProfit;
  final ReportSummary sameDayLastWeek;
  final double sameDayLastWeekGrossProfit;

  /// Oldest first, ending today; days without sales are ₱0.
  final List<DailyRevenue> lastSevenDays;
  final List<Item> lowStock;
  final List<Item> soldOut;
  final int pickupsDueToday;
  final int pickupsOverdue;

  /// The five most recent sales, newest first — not only today's, so a quiet
  /// morning still shows how yesterday ended.
  final List<Sale> latestSales;

  /// Some of today's pieces have no recorded cost, so they count as ₱0
  /// cost and today's profit reads high.
  final bool hasUncostedSales;

  bool get needsAttention => lowStock.isNotEmpty || soldOut.isNotEmpty || pickupsDueToday > 0 || pickupsOverdue > 0;

  static List<Sale> _onDay(List<Sale> sales, DateTime day) => [
        for (final s in sales)
          if (s.dateTime.year == day.year && s.dateTime.month == day.month && s.dateTime.day == day.day) s,
      ];

  static double _grossProfit(List<Sale> sales) => sales.fold(
        0,
        (sum, s) => sum + s.lineItems.fold<double>(0, (lineSum, l) => lineSum + l.subtotal - l.costOfGoods),
      );
}

/// Change against a comparison figure, as a fraction (0.12 = +12%), or null
/// when there's nothing to compare against.
double? changeFrom(double previous, double current) => previous == 0 ? null : (current - previous) / previous;
