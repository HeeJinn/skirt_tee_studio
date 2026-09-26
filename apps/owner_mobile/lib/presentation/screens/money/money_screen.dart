import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/calculations/money_calculations.dart';
import 'package:shop_core/calculations/report_calculations.dart';
import 'package:shop_core/core/format/money_format.dart';

import '../../../core/theme/cupertino_theme.dart';
import '../../viewmodels/money_view_model.dart';
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
                _PaybackDetails(vm: vm),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: CupertinoSlidingSegmentedControl<ReportRange>(
                    groupValue: vm.range,
                    onValueChanged: (r) {
                      if (r != null) vm.selectRange(r);
                    },
                    children: {for (final r in MoneyViewModel.ranges) r: Text(_rangeLabels[r]!)},
                  ),
                ),
                _Profit(statement: vm.statement, since: vm.periodStart),
                if (vm.months.isNotEmpty) _MonthlyChart(months: vm.months),
                CupertinoListSection.insetGrouped(
                  children: [
                    CupertinoListTile(
                      title: const Text('Money log'),
                      additionalInfo: Text('${vm.log.length}'),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(builder: (_) => const MoneyLogScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
        ],
      ),
    );
  }
}

class _PaybackCard extends StatelessWidget {
  const _PaybackCard({required this.payback});
  final Payback payback;

  @override
  Widget build(BuildContext context) {
    final tokens = shopTokens(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final share = payback.recoveredShare;
    final done = share != null && share >= 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Investment paid back', style: TextStyle(fontSize: 13, color: secondary)),
          const SizedBox(height: 4),
          Text(
            share == null ? '—' : '${(share * 100).round()}%',
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: CupertinoColors.systemGrey5.resolveFrom(context)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (share ?? 0).clamp(0, 1).toDouble(),
                    child: ColoredBox(color: tokens.success),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            share == null
                ? 'Nothing put in yet. Money the owners put in shows up here once recorded on the shop computer.'
                : done
                    ? 'Fully paid back — ${pesoWhole.format(payback.earned)} earned on ${pesoWhole.format(payback.invested)} put in.'
                    : '${signedPeso(payback.earned, whole: true)} earned of ${pesoWhole.format(payback.invested)} put in · '
                        '${pesoWhole.format(payback.remainingToRecover)} to go',
            style: TextStyle(fontSize: 13, color: secondary),
          ),
        ],
      ),
    );
  }
}

class _PaybackDetails extends StatelessWidget {
  const _PaybackDetails({required this.vm});
  final MoneyViewModel vm;

  @override
  Widget build(BuildContext context) {
    final p = vm.paybackStatus;
    final byPerson = p.investedByPerson.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final started = vm.booksStartedAt;
    return CupertinoListSection.insetGrouped(
      footer: Text(
        started == null
            ? "The shop computer's books haven't reached this phone yet."
            : 'Counting since the books started on ${DateFormat('MMM d, y').format(started)}.',
      ),
      children: [
        for (final MapEntry(key: person, value: amount) in byPerson)
          CupertinoListTile(
            title: Text(person == Payback.bothOwners ? 'Put in' : 'Put in by $person'),
            additionalInfo: Text(peso.format(amount)),
          ),
        CupertinoListTile(title: const Text('Taken home'), additionalInfo: Text(peso.format(p.takenHome))),
        CupertinoListTile(title: const Text('Still in the shop'), additionalInfo: Text(signedPeso(p.stillInShop))),
        CupertinoListTile(title: const Text('Stock on the rack, at cost'), additionalInfo: Text(peso.format(vm.stockValue))),
      ],
    );
  }
}

/// The period's profit laid out like the shop computer's breakdown: sales,
/// less what the pieces cost, less expenses and losses.
class _Profit extends StatelessWidget {
  const _Profit({required this.statement, required this.since});
  final ProfitStatement statement;
  final DateTime since;

