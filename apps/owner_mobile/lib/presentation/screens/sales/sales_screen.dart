import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/calculations/sales_grouping.dart';
import 'package:shop_core/core/format/money_format.dart';

import '../../../core/period.dart';
import '../../../core/theme/shop_ui.dart';
import '../../viewmodels/sales_view_model.dart';
import '../../widgets/sale_tile.dart';
import '../../widgets/ui/empty_state.dart';
import '../../widgets/ui/line_art.dart';
import '../../widgets/ui/period_bar.dart';
import '../../widgets/ui/section.dart';
import 'sale_detail_screen.dart';

/// Every sale on a chosen day or in a chosen month, grouped by day with
/// each day's total.
class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SalesViewModel>();
    final summary = vm.summary;
    final days = vm.days;
    final period = vm.period;

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('Sales'), border: null),
          CupertinoSliverRefreshControl(onRefresh: context.read<SalesViewModel>().load),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PeriodBar(
                    period: period,
                    now: vm.now,
                    kinds: SalesViewModel.kinds,
                    earliest: vm.earliest,
                    onChanged: vm.selectPeriod,
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
                      key: ValueKey((period, summary.revenue, summary.saleCount)),
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
          else if (days.isEmpty && period.kind == PeriodKind.day && period.isCurrent(vm.now))
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                drawing: LineArtDrawing.bag,
                message: 'No sales yet today. They show up here as the shop computer rings them up.',
              ),
            )
          else if (days.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter + Space.xs, Space.xl, Space.gutter + Space.xs, 0),
                child: Text('No sales ${period.phrase(vm.now)}.', style: ShopType.subhead(context)),
              ),
            )
          else
            SliverList.builder(
              itemCount: days.length,
              itemBuilder: (context, i) {
                final day = days[i];
                // A single day needs no heading: the date and its total are
                // already just above.
                final byDay = period.kind == PeriodKind.month;
                return GroupedSection(
                  title: byDay ? dayLabel(day.day, vm.now) : null,
                  trailing: byDay ? pesoWhole.format(day.total) : null,
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
