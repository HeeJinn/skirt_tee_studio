import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'tender.dart';

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
final _wholePeso = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);

/// "₱1,000" for bills and peso coins, "25¢" for centavo coins.
String formatDenomination(int centavos) => centavos >= 100 ? _wholePeso.format(centavos / 100) : '$centavos¢';

/// Asks how much cash the customer handed over for [total] and shows the
/// change due. Returns the amount received, or null if cancelled.
Future<double?> showCashTenderDialog(
  BuildContext context, {
  required double total,
  String confirmLabel = 'COMPLETE SALE',
}) =>
    showDialog<double>(
      context: context,
      builder: (_) => CashTenderDialog(total: total, confirmLabel: confirmLabel),
    );

/// Amount received → change due, three ways to enter it: tap the bills as
/// the customer hands them over (₱500 + ₱100 + ₱100…), pick a quick round
/// amount, or type it. Change comes with a bill-and-coin breakdown so the
/// cashier can count it straight out of the drawer.
class CashTenderDialog extends StatefulWidget {
  const CashTenderDialog({super.key, required this.total, this.confirmLabel = 'COMPLETE SALE'});
  final double total;
  final String confirmLabel;

  @override
  State<CashTenderDialog> createState() => _CashTenderDialogState();
}

class _CashTenderDialogState extends State<CashTenderDialog> {
  final _received = TextEditingController();

  /// How many of each bill/coin were tapped in, for the count badges. Reset
  /// whenever the amount is typed or set some other way, since the tally
  /// would no longer add up to it.
  final Map<int, int> _tally = {};

  @override
  void dispose() {
    _received.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_received.text);
  bool get _covers => _amount != null && coversTotal(_amount!, widget.total);

  void _setText(double amount) {
    final text = toCentavos(amount) % 100 == 0 ? '${toCentavos(amount) ~/ 100}' : amount.toStringAsFixed(2);
    _received.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  void _setAmount(double amount) => setState(() {
        _tally.clear();
        _setText(amount);
      });

  void _addDenomination(int centavos) => setState(() {
        _tally.update(centavos, (n) => n + 1, ifAbsent: () => 1);
        _setText((toCentavos(_amount ?? 0) + centavos) / 100);
      });

  void _clear() => setState(() {
        _tally.clear();
        _received.clear();
      });

  void _submit() {
    if (_covers) Navigator.of(context).pop(_amount);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final amount = _amount;
    final short = amount != null && !_covers;
    final change = amount != null && _covers ? changeDue(amount, widget.total) : null;

    return AlertDialog(
      title: const Text('CASH PAYMENT'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('Total due', style: context.text.bodyMedium?.copyWith(color: tokens.mutedText)),
                  const Spacer(),
                  Text(_peso.format(widget.total), style: context.text.headlineSmall),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _received,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                style: context.text.titleLarge?.copyWith(fontFeatures: kTabularFigures),
                decoration: InputDecoration(
                  labelText: 'Amount received',
                  prefixText: '₱ ',
                  suffixIcon: _received.text.isEmpty
                      ? null
                      : IconButton(icon: const Icon(Icons.close, size: 18), tooltip: 'Clear', onPressed: _clear),
                ),
                onChanged: (_) => setState(_tally.clear),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final (i, quick) in quickTenderAmounts(widget.total).indexed)
                    OutlinedButton(
                      onPressed: () => _setAmount(quick),
                      child: Text(i == 0 ? 'Exact' : _peso.format(quick)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('CUSTOMER HANDED OVER · TAP TO ADD', style: context.text.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              _DenominationPad(tally: _tally, onTap: _addDenomination),
              const SizedBox(height: AppSpacing.lg),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: tokens.sunken,
                  borderRadius: BorderRadius.circular(AppRadius.container),
                  border: Border.all(color: short ? tokens.danger : tokens.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          short ? 'Short by' : 'Change',
                          style: context.text.bodyMedium?.copyWith(color: short ? tokens.danger : tokens.mutedText),
                        ),
                        const Spacer(),
                        Text(
                          amount == null ? '—' : _peso.format(changeDue(amount, widget.total).abs()),
                          style: context.text.headlineMedium?.copyWith(
                            color: short ? tokens.danger : null,
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                      ],
                    ),
                    if (change != null && change > 0) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text('GIVE BACK', style: context.text.labelSmall),
                      const SizedBox(height: AppSpacing.xs),
                      ChangeBreakdownChips(change: change),
                    ] else if (change == 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text('Exact amount — no change', style: context.text.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
        ElevatedButton(onPressed: _covers ? _submit : null, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Bills on top, peso coins below — laid out like the drawer. Each tap adds
/// that denomination to the amount received; a badge counts the taps.
class _DenominationPad extends StatelessWidget {
  const _DenominationPad({required this.tally, required this.onTap});
  final Map<int, int> tally;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    Widget row(Iterable<int> denominations) => Row(
          children: [
            for (final (i, d) in denominations.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(child: _DenominationButton(centavos: d, count: tally[d] ?? 0, onTap: () => onTap(d))),
            ],
          ],
        );

    return Column(
      children: [
        row(kTenderDenominations.where(isBill).take(3)),
        const SizedBox(height: AppSpacing.sm),
        row(kTenderDenominations.where(isBill).skip(3)),
        const SizedBox(height: AppSpacing.sm),
        row(kTenderDenominations.where((d) => !isBill(d))),
      ],
    );
  }
}

class _DenominationButton extends StatelessWidget {
  const _DenominationButton({required this.centavos, required this.count, required this.onTap});
  final int centavos;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bill = isBill(centavos);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              backgroundColor: context.colors.surface,
              side: BorderSide(color: count > 0 ? context.colors.onSurface : context.tokens.hairline),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            icon: Icon(bill ? Icons.payments_outlined : Icons.toll_outlined, size: 16),
            label: Text(
              formatDenomination(centavos),
              style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontFeatures: kTabularFigures),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            top: -6,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Text(
                '×$count',
                style: TextStyle(
                  fontFamily: kSansFont,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.colors.onPrimary,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "1 × ₱100 · 2 × ₱20 · 3 × ₱1" as chips — what to pull from the drawer.
class ChangeBreakdownChips extends StatelessWidget {
  const ChangeBreakdownChips({super.key, required this.change});
  final double change;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final (centavos, count) in changeBreakdown(change))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: tokens.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isBill(centavos) ? Icons.payments_outlined : Icons.toll_outlined, size: 14, color: tokens.mutedText),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '$count × ${formatDenomination(centavos)}',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurface,
                    fontWeight: FontWeight.w600,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
