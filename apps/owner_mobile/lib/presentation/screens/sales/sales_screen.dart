import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/calculations/report_calculations.dart';
import 'package:shop_core/calculations/sales_grouping.dart';
import 'package:shop_core/core/format/money_format.dart';

import '../../viewmodels/sales_view_model.dart';
import '../../widgets/sale_tile.dart';
import 'sale_detail_screen.dart';

/// Every sale in the chosen period, grouped by day with each day's total.
class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  static const _rangeLabels = {
    ReportRange.today: 'Today',
    ReportRange.last7Days: '7 days',
    ReportRange.last30Days: '30 days',
  };

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SalesViewModel>();
    final summary = vm.summary;
    final days = vm.days;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('Sales')),
          CupertinoSliverRefreshControl(onRefresh: context.read<SalesViewModel>().load),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CupertinoSlidingSegmentedControl<ReportRange>(
                    groupValue: vm.range,
                    onValueChanged: (range) {
                      if (range != null) vm.selectRange(range);
                    },
                    children: {
                      for (final range in SalesViewModel.ranges) range: Text(_rangeLabels[range]!),
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    summary.saleCount == 0
                        ? 'No sales'
                        : '${pesoWhole.format(summary.revenue)} · ${summary.saleCount} '
                            '${summary.saleCount == 1 ? 'sale' : 'sales'} · ${summary.itemsSold} '
                            '${summary.itemsSold == 1 ? 'piece' : 'pieces'}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: secondary),
                  ),
                ],
              ),
            ),
          ),
          if (!vm.loaded)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CupertinoActivityIndicator()))
          else if (days.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    vm.range == ReportRange.today
                        ? 'No sales yet today. They show up here as the shop computer rings them up.'
                        : 'No sales in this period.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: secondary),
                  ),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: days.length,
              itemBuilder: (context, i) {
                final day = days[i];
                return CupertinoListSection.insetGrouped(
                  header: Row(
                    children: [
                      Expanded(child: Text(dayLabel(day.day, vm.now).toUpperCase())),
                      Text(pesoWhole.format(day.total)),
                    ],
                  ),
                  children: [
                    for (final sale in day.sales)
                      SaleTile(
                        sale: sale,
                        when: saleWhen(sale, day.day),
                        onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute<void>(builder: (_) => SaleDetailScreen(saleId: sale.id)),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
