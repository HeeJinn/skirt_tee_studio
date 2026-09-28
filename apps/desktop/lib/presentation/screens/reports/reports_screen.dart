import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import '../../viewmodels/inventory_view_model.dart';
import '../../viewmodels/sales_view_model.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/list_surface.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/stat_tile.dart';
import 'package:shop_core/calculations/report_calculations.dart';

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
final _pesoWhole = NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 0,
);

/// Compact axis label on round numbers: ₱0, ₱500, ₱1K, ₱1.5K.
String _axisPeso(double v) {
  if (v >= 1000) {
    final k = v / 1000;
    return '₱${k == k.roundToDouble() ? k.toInt() : k.toStringAsFixed(1)}K';
  }
  return '₱${v.toInt()}';
}

/// Core function: the shape of the business — revenue over time, what's
/// selling, which categories earn. One range filter scopes everything.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportRange _range = ReportRange.last30Days;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sales = filterSalesByRange(
      context.watch<SalesViewModel>().sales,
      _range,
      now,
    );
    final categoryByItemId = {
      for (final item in context.watch<InventoryViewModel>().items)
        item.id: item.category,
    };
    final summary = summarize(sales);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Reports',
            subtitle: '${_range.description} · ${summary.saleCount} sales',
          ),
          const SizedBox(height: 20),
          SegmentedStrip<ReportRange>(
            // No "Today": a one-day trend is a single bar — Sales covers today.
            options: [
              for (final r in ReportRange.values)
                if (r != ReportRange.today) (r, r.label),
            ],
            selected: _range,
            onSelected: (r) => setState(() => _range = r),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: sales.isEmpty
                ? const EmptyState(
                    icon: CupertinoIcons.chart_bar,
                    message: 'No sales in this range',
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StatRow(
                          tiles: [
                            StatTile(
                              label: 'Revenue',
                              value: _peso.format(summary.revenue),
                            ),
                            StatTile(
                              label: 'Sales',
                              value: '${summary.saleCount}',
                            ),
                            StatTile(
                              label: 'Average sale',
                              value: _peso.format(summary.averageSale),
                            ),
                            StatTile(
                              label: 'Items sold',
                              value: '${summary.itemsSold}',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _ReportCard(
                          title: 'Revenue trend',
                          caption: 'Daily revenue',
                          child: _RevenueColumns(
                            days: dailyRevenue(sales, _range, now),
                            range: _range,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _ReportCard(
                                  title: 'Top sellers',
                                  caption: 'By units sold',
                                  child: _RankedBars(
                                    entries: [
                                      for (final i in topSellingItems(sales))
                                        (
                                          i.itemName,
                                          i.qty.toDouble(),
                                          '${i.qty} sold',
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: _ReportCard(
                                  title: 'Revenue by category',
                                  caption: 'Share of revenue',
                                  child: _RankedBars(
                                    entries: [
                                      for (final c in revenueByCategory(
                                        sales,
                                        categoryByItemId,
                                      ))
                                        (
                                          c.category,
                                          c.amount,
                                          '${_pesoWhole.format(c.amount)} · '
                                              '${(c.amount / summary.revenue * 100).round()}%',
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
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.caption,
    required this.child,
  });

  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.container),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.titleSmall),
          const SizedBox(height: 2),
          Text(caption, style: context.text.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

/// Daily revenue as columns — discrete per-day totals, many of them zero,
/// read more honestly as bars than as a zig-zagging line.
class _RevenueColumns extends StatelessWidget {
  const _RevenueColumns({required this.days, required this.range});

  final List<DailyRevenue> days;
  final ReportRange range;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final maxValue = days.fold(0.0, (m, d) => d.amount > m ? d.amount : m);
    final step = niceStep(maxValue);
    final ceiling = niceCeiling(maxValue);
    final labelFormat = range == ReportRange.last7Days
        ? DateFormat('EEE')
        : DateFormat('MMM d');
    final labelEvery = (days.length / 7).ceil().clamp(1, days.length);
    final axisStyle = context.text.bodySmall?.copyWith(
      fontSize: 11,
      fontFeatures: kTabularFigures,
    );

    return SizedBox(
      height: 220,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = (constraints.maxWidth - 48) / days.length;
          final barWidth = (slot * 0.6).clamp(2.0, 24.0);

          return BarChart(
            BarChartData(
              minY: 0,
              maxY: ceiling,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: step,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: tokens.chartGrid, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: step,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        _axisPeso(value),
                        style: axisStyle,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      final isLast = i == days.length - 1;
                      if (i < 0 ||
                          i >= days.length ||
                          (i % labelEvery != 0 && !isLast)) {
                        return const SizedBox.shrink();
                      }
                      if (!isLast && days.length - 1 - i < labelEvery) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          labelFormat.format(days[i].date),
                          style: axisStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => context.colors.onSurface,
                  tooltipBorderRadius: BorderRadius.circular(AppRadius.control),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(
                        '${_peso.format(rod.toY)}\n',
                        TextStyle(
                          fontFamily: kSansFont,
                          color: context.colors.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: DateFormat('EEE, MMM d')
                                .format(days[group.x].date),
                            style: TextStyle(
                              fontFamily: kSansFont,
                              color: context.colors.onPrimary.withValues(
                                alpha: 0.75,
                              ),
                              fontWeight: FontWeight.w400,
                              fontSize: 12,
                            ),
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
                        color: tokens.chartSeries,
                        width: barWidth,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(barWidth >= 8 ? 4 : 1),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Horizontal ranked bars with direct labels: name on the left (long names
/// don't have to wrap under a column), value at the bar's tip, so nothing is
/// gated behind a hover tooltip. One series, so one hue.
class _RankedBars extends StatelessWidget {
  const _RankedBars({required this.entries});

  final List<(String label, double value, String valueLabel)> entries;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final maxValue = entries.fold(0.0, (m, e) => e.$2 > m ? e.$2 : m);

    return Column(
      children: [
        for (final (label, value, valueLabel) in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    label,
                    style: context.text.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: maxValue == 0 ? 0 : value / maxValue,
                    ),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    builder: (context, fraction, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fraction.clamp(0.01, 1.0),
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: tokens.chartSeries,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 112,
                  child: Text(
                    valueLabel,
                    textAlign: TextAlign.right,
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: kTabularFigures,
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
