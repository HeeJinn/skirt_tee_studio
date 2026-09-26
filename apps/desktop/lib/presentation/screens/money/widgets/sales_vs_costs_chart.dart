import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/calculations/report_calculations.dart';
import 'package:shop_core/calculations/money_calculations.dart';
import 'money_format.dart';

/// Sales against everything that came off profit, month by month — the gap
/// between each pair is that month's profit. One axis (both are pesos), a
/// legend plus a fixed left/right order so identity never rides on color
/// alone, and the exact figures on hover.
class SalesVsCostsChart extends StatelessWidget {
  const SalesVsCostsChart({super.key, required this.months});

  final List<MonthlyProfit> months;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final maxValue = months.fold(0.0, (m, x) => [m, x.sales, x.costs].reduce((a, b) => a > b ? a : b));
    final step = niceStep(maxValue);
    final ceiling = niceCeiling(maxValue);
    final axisStyle = context.text.bodySmall?.copyWith(fontSize: 11, fontFeatures: kTabularFigures);
    final tooltipStrong = TextStyle(
      fontFamily: kSansFont,
      color: context.colors.onPrimary,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    );
    final tooltipSoft = tooltipStrong.copyWith(
      color: context.colors.onPrimary.withValues(alpha: 0.75),
      fontWeight: FontWeight.w400,
      fontSize: 12,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendKey(color: tokens.chartSales, label: 'Sales'),
            const SizedBox(width: AppSpacing.lg),
            _LegendKey(color: tokens.chartCosts, label: 'Costs'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 200,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slot = (constraints.maxWidth - 56) / months.length;
              final barWidth = ((slot * 0.6 - 2) / 2).clamp(4.0, 22.0);

              return BarChart(
                BarChartData(
                  minY: 0,
                  maxY: ceiling,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: step,
                    getDrawingHorizontalLine: (_) => FlLine(color: tokens.chartGrid, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 56,
                        interval: step,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(axisPeso(value), style: axisStyle, textAlign: TextAlign.right),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= months.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(DateFormat('MMM').format(months[i].month), style: axisStyle),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => context.colors.onSurface,
                      tooltipBorderRadius: BorderRadius.circular(AppRadius.control),
                      // Only the hovered bar shows a tooltip, so either bar
                      // of a month carries the whole month's summary.
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final m = months[group.x];
                        return BarTooltipItem(
                          '${DateFormat('MMMM y').format(m.month)}\n',
                          tooltipSoft,
                          textAlign: TextAlign.left,
                          children: [
                            TextSpan(text: 'Sales  ${peso.format(m.sales)}\n', style: tooltipStrong),
                            TextSpan(text: 'Costs  ${peso.format(m.costs)}\n', style: tooltipStrong),
                            TextSpan(
                              text: '${m.profit < 0 ? 'Loss' : 'Profit'}  ${signedPeso(m.profit)}',
                              style: tooltipSoft,
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
                        barsSpace: 2,
                        barRods: [
                          for (final (value, color) in [
                            (months[i].sales, tokens.chartSales),
                            (months[i].costs, tokens.chartCosts),
                          ])
                            BarChartRodData(
                              toY: value,
                              color: color,
                              width: barWidth,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(barWidth >= 8 ? 4 : 1)),
                            ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LegendKey extends StatelessWidget {
  const _LegendKey({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(label, style: context.text.bodySmall),
      ],
    );
  }
}
