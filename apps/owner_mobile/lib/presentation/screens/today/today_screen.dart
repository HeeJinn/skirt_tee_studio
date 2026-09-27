import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/calculations/report_calculations.dart';
import 'package:shop_core/core/format/money_format.dart';
import 'package:shop_core/domain/entities/cloud_sync.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';

import '../../../core/theme/shop_ui.dart';
import '../../viewmodels/today_view_model.dart';
import '../../widgets/sale_tile.dart';
import '../../widgets/ui/badges.dart';
import '../../widgets/ui/section.dart';
import '../more/more_screen.dart';
import '../sales/sale_detail_screen.dart';
import 'today_snapshot.dart';

/// How the shop is doing today, compared with the same day last week, and
/// what needs the owners' attention.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<TodayViewModel>().snapshot;

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('Today'), border: null),
          CupertinoSliverRefreshControl(onRefresh: context.read<TodayViewModel>().load),
          if (snapshot == null)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CupertinoActivityIndicator()))
          else
            SliverList.list(
              children: [
                _Header(day: snapshot.day),
                _HeroCard(snapshot: snapshot),
                _StatRow(snapshot: snapshot),
                _Attention(snapshot: snapshot),
                _LatestSales(sales: snapshot.latestSales, day: snapshot.day),
                if (snapshot.hasUncostedSales)
                  const SectionFooter(
                    "Some of today's pieces have no recorded cost, so they count as ₱0 cost and profit reads high.",
                  ),
                const BottomInset(),
              ],
            ),
        ],
      ),
    );
  }
}

/// The date on the left, whether the phone has the shop computer's latest
/// on the right.
class _Header extends StatelessWidget {
  const _Header({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<CloudSyncViewModel>().state;
    final colors = ShopColors.of(context);
    final (color, icon) = switch (sync.status) {
      CloudStatus.upToDate => (colors.success, CupertinoIcons.checkmark_alt),
      CloudStatus.offline => (colors.warning, CupertinoIcons.wifi_slash),
      CloudStatus.paused || CloudStatus.refused => (colors.warning, CupertinoIcons.exclamationmark_triangle),
      _ => (colors.secondaryInk, CupertinoIcons.arrow_2_circlepath),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter + Space.xs, 0, Space.gutter, Space.md),
      child: Wrap(
        spacing: Space.sm,
        runSpacing: Space.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(DateFormat('EEEE, MMMM d').format(day), style: ShopType.subhead(context)),
          Pill(text: syncLabel(sync), color: color, icon: icon),
        ],
      ),
    );
  }
}

/// The one figure the owners open the app for — today's sales — on the
/// shop's mist, with the week behind it.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.snapshot});
  final TodaySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final lastWeekDay = DateFormat('EEEE').format(snapshot.day.subtract(const Duration(days: 7)));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Space.gutter),
      padding: const EdgeInsets.fromLTRB(Space.lg + Space.xs, Space.lg + Space.xs, Space.lg + Space.xs, Space.md),
      decoration: BoxDecoration(color: colors.hero, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sales today', style: ShopType.label(context).copyWith(color: colors.ink.withValues(alpha: 0.7))),
          const SizedBox(height: Space.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(pesoWhole.format(snapshot.today.revenue), style: ShopType.hero(context)),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DeltaPill(change: changeFrom(snapshot.sameDayLastWeek.revenue, snapshot.today.revenue)),
              Text(
                'vs last $lastWeekDay · ${pesoWhole.format(snapshot.sameDayLastWeek.revenue)}',
                style: ShopType.footnote(context).copyWith(color: colors.ink.withValues(alpha: 0.65)),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          _WeekBars(days: snapshot.lastSevenDays),
        ],
      ),
    );
  }
}