  @override
  Widget build(BuildContext context) {
    final s = statement;
    final tokens = shopTokens(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final net = s.netProfit;
    const strong = TextStyle(fontWeight: FontWeight.w600);

    Widget indented(String label, String value) => CupertinoListTile(
          title: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(label, style: TextStyle(color: secondary)),
          ),
          additionalInfo: Text(value),
        );

    return CupertinoListSection.insetGrouped(
      header: Text('PROFIT FROM ${DateFormat('MMM d').format(since).toUpperCase()}'),
      footer: s.unknownCostRevenue > 0
          ? Text(
              '${peso.format(s.unknownCostRevenue)} of these sales were stock from before the books started, '
              'counted at ₱0 cost, so profit reads high until that stock sells through.',
            )
          : null,
      children: [
        CupertinoListTile(title: const Text('Sales'), additionalInfo: Text(peso.format(s.revenue))),
        CupertinoListTile(title: const Text('Cost of items sold'), additionalInfo: Text(minusPeso(s.costOfGoodsSold))),
        CupertinoListTile(
          title: const Text('Gross profit', style: strong),
          subtitle: s.revenue == 0 ? null : Text('${(s.grossMargin * 100).round()}% of sales'),
          additionalInfo: Text(signedPeso(s.grossProfit), style: strong),
        ),
        if (s.expensesByCategory.isEmpty) indented('Expenses', '—'),
        for (final MapEntry(key: category, value: amount) in s.expensesByCategory.entries)
          indented(category.label, minusPeso(amount)),
        if (s.stockLosses != 0)
          indented('Stock losses', s.stockLosses > 0 ? minusPeso(s.stockLosses) : '+${peso.format(-s.stockLosses)}'),
        CupertinoListTile(
          title: Text(net < 0 ? 'Net loss' : 'Net profit', style: strong),
          additionalInfo: Text(
            signedPeso(net),
            style: strong.copyWith(color: net < 0 ? tokens.danger : tokens.success),
          ),
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
    final tokens = shopTokens(context);
    final label = CupertinoColors.secondaryLabel.resolveFrom(context);
    final top = months.fold<double>(0, (m, x) => [m, x.sales, x.costs].reduce((a, b) => a > b ? a : b));
    final ceiling = top == 0 ? 1.0 : niceCeiling(top);

    Widget key(Color color, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(fontSize: 12, color: label)),
          ],
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 6),
            child: Text('SALES AND COSTS BY MONTH', style: TextStyle(fontSize: 13, color: label)),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            decoration: BoxDecoration(
              color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Wrap(spacing: 16, children: [key(tokens.chartSales, 'Sales'), key(tokens.chartCosts, 'Costs')]),
                const SizedBox(height: 8),
                SizedBox(
                  height: 170,
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
                            getTitlesWidget: (value, meta) => Text(axisPeso(value), style: TextStyle(fontSize: 11, color: label)),
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
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(DateFormat('MMM').format(months[i].month), style: TextStyle(fontSize: 11, color: label)),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => CupertinoColors.label.resolveFrom(context),
                          tooltipBorderRadius: BorderRadius.circular(8),
                          getTooltipItem: (group, _, _, _) {
                            final m = months[group.x];
                            final style = TextStyle(fontSize: 12, color: CupertinoColors.systemBackground.resolveFrom(context));
                            return BarTooltipItem(
                              '${DateFormat('MMMM y').format(m.month)}\n',
                              style,
                              textAlign: TextAlign.left,
                              children: [
                                TextSpan(text: 'Sales ${pesoWhole.format(m.sales)}\n'),
                                TextSpan(text: 'Costs ${pesoWhole.format(m.costs)}\n'),
                                TextSpan(
                                  text: '${m.profit < 0 ? 'Loss' : 'Profit'} ${signedPeso(m.profit, whole: true)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
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
                            barsSpace: 3,
                            barRods: [
                              for (final (value, color) in [(months[i].sales, tokens.chartSales), (months[i].costs, tokens.chartCosts)])
                                BarChartRodData(
                                  toY: value,
                                  color: color,
                                  width: 10,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
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
      ),
    );
  }
}
