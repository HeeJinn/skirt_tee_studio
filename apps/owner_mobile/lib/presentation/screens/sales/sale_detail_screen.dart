import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/core/format/money_format.dart';
import 'package:shop_core/domain/entities/sale.dart';

import '../../../core/theme/cupertino_theme.dart';
import '../../viewmodels/sales_view_model.dart';

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
      navigationBar: CupertinoNavigationBar(middle: const Text('Sale'), previousPageTitle: backLabel),
      child: SafeArea(
        child: sale == null
            ? const _Voided()
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _Total(sale: sale),
                  _Payment(sale: sale),
                  _Items(sale: sale),
                  _Profit(sale: sale),
                ],
              ),
      ),
    );
  }
}

class _Voided extends StatelessWidget {
  const _Voided();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            'This sale was voided on the shop computer, and its pieces went back into stock.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
          ),
        ),
      );
}

class _Total extends StatelessWidget {
  const _Total({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(peso.format(sale.totalAmount), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEE, MMM d, y · h:mm a').format(sale.dateTime),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
            ),
          ],
        ),
      );
}

class _Payment extends StatelessWidget {
  const _Payment({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final tendered = sale.amountTendered;
    final change = sale.changeGiven;
    return CupertinoListSection.insetGrouped(
      header: const Text('PAYMENT'),
      children: [
        CupertinoListTile(
          title: const Text('Paid with'),
          // Sales from before the shop recorded payment methods.
          additionalInfo: Text(sale.paymentMethod?.label ?? 'Not recorded'),
        ),
        if (tendered != null) CupertinoListTile(title: const Text('Cash received'), additionalInfo: Text(peso.format(tendered))),
        if (change != null) CupertinoListTile(title: const Text('Change'), additionalInfo: Text(peso.format(change))),
      ],
    );
  }
}

class _Items extends StatelessWidget {
  const _Items({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      header: Text('${sale.totalItemsSold} ${sale.totalItemsSold == 1 ? 'PIECE' : 'PIECES'}'),
      children: [
        for (final line in sale.lineItems)
          CupertinoListTile(
            title: Text(line.itemName, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              line.unitCost == null
                  ? '${line.qty} × ${peso.format(line.unitPrice)} · cost not recorded'
                  : '${line.qty} × ${peso.format(line.unitPrice)} · cost ${peso.format(line.unitCost!)} each',
            ),
            additionalInfo: Text(peso.format(line.subtotal)),
          ),
      ],
    );
  }
}

class _Profit extends StatelessWidget {
  const _Profit({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final tokens = shopTokens(context);
    final cost = sale.lineItems.fold<double>(0, (sum, l) => sum + l.costOfGoods);
    final profit = sale.totalAmount - cost;
    final uncosted = sale.lineItems.any((l) => l.unitCost == null);
    return CupertinoListSection.insetGrouped(
      header: const Text('WHAT THE SHOP MADE'),
      footer: uncosted
          ? const Text('Pieces with no recorded cost count as ₱0 cost, so this profit reads high.')
          : null,
      children: [
        CupertinoListTile(title: const Text('Sale'), additionalInfo: Text(peso.format(sale.totalAmount))),
        CupertinoListTile(title: const Text('Cost of pieces'), additionalInfo: Text(minusPeso(cost))),
        CupertinoListTile(
          title: const Text('Gross profit', style: TextStyle(fontWeight: FontWeight.w600)),
          additionalInfo: Text(
            signedPeso(profit),
            style: TextStyle(fontWeight: FontWeight.w600, color: profit < 0 ? tokens.danger : tokens.success),
          ),
        ),
      ],
    );
  }
}
