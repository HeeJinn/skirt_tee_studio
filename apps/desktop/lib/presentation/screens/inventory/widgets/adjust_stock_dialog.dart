import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/stock.dart';
import '../../../widgets/filter_bar.dart';

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

/// What [AdjustStockDialog] returns: pieces leaving as a loss ([reason]
/// set) or pieces that turned up ([reason] null).
class StockAdjustment {
  const StockAdjustment({required this.qty, this.reason, this.note = ''});
  final int qty;
  final WriteOffReason? reason;
  final String note;

  bool get isFound => reason == null;
}

/// Records stock leaving without a sale — the losses that otherwise vanish
/// silently when someone just lowers a count — or a recount finding more.
class AdjustStockDialog extends StatefulWidget {
  const AdjustStockDialog({super.key, required this.item});
  final Item item;

  @override
  State<AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends State<AdjustStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _noteController = TextEditingController();
  bool _found = false;
  WriteOffReason _reason = WriteOffReason.damaged;

  /// "Removed from inventory" is booked by deleting the item, not chosen.
  static final _reasons = WriteOffReason.values.where((r) => r != WriteOffReason.removed).toList();

  int get _qty => int.tryParse(_qtyController.text) ?? 0;

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(StockAdjustment(
      qty: _qty,
      reason: _found ? null : _reason,
      note: _noteController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final cost = item.unitCost ?? 0;
    final value = _qty * cost;

    return AlertDialog(
      title: const Text('ADJUST STOCK'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text(
                '${item.qtyOnHand} in stock · '
                '${item.unitCost == null ? 'no cost recorded' : '${_peso.format(cost)} each at cost'}',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              ChoiceStrip<bool>(
                options: const [(false, 'Remove pieces'), (true, 'Found pieces')],
                selected: _found,
                onSelected: (v) => setState(() => _found = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      controller: _qtyController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Pieces'),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'Enter 1 or more';
                        if (!_found && n > item.qtyOnHand) return 'Only ${item.qtyOnHand} in stock';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  if (!_found)
                    Expanded(
                      child: DropdownButtonFormField<WriteOffReason>(
                        initialValue: _reason,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Why'),
                        items: [for (final r in _reasons) DropdownMenuItem(value: r, child: Text(r.label))],
                        onChanged: (r) => setState(() => _reason = r!),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ImpactLine(found: _found, value: value, hasCost: item.unitCost != null),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
        ElevatedButton(onPressed: _submit, child: Text(_found ? 'ADD BACK' : 'REMOVE')),
      ],
    );
  }
}

/// Says in money what the adjustment does to the books, before it's saved.
class _ImpactLine extends StatelessWidget {
  const _ImpactLine({required this.found, required this.value, required this.hasCost});
  final bool found;
  final double value;
  final bool hasCost;

  @override
  Widget build(BuildContext context) {
    final String message;
    if (!hasCost) {
      message = 'This item has no recorded cost, so profit won\'t change.';
    } else if (found) {
      message = 'Undoes ${_peso.format(value)} of losses.';
    } else {
      message = 'Records a ${_peso.format(value)} loss at cost.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      decoration: BoxDecoration(
        color: context.tokens.sunken,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(message, style: context.text.bodyMedium?.copyWith(fontFeatures: kTabularFigures)),
    );
  }
}
