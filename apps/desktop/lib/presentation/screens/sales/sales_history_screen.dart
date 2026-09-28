import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import '../../../core/utils/csv.dart';
import '../../../core/utils/csv_export.dart';
import '../../../core/utils/date_stamp.dart';
import 'package:shop_core/domain/entities/sale.dart';
import '../../viewmodels/inventory_view_model.dart';
import '../../viewmodels/sales_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/ios_alert.dart';
import '../../widgets/list_surface.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/stat_tile.dart';
import 'package:shop_core/calculations/report_calculations.dart';
import 'package:shop_core/calculations/sales_grouping.dart';

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
final _time = DateFormat('h:mm a');

/// Core function: see past transactions and correct a mistaken sale.
/// One filter row (search, payment, date range) scopes the stats, the list,
/// and the export. Defaults to Today, so the stats read as the day's drawer
/// reconciliation.
class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  ReportRange _range = ReportRange.today;
  PaymentMethod? _method;
  String _search = '';

  Future<void> _exportCsv(List<Sale> sales) async {
    // One row per line item (not per sale) — that's the shape an
    // accounting/spreadsheet reconciliation actually wants.
    final csv = buildCsv(
      ['Date', 'Sale ID', 'Payment', 'Item', 'Qty', 'Unit Price', 'Subtotal'],
      [
        for (final sale in sales)
          for (final line in sale.lineItems)
            [
              sale.dateTime.toIso8601String(),
              sale.id,
              sale.paymentMethod?.label,
              line.itemName,
              line.qty,
              line.unitPrice,
              line.subtotal,
            ],
      ],
    );
    await exportCsv(context, suggestedName: 'sales_${_range.name}_${dateStamp(DateTime.now())}.csv', csv: csv);
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<SalesViewModel>().sales;
    final now = DateTime.now();
    final query = _search.trim().toLowerCase();
    final sales = filterSalesByRange(all, _range, now)
        .where((s) => _method == null || s.paymentMethod == _method)
        .where((s) => query.isEmpty || s.lineItems.any((l) => l.itemName.toLowerCase().contains(query)))
        .toList();
    final days = groupSalesByDay(sales);
    final summary = summarize(sales);
    // Legacy "Cashless" only appears as a filter option if such sales exist.
    final methods = {...PaymentMethod.selectable, ...all.map((s) => s.paymentMethod).whereType<PaymentMethod>()}
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Sales',
            subtitle: '${_range.description} · ${summary.saleCount} sale${summary.saleCount == 1 ? '' : 's'}',
            actions: [
              OutlinedButton.icon(
                onPressed: sales.isEmpty ? null : () => _exportCsv(sales),
                icon: const Icon(CupertinoIcons.square_arrow_down, size: 18),
                label: const Text('Export'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Flexible(child: SearchField(hint: 'Search items sold', onChanged: (v) => setState(() => _search = v), width: 240)),
              const SizedBox(width: AppSpacing.md),
              DropdownMenu<PaymentMethod?>(
                width: 204,
                initialSelection: _method,
                requestFocusOnTap: false,
                leadingIcon: const Icon(CupertinoIcons.line_horizontal_3_decrease, size: 18),
                onSelected: (m) => setState(() => _method = m),
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: null, label: 'All payments'),
                  for (final m in methods) DropdownMenuEntry(value: m, label: m.label),
                ],
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: SegmentedStrip<ReportRange>(
                  options: [for (final r in ReportRange.values) (r, r.label)],
                  selected: _range,
                  onSelected: (r) => setState(() => _range = r),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StatRow(
            tiles: [
              StatTile(
                label: 'Revenue',
                value: _peso.format(summary.revenue),
                caption: '${_peso.format(summary.cashRevenue)} cash · '
                    '${_peso.format(summary.cashlessRevenue)} cashless',
              ),
              StatTile(
                label: 'Sales',
                value: '${summary.saleCount}',
                caption: 'Avg. ${_peso.format(summary.averageSale)}',
              ),
              StatTile(label: 'Items sold', value: '${summary.itemsSold}'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: days.isEmpty
                ? EmptyState(
                    icon: CupertinoIcons.doc_text,
                    message: all.isEmpty ? 'No sales yet' : 'No sales match these filters',
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      for (final day in days) ...[
                        SectionLabel(
                          dayLabel(day.day, now),
                          trailing:
                              '${_peso.format(day.total)}  ·  ${day.sales.length} sale${day.sales.length == 1 ? '' : 's'}',
                        ),
                        ListSurface(
                          children: [for (final sale in day.sales) _SaleRow(key: ValueKey(sale.id), sale: sale)],
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SaleRow extends StatefulWidget {
  const _SaleRow({super.key, required this.sale});
  final Sale sale;

  @override
  State<_SaleRow> createState() => _SaleRowState();
}

class _SaleRowState extends State<_SaleRow> {
  bool _expanded = false;

  Future<void> _confirmVoid() async {
    final count = widget.sale.totalItemsSold;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => IosAlert(
        title: const Text('Void Sale'),
        content: Text(
          'Remove this ${_peso.format(widget.sale.totalAmount)} sale and return '
          '$count item${count == 1 ? '' : 's'} to stock? This can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dialogContext.tokens.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Void Sale'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<SalesViewModel>().voidSale(widget.sale);
    if (!mounted) return;
    await Future.wait([
      context.read<InventoryViewModel>().load(),
      context.read<SessionViewModel>().log(
            'Voided sale ${_peso.format(widget.sale.totalAmount)} from '
            '${DateFormat('MMM d, h:mm a').format(widget.sale.dateTime)} · ${saleSummary(widget.sale)}',
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final tokens = context.tokens;
    final tabular = context.text.bodyMedium?.copyWith(fontFeatures: kTabularFigures);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Text(_time.format(sale.dateTime), style: tabular?.copyWith(color: tokens.mutedText)),
                ),
                Expanded(
                  child: Text(saleSummary(sale), style: context.text.bodyMedium, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: 80,
                  child: Text(sale.paymentMethod?.label ?? '—', style: context.text.bodySmall),
                ),
                SizedBox(
                  width: 96,
                  child: Text(
                    _peso.format(sale.totalAmount),
                    textAlign: TextAlign.right,
                    style: tabular?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(CupertinoIcons.chevron_down, size: 20, color: tokens.mutedText),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox(width: double.infinity)
              : Container(
                  color: tokens.sunken,
                  padding: const EdgeInsets.fromLTRB(76 + AppSpacing.lg, AppSpacing.md, AppSpacing.lg + 32, AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final line in sale.lineItems)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(child: Text(line.itemName, style: context.text.bodySmall)),
                              Text(
                                '${line.qty} × ${_peso.format(line.unitPrice)}',
                                style: context.text.bodySmall?.copyWith(fontFeatures: kTabularFigures),
                              ),
                              SizedBox(
                                width: 96,
                                child: Text(
                                  _peso.format(line.subtotal),
                                  textAlign: TextAlign.right,
                                  style: context.text.bodySmall?.copyWith(fontFeatures: kTabularFigures),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (sale.amountTendered != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            const Spacer(),
                            Text(
                              'Received ${_peso.format(sale.amountTendered)}  ·  '
                              'Change ${_peso.format(sale.changeGiven)}',
                              style: context.text.bodySmall?.copyWith(
                                color: tokens.mutedText,
                                fontFeatures: kTabularFigures,
                              ),
                            ),
                          ],
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _confirmVoid,
                          style: TextButton.styleFrom(foregroundColor: tokens.danger),
                          icon: const Icon(CupertinoIcons.arrow_uturn_left, size: 16),
                          label: const Text('Void sale'),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