/// The last seven days as quiet bars, today's in full ink.
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days});
  final List<DailyRevenue> days;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final top = days.fold<double>(0, (m, d) => d.amount > m ? d.amount : m);
    final label = ShopType.caption(context).copyWith(color: colors.ink.withValues(alpha: 0.6));

    return SizedBox(
      height: 96,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: top == 0 ? 1 : top * 1.05,
          alignment: BarChartAlignment.spaceBetween,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  final isToday = i == days.length - 1;
                  return Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Text(
                      DateFormat('EEEEE').format(days[i].date),
                      style: isToday ? label.copyWith(color: colors.ink, fontWeight: FontWeight.w700) : label,
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => colors.ink,
              tooltipBorderRadius: BorderRadius.circular(Radii.badge),
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${DateFormat('EEE, MMM d').format(days[group.x].date)}\n',
                ShopType.caption(context).copyWith(color: colors.card),
                children: [
                  TextSpan(text: pesoWhole.format(rod.toY), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    // A sliver even on ₱0 days, so the week reads as seven days.
                    toY: days[i].amount == 0 ? (top == 0 ? 0.02 : top * 0.02) : days[i].amount,
                    color: i == days.length - 1 ? colors.ink : colors.ink.withValues(alpha: 0.18),
                    width: 22,
                    borderRadius: BorderRadius.circular(Radii.badge - 2),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The day's other figures in one quiet row, rather than three more cards.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.snapshot});
  final TodaySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final today = snapshot.today;
    final before = snapshot.sameDayLastWeek;
    final stats = [
      ('Gross profit', signedPeso(snapshot.todayGrossProfit, whole: true),
          changeFrom(snapshot.sameDayLastWeekGrossProfit, snapshot.todayGrossProfit)),
      ('Sales made', '${today.saleCount}', changeFrom(before.saleCount.toDouble(), today.saleCount.toDouble())),
      ('Pieces sold', '${today.itemsSold}', changeFrom(before.itemsSold.toDouble(), today.itemsSold.toDouble())),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
      padding: const EdgeInsets.symmetric(vertical: Space.lg),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(Radii.card)),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) Container(width: 0.5, color: colors.hairline),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stats[i].$1, style: ShopType.label(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: Space.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(stats[i].$2, style: ShopType.stat(context)),
                      ),
                      const SizedBox(height: Space.xs),
                      _Change(change: stats[i].$3),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact change for the stat row: "↑ 250%" in green, "↓ 12%" in red.
class _Change extends StatelessWidget {
  const _Change({required this.change});
  final double? change;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final c = change;
    final style = ShopType.caption(context).copyWith(fontWeight: FontWeight.w600, fontFeatures: ShopType.tabular);
    if (c == null) return Text('—', style: style.copyWith(color: colors.tertiaryInk));
    if (c.abs() < 0.005) return Text('Same', style: style);
    final up = c > 0;
    return Text(
      '${up ? '↑' : '↓'} ${(c.abs() * 100).round()}%',
      style: style.copyWith(color: up ? colors.success : colors.danger),
    );
  }
}

class _Attention extends StatelessWidget {
  const _Attention({required this.snapshot});
  final TodaySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    String plural(int n, String one, String many) => n == 1 ? one : many;

    final rows = <Widget>[
      if (snapshot.soldOut.isNotEmpty)
        ValueRow(
          leading: IconBadge(icon: CupertinoIcons.xmark, color: colors.danger),
          label: '${snapshot.soldOut.length} ${plural(snapshot.soldOut.length, 'item', 'items')} sold out',
          detail: _names(snapshot.soldOut.map((i) => i.name)),
        ),
      if (snapshot.lowStock.isNotEmpty)
        ValueRow(
          leading: IconBadge(icon: CupertinoIcons.exclamationmark_triangle_fill, color: colors.warning),
          label: '${snapshot.lowStock.length} ${plural(snapshot.lowStock.length, 'item', 'items')} low on stock',
          detail: _names(snapshot.lowStock.map((i) => '${i.name} (${i.qtyOnHand})')),
        ),
      if (snapshot.pickupsOverdue > 0)
        ValueRow(
          leading: IconBadge(icon: CupertinoIcons.clock_fill, color: colors.danger),
          label: '${snapshot.pickupsOverdue} ${plural(snapshot.pickupsOverdue, 'pickup', 'pickups')} overdue',
        ),
      if (snapshot.pickupsDueToday > 0)
        ValueRow(
          leading: IconBadge(icon: CupertinoIcons.bag_fill, color: colors.accent),
          label: '${snapshot.pickupsDueToday} ${plural(snapshot.pickupsDueToday, 'pickup', 'pickups')} due today',
        ),
    ];

    return GroupedSection(
      title: 'Needs attention',
      children: rows.isEmpty
          ? [ValueRow(leading: IconBadge(icon: CupertinoIcons.checkmark_alt, color: colors.success), label: 'All clear')]
          : rows,
    );
  }

  /// "Pleated skirt, Basic tee, and 3 more"
  static String _names(Iterable<String> names) {
    final list = names.toList();
    if (list.length <= 2) return list.join(', ');
    return '${list.take(2).join(', ')}, and ${list.length - 2} more';
  }
}

class _LatestSales extends StatelessWidget {
  const _LatestSales({required this.sales, required this.day});
  final List<Sale> sales;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return GroupedSection(
      title: 'Latest sales',
      children: sales.isEmpty
          ? [const ValueRow(label: 'No sales yet', tone: ValueTone.muted)]
          : [
              for (final sale in sales)
                SaleTile(
                  sale: sale,
                  when: saleWhen(sale, day),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(builder: (_) => SaleDetailScreen(saleId: sale.id, backLabel: 'Today')),
                  ),
                ),
            ],
    );
  }
}
