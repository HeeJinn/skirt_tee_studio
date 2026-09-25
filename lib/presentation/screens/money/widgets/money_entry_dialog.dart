import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_input.dart';
import '../../../../domain/entities/money_entry.dart';
import '../../../widgets/date_field.dart';
import '../../../widgets/filter_bar.dart';

/// Adds or edits one line in the owners' money log. Each kind explains in
/// a sentence what it does to the books, since "is this an expense?" is
/// exactly the question the owners couldn't answer before.
class MoneyEntryDialog extends StatefulWidget {
  const MoneyEntryDialog({super.key, required this.kind, required this.ownerNames, this.entry});

  final MoneyEntryKind kind;

  /// For "whose money". With one owner (or none) the choice isn't shown.
  final List<String> ownerNames;

  /// Pass to edit an existing entry; its kind wins over [kind].
  final MoneyEntry? entry;

  @override
  State<MoneyEntryDialog> createState() => _MoneyEntryDialogState();
}

class _MoneyEntryDialogState extends State<MoneyEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  late ExpenseCategory _category;
  late PaidFrom _paidFrom;
  String? _person;

  MoneyEntryKind get _kind => widget.entry?.kind ?? widget.kind;
  bool get _isExpense => _kind == MoneyEntryKind.expense;

  /// Whose money / who took it only matters when an owner is involved.
  bool get _asksPerson => widget.ownerNames.length > 1 && (!_isExpense || _paidFrom == PaidFrom.owners);

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _amount = TextEditingController(text: entry == null ? '' : formatAmountInput(entry.amount));
    _note = TextEditingController(text: entry?.note ?? '');
    _date = entry?.at ?? DateTime.now();
    _category = entry?.category ?? ExpenseCategory.rent;
    _paidFrom = entry?.paidFrom ?? PaidFrom.shop;
    _person = entry?.person;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(MoneyEntry(
      id: widget.entry?.id ?? const Uuid().v4(),
      at: _date,
      kind: _kind,
      amount: parseAmount(_amount.text)!,
      category: _isExpense ? _category : null,
      paidFrom: _isExpense ? _paidFrom : PaidFrom.shop,
      person: _asksPerson ? _person : null,
      note: _note.text.trim(),
    ));
  }

  String get _title => switch (_kind) {
        MoneyEntryKind.capitalIn => 'MONEY PUT IN',
        MoneyEntryKind.expense => 'EXPENSE',
        MoneyEntryKind.ownerDraw => 'TAKEN HOME',
      };

  String get _explainer => switch (_kind) {
        MoneyEntryKind.capitalIn =>
          'Your own money going into the shop — startup cash, racks, renovation. Counts toward what you\'ve invested.',
        MoneyEntryKind.expense =>
          'A cost of running the shop. Lowers profit. Buying stock isn\'t an expense — use Receive stock in Inventory.',
        MoneyEntryKind.ownerDraw =>
          'Money you take out for yourselves, including your own pay. Doesn\'t lower profit — it\'s profit you\'ve collected.',
      };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry == null ? _title : 'EDIT · $_title'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_explainer, style: context.text.bodySmall),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amount,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Amount (₱)'),
                        validator: (v) {
                          final n = parseAmount(v);
                          return (n == null || n <= 0) ? 'Enter an amount' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 170,
                      child: DateField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d)),
                    ),
                  ],
                ),
                if (_isExpense) ...[
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<ExpenseCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'What for'),
                    items: [for (final c in ExpenseCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
                    onChanged: (c) => setState(() => _category = c!),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('PAID WITH', style: context.text.labelSmall),
                  const SizedBox(height: 6),
                  ChoiceStrip<PaidFrom>(
                    options: [for (final p in PaidFrom.values) (p, p.label)],
                    selected: _paidFrom,
                    onSelected: (p) => setState(() => _paidFrom = p),
                  ),
                  if (_paidFrom == PaidFrom.owners) ...[
                    const SizedBox(height: 6),
                    Text('Also counts toward what you\'ve put into the shop.', style: context.text.bodySmall),
                  ],
                ],
                if (_asksPerson) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(_kind == MoneyEntryKind.ownerDraw ? 'TAKEN BY' : 'WHOSE MONEY', style: context.text.labelSmall),
                  const SizedBox(height: 6),
                  ChoiceStrip<String?>(
                    options: [(null, 'Both of us'), for (final n in widget.ownerNames) (n, n)],
                    selected: _person,
                    onSelected: (p) => setState(() => _person = p),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                TextFormField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)')),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
        ElevatedButton(onPressed: _submit, child: Text(widget.entry == null ? 'SAVE' : 'SAVE CHANGES')),
      ],
    );
  }
}
