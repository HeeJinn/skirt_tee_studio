import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/calculations/report_calculations.dart';
import 'package:shop_core/calculations/sales_grouping.dart';
import 'package:shop_core/core/format/money_format.dart';

import '../../../core/theme/shop_ui.dart';
import '../../viewmodels/sales_view_model.dart';
import '../../widgets/sale_tile.dart';
import '../../widgets/ui/section.dart';
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

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('Sales')),
          CupertinoSliverRefreshControl(onRefresh: context.read<SalesViewModel>().load),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 0),
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
                  const SizedBox(height: Space.lg),
                  // The period's total, left-aligned and large; it changes
                  // with a quick cross-fade as the period switches.
                  AnimatedSwitcher(
                    duration: Motion.medium,
                    switchInCurve: Motion.curve,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topLeft,
                      children: [...previous, ?current],
                    ),
                    child: Padding(
                      key: ValueKey((vm.range, summary.revenue, summary.saleCount)),
                      padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pesoWhole.format(summary.revenue), style: ShopType.hero(context)),
                          const SizedBox(height: Space.xs),
                          Text(
                            summary.saleCount == 0
                                ? 'No sales'
                                : '${summary.saleCount} ${summary.saleCount == 1 ? 'sale' : 'sales'} · '
                                    '${summary.itemsSold} ${summary.itemsSold == 1 ? 'piece' : 'pieces'} · '
                                    'average ${pesoWhole.format(summary.averageSale)}',
                            style: ShopType.subhead(context),
                          ),
                        ],
                      ),
                    ),
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter + Space.xs, Space.xl, Space.gutter + Space.xs, 0),
                child: Text(
                  vm.range == ReportRange.today
                      ? 'No sales yet today. They show up here as the shop computer rings them up.'
                      : 'No sales in this period.',
                  style: ShopType.subhead(context),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: days.length,
              itemBuilder: (context, i) {
                final day = days[i];
                return GroupedSection(
                  title: dayLabel(day.day, vm.now),
                  trailing: pesoWhole.format(day.total),
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
          const SliverToBoxAdapter(child: BottomInset()),
        ],
      ),
    );
  }
}
