import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../money_calculations.dart';
import 'money_format.dart';

/// The period's profit laid out like an income statement, so the owners
/// can see exactly how sales turn into what the shop kept.
class ProfitBreakdown extends StatelessWidget {
  const ProfitBreakdown({super.key, required this.statement});

  final ProfitStatement statement;

  @override
  Widget build(BuildContext context) {
    final s = statement;
    final net = s.netProfit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Line('Sales', peso.format(s.revenue)),
        _Line('Cost of items sold', minusPeso(s.costOfGoodsSold)),
        const _Rule(),
        _Line(
          'Gross profit',
          signedPeso(s.grossProfit),
          strong: true,
          note: s.revenue == 0 ? null : '${(s.grossMargin * 100).round()}% of sales',
        ),
        for (final MapEntry(key: category, value: amount) in s.expensesByCategory.entries)
          _Line(category.label, minusPeso(amount), indent: true),
        if (s.expensesByCategory.isEmpty) const _Line('Expenses', '—', indent: true),
        if (s.stockLosses != 0)
          _Line(
            'Stock losses',
            s.stockLosses > 0 ? minusPeso(s.stockLosses) : '+${peso.format(-s.stockLosses)}',
            indent: true,
          ),
        const _Rule(),
        _Line(net < 0 ? 'Net loss' : 'Net profit', signedPeso(net), strong: true, large: true, danger: net < 0),
        if (s.unknownCostRevenue > 0) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.tokens.sunken,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: context.tokens.mutedText),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${peso.format(s.unknownCostRevenue)} of these sales were stock from before the books '
                    'started, counted at ₱0 cost — so profit reads high until that stock sells through. '
                    'Setting a cost on those items in Inventory fixes it from then on.',
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(
    this.label,
    this.value, {
    this.note,
    this.strong = false,
    this.large = false,
    this.indent = false,
    this.danger = false,
  });

  final String label;
  final String value;
  final String? note;
  final bool strong;
  final bool large;
  final bool indent;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final base = large ? context.text.titleMedium : context.text.bodyMedium;
    final weight = strong ? FontWeight.w700 : FontWeight.w400;
    final color = danger ? context.tokens.danger : (indent ? context.tokens.mutedText : null);

    return Padding(
      padding: EdgeInsets.fromLTRB(indent ? AppSpacing.lg : 0, 5, 0, 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label, style: base?.copyWith(fontWeight: weight, color: color)),
          if (note != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(note!, style: context.text.bodySmall),
          ],
          const Spacer(),
          Text(
            value,
            style: base?.copyWith(fontWeight: weight, color: color, fontFeatures: kTabularFigures),
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.xs), child: Divider());
}
