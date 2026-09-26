import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:shop_core/calculations/sales_grouping.dart';
import 'package:shop_core/core/format/money_format.dart';
import 'package:shop_core/domain/entities/sale.dart';

/// One sale in a list: what was bought, when and how it was paid, and the
/// total. Worded like the shop computer's Sales screen (shared
/// [saleSummary]).
class SaleTile extends StatelessWidget {
  const SaleTile({super.key, required this.sale, required this.when, this.onTap});

  final Sale sale;

  /// The time, or a day for sales not from today.
  final String when;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final how = sale.paymentMethod?.label;
    final summary = saleSummary(sale);
    return CupertinoListTile(
      title: Text(summary.isEmpty ? 'Sale' : summary, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(how == null ? when : '$when · $how'),
      additionalInfo: Text(peso.format(sale.totalAmount)),
      trailing: onTap == null ? null : const CupertinoListTileChevron(),
      onTap: onTap,
    );
  }
}

/// "2:41 PM" for a sale on [day]; "Yesterday" or "Sep 24" otherwise.
String saleWhen(Sale sale, DateTime day) {
  final d = sale.dateTime;
  final saleDay = DateTime(d.year, d.month, d.day);
  if (saleDay == day) return DateFormat.jm().format(d);
  if (saleDay == day.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat('MMM d').format(d);
}
