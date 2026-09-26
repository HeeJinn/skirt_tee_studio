import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/calculations/report_calculations.dart';
import 'package:shop_core/core/format/money_format.dart';
import 'package:shop_core/domain/entities/cloud_sync.dart';
import 'package:shop_core/domain/entities/sale.dart';
import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';

import '../../../core/theme/cupertino_theme.dart';
import '../../viewmodels/today_view_model.dart';
import '../more/more_screen.dart';
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
          const CupertinoSliverNavigationBar(largeTitle: Text('Today')),
          CupertinoSliverRefreshControl(onRefresh: context.read<TodayViewModel>().load),
          if (snapshot == null)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CupertinoActivityIndicator()))
          else
            SliverList.list(
              children: [
                _Header(day: snapshot.day),
                _Tiles(snapshot: snapshot),
                _SectionTitle('Last 7 days'),
                _WeekChart(days: snapshot.lastSevenDays),
                _Attention(snapshot: snapshot),
                _LatestSales(sales: snapshot.latestSales, day: snapshot.day),
                if (snapshot.hasUncostedSales)
                  const _Footnote(
                    'Some of today\'s pieces have no recorded cost, so they count as ₱0 cost and profit reads high.',
                  ),
                const SizedBox(height: 24),
              ],
            ),
        ],
      ),
    );
  }
}

/// The date, and whether the phone has the shop computer's latest.
class _Header extends StatelessWidget {
  const _Header({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<CloudSyncViewModel>().state;
    final tokens = shopTokens(context);
    final color = switch (sync.status) {
      CloudStatus.upToDate => tokens.success,
      CloudStatus.offline || CloudStatus.paused => tokens.warning,
      _ => CupertinoColors.secondaryLabel.resolveFrom(context),
    };
    // Two lines rather than one row, so large text sizes still fit.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMM d').format(day),
            style: TextStyle(fontSize: 15, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                sync.status == CloudStatus.upToDate ? CupertinoIcons.checkmark_circle : CupertinoIcons.cloud,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Shop data ${syncLabel(sync).toLowerCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({required this.snapshot});
  final TodaySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final lastWeekDay = DateFormat('EEE').format(snapshot.day.subtract(const Duration(days: 7)));
    final today = snapshot.today;
    final before = snapshot.sameDayLastWeek;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
        children: [
          _Tile(
            label: 'Sales',
            value: pesoWhole.format(today.revenue),
            change: changeFrom(before.revenue, today.revenue),
            versus: 'last $lastWeekDay',
          ),
          _Tile(
            label: 'Gross profit',
            value: signedPeso(snapshot.todayGrossProfit, whole: true),
            change: changeFrom(snapshot.sameDayLastWeekGrossProfit, snapshot.todayGrossProfit),
            versus: 'last $lastWeekDay',
          ),
          _Tile(
            label: 'Sales made',
            value: '${today.saleCount}',
            change: changeFrom(before.saleCount.toDouble(), today.saleCount.toDouble()),
            versus: 'last $lastWeekDay',
          ),
          _Tile(
            label: 'Pieces sold',
            value: '${today.itemsSold}',
            change: changeFrom(before.itemsSold.toDouble(), today.itemsSold.toDouble()),
            versus: 'last $lastWeekDay',
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.change, required this.versus});

  final String label;
  final String value;

  /// Null when last week had nothing to compare with.
  final double? change;
  final String versus;

  @override
  Widget build(BuildContext context) {
    final tokens = shopTokens(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final change = this.change;
    final (changeText, changeColor) = switch (change) {
      null => ('Nothing $versus', secondary),
      final c when c.abs() < 0.005 => ('Same as $versus', secondary),
      final c => ('${c > 0 ? '+' : '−'}${(c.abs() * 100).round()}% vs $versus', c > 0 ? tokens.success : tokens.danger),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: secondary)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          ),
          Text(changeText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: changeColor)),
        ],
      ),
    );
  }
}

