import 'package:intl/intl.dart';

import '../../../domain/entities/sale.dart';

class SalesDay {
  const SalesDay({required this.day, required this.sales});

  final DateTime day;

  /// Newest first.
  final List<Sale> sales;

  double get total => sales.fold(0, (sum, s) => sum + s.totalAmount);
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Calendar-day groups, newest day first.
List<SalesDay> groupSalesByDay(List<Sale> sales) {
  final byDay = <DateTime, List<Sale>>{};
  for (final sale in sales) {
    byDay.putIfAbsent(_dayOf(sale.dateTime), () => []).add(sale);
  }
  final days = byDay.entries
      .map((e) => SalesDay(day: e.key, sales: e.value..sort((a, b) => b.dateTime.compareTo(a.dateTime))))
      .toList()
    ..sort((a, b) => b.day.compareTo(a.day));
  return days;
}

/// "Today", "Yesterday", or "Mon, Sep 20".
String dayLabel(DateTime day, DateTime now) {
  final diff = _dayOf(now).difference(_dayOf(day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEE, MMM d').format(day);
}

/// "Classic White Tee ×2, Floral Wrap Blouse" — what was bought, at a glance.
String saleSummary(Sale sale) =>
    sale.lineItems.map((l) => l.qty > 1 ? '${l.itemName} ×${l.qty}' : l.itemName).join(', ');
