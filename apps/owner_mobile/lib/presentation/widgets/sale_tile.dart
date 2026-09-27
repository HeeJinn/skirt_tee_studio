import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:shop_core/calculations/sales_grouping.dart';
import 'package:shop_core/core/format/money_format.dart';
import 'package:shop_core/domain/entities/sale.dart';

import '../../core/theme/shop_ui.dart';
import 'ui/badges.dart';
import 'ui/section.dart';

/// One sale in a list: how it was paid (at a glance, as Wallet marks each
/// transaction), what was bought, when, and the total. Worded like the shop
/// computer's Sales screen (shared [saleSummary]).
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
    return ValueRow(
      leading: PaymentBadge(method: sale.paymentMethod),
      label: summary.isEmpty ? 'Sale' : summary,
      detail: how == null ? when : '$when · $how',
      value: peso.format(sale.totalAmount),
      labelLines: 1,
      onTap: onTap,
    );
  }
}

/// How a sale was paid, as a round badge: "₱" for cash, a phone for the
/// e-wallets, a card for cards.
class PaymentBadge extends StatelessWidget {
  const PaymentBadge({super.key, required this.method});

  /// Null for sales from before payment methods were recorded.
  final PaymentMethod? method;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final tokens = colors.tokens;
    return switch (method) {
      PaymentMethod.cash => IconBadge.glyph('₱', color: tokens.chartSales),
      PaymentMethod.gcash || PaymentMethod.maya || PaymentMethod.cashless =>
        IconBadge(icon: CupertinoIcons.device_phone_portrait, color: colors.accent),
      PaymentMethod.card => IconBadge(icon: CupertinoIcons.creditcard_fill, color: tokens.chartCosts),
      null => IconBadge(icon: CupertinoIcons.bag_fill, color: colors.secondaryInk),
    };
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