/// Sales per day for the last week, today's bar in the shop's color.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.days});
  final List<DailyRevenue> days;

  @override
  Widget build(BuildContext context) {
    final tokens = shopTokens(context);
    final brand = CupertinoTheme.of(context).primaryColor;
    final muted = CupertinoColors.systemGrey3.resolveFrom(context);
    final label = CupertinoColors.secondaryLabel.resolveFrom(context);
    final top = days.fold<double>(0, (m, d) => d.amount > m ? d.amount : m);
    final ceiling = top == 0 ? 1.0 : niceCeiling(top);

    return Container(
      height: 170,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
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
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      i == days.length - 1 ? 'Today' : DateFormat('EEE').format(days[i].date),
                      style: TextStyle(fontSize: 11, color: label),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => CupertinoColors.label.resolveFrom(context),
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${DateFormat('EEE, MMM d').format(days[group.x].date)}\n',
                TextStyle(fontSize: 12, color: CupertinoColors.systemBackground.resolveFrom(context)),
                children: [
                  TextSpan(
                    text: pesoWhole.format(rod.toY),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
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
                    toY: days[i].amount,
                    color: i == days.length - 1 ? brand : muted,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Attention extends StatelessWidget {
  const _Attention({required this.snapshot});
  final TodaySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tokens = shopTokens(context);
    String plural(int n, String one, String many) => n == 1 ? one : many;

    final rows = <Widget>[
      if (snapshot.soldOut.isNotEmpty)
        _AttentionRow(
          icon: CupertinoIcons.xmark_circle,
          color: tokens.danger,
          title: '${snapshot.soldOut.length} ${plural(snapshot.soldOut.length, 'item', 'items')} sold out',
          detail: _names(snapshot.soldOut.map((i) => i.name)),
        ),
      if (snapshot.lowStock.isNotEmpty)
        _AttentionRow(
          icon: CupertinoIcons.exclamationmark_triangle,
          color: tokens.warning,
          title: '${snapshot.lowStock.length} ${plural(snapshot.lowStock.length, 'item', 'items')} low on stock',
          detail: _names(snapshot.lowStock.map((i) => '${i.name} (${i.qtyOnHand})')),
        ),
      if (snapshot.pickupsOverdue > 0)
        _AttentionRow(
          icon: CupertinoIcons.clock,
          color: tokens.danger,
          title: '${snapshot.pickupsOverdue} ${plural(snapshot.pickupsOverdue, 'pickup', 'pickups')} overdue',
        ),
      if (snapshot.pickupsDueToday > 0)
        _AttentionRow(
          icon: CupertinoIcons.calendar,
          color: CupertinoTheme.of(context).primaryColor,
          title: '${snapshot.pickupsDueToday} ${plural(snapshot.pickupsDueToday, 'pickup', 'pickups')} due today',
        ),
    ];

    return CupertinoListSection.insetGrouped(
      header: const Text('NEEDS ATTENTION'),
      children: rows.isEmpty
          ? [
              _AttentionRow(icon: CupertinoIcons.checkmark_circle, color: tokens.success, title: 'All clear'),
            ]
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

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.icon, required this.color, required this.title, this.detail});

  final IconData icon;
  final Color color;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) => CupertinoListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: detail == null ? null : Text(detail!),
      );
}

class _LatestSales extends StatelessWidget {
  const _LatestSales({required this.sales, required this.day});
  final List<Sale> sales;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      header: const Text('LATEST SALES'),
      children: sales.isEmpty
          ? [const CupertinoListTile(title: Text('No sales yet'))]
          : [
              for (final sale in sales)
                CupertinoListTile(
                  title: Text(_itemsLabel(sale)),
                  subtitle: Text(_whenAndHow(sale)),
                  additionalInfo: Text(peso.format(sale.totalAmount)),
                ),
            ],
    );
  }

  static String _itemsLabel(Sale sale) {
    final lines = sale.lineItems;
    if (lines.isEmpty) return 'Sale';
    if (lines.length == 1) return lines.single.qty == 1 ? lines.single.itemName : '${lines.single.itemName} × ${lines.single.qty}';
    return '${sale.totalItemsSold} items';
  }

  /// "2:41 PM · Cash" today, "Yesterday · GCash", or "Sep 24 · Card".
  String _whenAndHow(Sale sale) {
    final d = sale.dateTime;
    final saleDay = DateTime(d.year, d.month, d.day);
    final when = saleDay == day
        ? DateFormat.jm().format(d)
        : saleDay == day.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : DateFormat('MMM d').format(d);
    final how = sale.paymentMethod?.label;
    return how == null ? when : '$when · $how';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(36, 22, 20, 6),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
        ),
      );
}

class _Footnote extends StatelessWidget {
  const _Footnote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(36, 0, 36, 8),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
        ),
      );
}
