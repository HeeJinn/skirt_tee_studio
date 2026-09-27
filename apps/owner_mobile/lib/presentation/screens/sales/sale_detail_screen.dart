import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/core/format/money_format.dart';
import 'package:shop_core/domain/entities/sale.dart';

import '../../../core/theme/shop_ui.dart';
import '../../viewmodels/sales_view_model.dart';
import '../../widgets/ui/badges.dart';
import '../../widgets/ui/glass.dart';
import '../../widgets/ui/section.dart';

/// One sale: what was bought, how it was paid, and what the shop made on it.
/// Looked up by id, so a sale voided on the shop computer while this page is
/// open says so instead of showing stale figures.
class SaleDetailScreen extends StatelessWidget {
  const SaleDetailScreen({super.key, required this.saleId, this.backLabel = 'Sales'});

  final String saleId;

  /// The back button's label: the screen this was opened from.
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final sale = context.watch<SalesViewModel>().byId(saleId);

    return CupertinoPageScaffold(
      navigationBar: shopNavBar(title: 'Sale', backTo: backLabel),
      child: SafeArea(
        child: sale == null
            ? Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Text(
                  'This sale was voided on the shop computer, and its pieces went back into stock.',
                  style: ShopType.subhead(context),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(0, Space.lg, 0, Space.xxl),
                children: [
                  _Receipt(sale: sale),
                  if (sale.amountTendered != null) _Cash(sale: sale),
                  _Items(sale: sale),
                  _Profit(sale: sale),
                ],
              ),
      ),
    );
  }
}

/// The total, when, and how it was paid — on the shop's mist.
class _Receipt extends StatelessWidget {
  const _Receipt({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Space.gutter),
      padding: const EdgeInsets.all(Space.lg + Space.xs),
      decoration: BoxDecoration(color: colors.hero, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMMM d · h:mm a').format(sale.dateTime),
            style: ShopType.label(context).copyWith(color: colors.ink.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: Space.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(peso.format(sale.totalAmount), style: ShopType.hero(context)),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              Pill(
                // Sales from before the shop recorded payment methods.
                text: sale.paymentMethod?.label ?? 'Payment not recorded',
                color: colors.ink,
                // As the sales list marks it; cash carries no icon.
                icon: switch (sale.paymentMethod) {
                  PaymentMethod.gcash || PaymentMethod.maya || PaymentMethod.cashless =>
                    CupertinoIcons.device_phone_portrait,
                  PaymentMethod.card => CupertinoIcons.creditcard,
                  PaymentMethod.cash || null => null,
                },
              ),
              Pill(
                text: '${sale.totalItemsSold} ${sale.totalItemsSold == 1 ? 'piece' : 'pieces'}',
                color: colors.ink,
                icon: CupertinoIcons.bag,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cash extends StatelessWidget {
  const _Cash({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) => GroupedSection(
        title: 'Cash',
        children: [
          ValueRow(label: 'Received', value: peso.format(sale.amountTendered!)),
          if (sale.changeGiven != null) ValueRow(label: 'Change', value: peso.format(sale.changeGiven!)),
        ],
      );
}

class _Items extends StatelessWidget {
  const _Items({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) => GroupedSection(
        title: 'Items',
        children: [
          for (final line in sale.lineItems)
            ValueRow(
              label: line.itemName,
              detail: line.unitCost == null
                  ? '${line.qty} × ${peso.format(line.unitPrice)} · cost not recorded'
                  : '${line.qty} × ${peso.format(line.unitPrice)} · cost ${peso.format(line.unitCost!)} each',
              value: peso.format(line.subtotal),
            ),
        ],
      );
}

class _Profit extends StatelessWidget {
  const _Profit({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final cost = sale.lineItems.fold<double>(0, (sum, l) => sum + l.costOfGoods);
    final profit = sale.totalAmount - cost;
    final uncosted = sale.lineItems.any((l) => l.unitCost == null);
    return GroupedSection(
      title: 'What the shop made',
      footer: uncosted ? 'Pieces with no recorded cost count as ₱0 cost, so this profit reads high.' : null,
      children: [
        ValueRow(label: 'Sale', value: peso.format(sale.totalAmount)),
        ValueRow(label: 'Cost of pieces', value: minusPeso(cost), indent: true),
        ValueRow(
          label: 'Gross profit',
          detail: sale.totalAmount == 0 ? null : '${(profit / sale.totalAmount * 100).round()}% of the sale',
          value: signedPeso(profit),
          tone: profit < 0 ? ValueTone.negative : ValueTone.positive,
        ),
      ],
    );
  }
}
