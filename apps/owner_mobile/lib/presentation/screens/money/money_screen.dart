import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/calculations/money_calculations.dart';
import 'package:shop_core/calculations/report_calculations.dart';
import 'package:shop_core/core/format/money_format.dart';

import '../../../core/theme/shop_ui.dart';
import '../../viewmodels/money_view_model.dart';
import '../../widgets/ui/section.dart';
import 'money_log_screen.dart';

/// How much of the owners' investment the shop has earned back, what it
/// made in a period, and sales against costs month by month.
class MoneyScreen extends StatelessWidget {
  const MoneyScreen({super.key});

  static const _rangeLabels = {
    ReportRange.last7Days: '7 days',
    ReportRange.last30Days: '30 days',
    ReportRange.allTime: 'Since start',
  };

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MoneyViewModel>();

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('Money')),
          CupertinoSliverRefreshControl(onRefresh: context.read<MoneyViewModel>().load),
          if (!vm.loaded)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CupertinoActivityIndicator()))
          else
            SliverList.list(
              children: [
                _PaybackCard(payback: vm.paybackStatus),
                _WhereItIs(vm: vm),
                SectionHeader('Profit', trailing: 'from ${DateFormat('MMM d').format(vm.periodStart)}'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: CupertinoSlidingSegmentedControl<ReportRange>(
                    groupValue: vm.range,
                    onValueChanged: (r) {
                      if (r != null) vm.selectRange(r);
                    },
                    children: {for (final r in MoneyViewModel.ranges) r: Text(_rangeLabels[r]!)},
                  ),
                ),
                AnimatedSwitcher(
                  duration: Motion.medium,
                  switchInCurve: Motion.curve,
                  child: _Profit(key: ValueKey(vm.range), statement: vm.statement),
                ),
                if (vm.months.isNotEmpty) _MonthlyChart(months: vm.months),
                GroupedSection(
                  children: [
                    ValueRow(
                      leading: const Icon(CupertinoIcons.book, size: 20),
                      label: 'Money log',
                      value: '${vm.log.length}',
                      tone: ValueTone.muted,
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(builder: (_) => const MoneyLogScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xxl),
              ],
            ),
        ],
      ),
    );
  }
}

/// How much of what the owners put in has come back — on the shop's mist.
class _PaybackCard extends StatelessWidget {
  const _PaybackCard({required this.payback});
  final Payback payback;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final share = payback.recoveredShare;
    final done = share != null && share >= 1;
    final muted = colors.ink.withValues(alpha: 0.65);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Space.gutter),
      padding: const EdgeInsets.all(Space.lg + Space.xs),
      decoration: BoxDecoration(color: colors.hero, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Investment paid back', style: ShopType.label(context).copyWith(color: muted)),
          const SizedBox(height: Space.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(share == null ? '—' : '${(share * 100).round()}%', style: ShopType.hero(context)),
              const SizedBox(width: Space.md),
              if (share != null)
                Expanded(
                  child: Text(
                    done ? 'Paid back' : '${pesoWhole.format(payback.remainingToRecover)} to go',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ShopType.subhead(context).copyWith(color: colors.ink, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          // The bar grows into place when the figures load.
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: SizedBox(
              height: 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: colors.ink.withValues(alpha: 0.1)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: (share ?? 0).clamp(0, 1).toDouble()),
                    duration: const Duration(milliseconds: 600),
                    curve: Motion.curve,
                    builder: (_, value, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value,
                      child: ColoredBox(color: colors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            share == null
                ? 'Nothing put in yet. Money the owners put in shows up here once recorded on the shop computer.'
                : '${signedPeso(payback.earned, whole: true)} earned back of ${pesoWhole.format(payback.invested)} put in',
            style: ShopType.footnote(context).copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _WhereItIs extends StatelessWidget {
  const _WhereItIs({required this.vm});
  final MoneyViewModel vm;

  @override
  Widget build(BuildContext context) {
    final p = vm.paybackStatus;
    final byPerson = p.investedByPerson.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final started = vm.booksStartedAt;
    return GroupedSection(
      title: 'Where the money is',
      footer: started == null
          ? "The shop computer's books haven't reached this phone yet."
          : 'Counting since the books started on ${DateFormat('MMMM d, y').format(started)}.',
      children: [
        for (final MapEntry(key: person, value: amount) in byPerson)
          ValueRow(
            label: person == Payback.bothOwners ? 'Put in' : 'Put in by $person',
            value: peso.format(amount),
          ),
        ValueRow(label: 'Taken home', value: peso.format(p.takenHome)),
        ValueRow(label: 'Still in the shop', value: signedPeso(p.stillInShop), tone: ValueTone.strong),
        ValueRow(label: 'Stock on the rack, at cost', value: peso.format(vm.stockValue), indent: true),
      ],
    );
  }
}

/// The period's profit laid out like the shop computer's breakdown: sales,
/// less what the pieces cost, less expenses and losses.
class _Profit extends StatelessWidget {
  const _Profit({super.key, required this.statement});
  final ProfitStatement statement;

  @override
  Widget build(BuildContext context) {
    final s = statement;
    final net = s.netProfit;
    return GroupedSection(
      gap: Space.md,
      footer: s.unknownCostRevenue > 0
          ? '${peso.format(s.unknownCostRevenue)} of these sales were stock from before the books started, '
              'counted at ₱0 cost, so profit reads high until that stock sells through.'
          : null,
      children: [
        ValueRow(label: 'Sales', value: peso.format(s.revenue)),
        ValueRow(label: 'Cost of items sold', value: minusPeso(s.costOfGoodsSold), indent: true),
        ValueRow(
          label: 'Gross profit',
          detail: s.revenue == 0 ? null : '${(s.grossMargin * 100).round()}% of sales',
          value: signedPeso(s.grossProfit),
          tone: ValueTone.strong,
        ),
        if (s.expensesByCategory.isEmpty) const ValueRow(label: 'Expenses', value: '—', indent: true),
        for (final MapEntry(key: category, value: amount) in s.expensesByCategory.entries)
          ValueRow(label: category.label, value: minusPeso(amount), indent: true),
        if (s.stockLosses != 0)
          ValueRow(
            label: 'Stock losses',
            value: s.stockLosses > 0 ? minusPeso(s.stockLosses) : '+${peso.format(-s.stockLosses)}',
            indent: true,
          ),
        ValueRow(
          label: net < 0 ? 'Net loss' : 'Net profit',
          value: signedPeso(net),
          tone: net < 0 ? ValueTone.negative : ValueTone.positive,
        ),
      ],
    );
  }
}

/// Sales against everything that came off profit, for each month since the
/// books started (up to six).
class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.months});
  final List<MonthlyProfit> months;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final tokens = colors.tokens;
    final label = ShopType.caption(context);
    final top = months.fold<double>(0, (m, x) => [m, x.sales, x.costs].reduce((a, b) => a > b ? a : b));
    final ceiling = top == 0 ? 1.0 : niceCeiling(top);

    Widget key(Color color, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: Space.xs + 2),
            Text(text, style: label),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Sales and costs'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: Space.gutter),
          padding: const EdgeInsets.fromLTRB(Space.sm, Space.lg, Space.lg, Space.md),
          decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(Radii.card)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: Space.sm),
                child: Wrap(spacing: Space.lg, children: [key(tokens.chartSales, 'Sales'), key(tokens.chartCosts, 'Costs')]),
              ),
              const SizedBox(height: Space.md),
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    minY: 0,
                    maxY: ceiling,
                    alignment: BarChartAlignment.spaceAround,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: ceiling / 2,
                      getDrawingHorizontalLine: (_) => FlLine(color: tokens.chartGrid, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          interval: ceiling / 2,
                          getTitlesWidget: (value, meta) => Text(axisPeso(value), style: label),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= months.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: Space.xs + 2),
                              child: Text(DateFormat('MMM').format(months[i].month), style: label),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => colors.ink,
                        tooltipBorderRadius: BorderRadius.circular(Radii.badge),
                        getTooltipItem: (group, _, _, _) {
                          final m = months[group.x];
                          return BarTooltipItem(
                            '${DateFormat('MMMM y').format(m.month)}\n',
                            label.copyWith(color: colors.card),
                            textAlign: TextAlign.left,
                            children: [
                              TextSpan(text: 'Sales ${pesoWhole.format(m.sales)}\n'),
                              TextSpan(text: 'Costs ${pesoWhole.format(m.costs)}\n'),
                              TextSpan(
                                text: '${m.profit < 0 ? 'Loss' : 'Profit'} ${signedPeso(m.profit, whole: true)}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < months.length; i++)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 4,
                          barRods: [
                            for (final (value, color) in [(months[i].sales, tokens.chartSales), (months[i].costs, tokens.chartCosts)])
                              BarChartRodData(
                                toY: value,
                                color: color,
                                width: 14,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
