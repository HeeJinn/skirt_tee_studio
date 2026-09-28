import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import '../../../../core/utils/money_input.dart';
import 'package:shop_core/domain/costing.dart';
import 'package:shop_core/domain/entities/item.dart';
import 'package:shop_core/domain/entities/money_entry.dart';
import 'package:shop_core/domain/entities/stock.dart';
import 'package:shop_core/domain/repositories/settings_repository.dart';
import '../../../../core/constants/categories.dart';
import '../../../widgets/date_field.dart';
import '../../../widgets/filter_bar.dart';
import '../../../widgets/item_thumbnail.dart';
import '../../../widgets/list_surface.dart';
import 'category_field.dart';
import 'item_form_dialog.dart';

final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

/// What [ReceiveStockDialog] returns, ready for InventoryViewModel.receiveLot.
class ReceivedLot {
  const ReceivedLot({required this.lot, required this.lines, required this.newItems});
  final StockLot lot;
  final List<LotLine> lines;
  final List<Item> newItems;

  int get pieces => lines.fold(0, (sum, l) => sum + l.qty);
}

/// Records a purchase of stock — typically a mixed bundle (tees, skirts,
/// long sleeves…) sorted into several items. Each kind goes in on one quick
/// line (category, price, pieces) without opening a form per item. The
/// lot's cost is split across the pieces by selling price, and the dialog
/// previews each item's resulting cost before saving.
class ReceiveStockDialog extends StatefulWidget {
  const ReceiveStockDialog({
    super.key,
    required this.items,
    required this.ownerNames,
    this.categories = SettingsRepository.defaultCategories,
  });

  final List<Item> items;

  /// The shop's categories. New ones typed here come back on the lot's new
  /// items; the caller adds them to the shop's list.
  final List<String> categories;

  /// For "whose money" when the owners paid themselves. With one owner (or
  /// none) the choice isn't shown.
  final List<String> ownerNames;

  @override
  State<ReceiveStockDialog> createState() => _ReceiveStockDialogState();
}

class _Draft {
  _Draft(this.item, {required this.isNew, int? pieces}) : qty = TextEditingController(text: pieces?.toString());
  final Item item;
  final bool isNew;
  final TextEditingController qty;

  int get pieces => int.tryParse(qty.text) ?? 0;
}

class _ReceiveStockDialogState extends State<ReceiveStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _supplier = TextEditingController();
  final _itemsCost = TextEditingController();
  final _fees = TextEditingController();
  final _note = TextEditingController();
  final _drafts = <_Draft>[];
  DateTime _date = DateTime.now();
  PaidFrom _paidFrom = PaidFrom.shop;
  String? _person;
  String? _linesError;

  // The quick-add line.
  late String _quickCategory = widget.categories.firstOrNull ?? 'Other';
  final _quickName = TextEditingController();
  final _quickPrice = TextEditingController();
  final _quickPieces = TextEditingController();
  final _quickNameFocus = FocusNode();
  String? _quickError;

  /// The shop's categories plus any the lot's new items brought in.
  List<String> get _categories => categoryOptions(widget.categories, [
        ...widget.items,
        for (final d in _drafts.where((d) => d.isNew)) d.item,
      ]);

  /// What the bundle held, e.g. {T-Shirt: 12, Long Sleeves: 5}.
  Map<String, int> get _piecesByCategory {
    final counts = <String, int>{};
    for (final d in _drafts.where((d) => d.pieces > 0)) {
      counts.update(d.item.category, (v) => v + d.pieces, ifAbsent: () => d.pieces);
    }
    return counts;
  }

  double get _totalCost => (parseAmount(_itemsCost.text) ?? 0) + (parseAmount(_fees.text) ?? 0);

  List<LotLine> get _lines => [
        for (final d in _drafts)
          LotLine(itemId: d.item.id, itemName: d.item.name, qty: d.pieces, sellingPrice: d.item.unitPrice),
      ];

  @override
  void dispose() {
    for (final c in [_supplier, _itemsCost, _fees, _note, _quickName, _quickPrice, _quickPieces]) {
      c.dispose();
    }
    _quickNameFocus.dispose();
    for (final d in _drafts) {
      d.qty.dispose();
    }
    super.dispose();
  }

  void _addDraft(_Draft draft) => setState(() {
        _drafts.add(draft);
        _linesError = null;
      });

  void _removeDraft(_Draft draft) {
    setState(() => _drafts.remove(draft));
    // Its field is still mounted until this rebuild lands.
    WidgetsBinding.instance.addPostFrameCallback((_) => draft.qty.dispose());
  }

  Future<void> _addNewItem() async {
    final item = await showDialog<Item>(
      context: context,
      builder: (_) => ItemFormDialog(forLot: true, categories: _categories),
    );
    if (item != null && mounted) _addDraft(_Draft(item, isNew: true));
  }

  bool get _quickLineStarted => [_quickName, _quickPrice, _quickPieces].any((c) => c.text.trim().isNotEmpty);

  /// Adds the quick line to the lot. With no name, the item is named after
  /// its category ("Long Sleeves"). A name already in inventory, or already
  /// in this lot, tops up that item rather than making a second one with the
  /// same name. Returns whether it was added.
  bool _addQuickLine() {
    final pieces = int.tryParse(_quickPieces.text.trim());
    final priceText = _quickPrice.text.trim();
    final price = priceText.isEmpty ? null : parseAmount(priceText);
    final name = _quickName.text.trim().isEmpty ? _quickCategory : _quickName.text.trim();

    String? error;
    bool same(Item i) => i.name.trim().toLowerCase() == name.toLowerCase();
    final inLot = _drafts.where((d) => same(d.item)).firstOrNull;
    final inStock = widget.items.where(same).firstOrNull;
    final match = inLot?.item ?? inStock;

    if (pieces == null || pieces <= 0) {
      error = 'How many pieces? Enter 1 or more.';
    } else if (priceText.isNotEmpty && (price == null || price < 0)) {
      error = 'Enter what each piece sells for.';
    } else if (match != null && price != null && price != match.unitPrice) {
      error = '"${match.name}" already sells for ${_peso.format(match.unitPrice)}. '
          'Give pieces at a different price their own name, e.g. "$name ${formatAmountInput(price)}".';
    } else if (match == null && price == null) {
      error = 'Enter what each piece sells for.';
    }
    if (error != null) {
      setState(() => _quickError = error);
      return false;
    }

    setState(() {
      if (inLot != null) {
        inLot.qty.text = '${inLot.pieces + pieces!}';
      } else if (inStock != null) {
        _drafts.add(_Draft(inStock, isNew: false, pieces: pieces));
      } else {
        _drafts.add(_Draft(
          Item(id: const Uuid().v4(), name: name, category: _quickCategory, unitPrice: price!, qtyOnHand: 0),
          isNew: true,
          pieces: pieces,
        ));
      }
      _linesError = null;
      _quickError = null;
      _quickName.clear();
      _quickPrice.clear();
      _quickPieces.clear();
    });
    _quickNameFocus.requestFocus();
    return true;
  }

  void _submit() {
    // A filled-in quick line that wasn't added yet is surely meant to be.
    if (_quickLineStarted && !_addQuickLine()) return;
    final fieldsValid = _formKey.currentState!.validate();
    setState(() => _linesError = _drafts.isEmpty ? 'Add the items this lot was sorted into.' : null);
    if (!fieldsValid || _drafts.isEmpty) return;

    final lot = StockLot(
      id: const Uuid().v4(),
      at: _date,
      supplier: _supplier.text.trim(),
      itemsCost: parseAmount(_itemsCost.text)!,
      fees: parseAmount(_fees.text) ?? 0,
      paidFrom: _paidFrom,
      person: _paidFrom == PaidFrom.owners ? _person : null,
      note: _note.text.trim(),
    );
    Navigator.of(context).pop(ReceivedLot(
      lot: lot,
      lines: _lines,
      newItems: [for (final d in _drafts.where((d) => d.isNew)) d.item],
    ));
  }

  String? _amountValidator(String? v, {required bool required}) {
    if (v == null || v.trim().isEmpty) return required ? 'Required' : null;
    final n = parseAmount(v);
    if (n == null || n < 0) return 'Enter an amount';
    return null;
  }

  /// Category, name, price, pieces, Enter — one kind of piece from the
  /// bundle per line, without opening a form.
  Widget _quickLine(BuildContext context) {
    void submit([_]) => _addQuickLine();
    void clearError(_) {
      if (_quickError != null) setState(() => _quickError = null);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.tokens.sunken,
        borderRadius: BorderRadius.circular(AppRadius.container),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 170,
                child: CategoryField(
                  options: _categories,
                  value: _quickCategory,
                  onChanged: (c) => setState(() => _quickCategory = c),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _quickName,
                  focusNode: _quickNameFocus,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: 'Item name', hintText: _quickCategory),
                  onChanged: clearError,
                  onSubmitted: submit,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _quickPrice,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Sells for ₱'),
                  onChanged: clearError,
                  onSubmitted: submit,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: _qtyWidth,
                child: TextField(
                  controller: _quickPieces,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pieces'),
                  onChanged: clearError,
                  onSubmitted: submit,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ElevatedButton(onPressed: submit, child: const Text('ADD')),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _quickError ?? 'No name? It\'s named after the category. A name already in inventory adds to that item.',
            style: context.text.bodySmall?.copyWith(color: _quickError == null ? null : context.tokens.danger),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    final unitCosts = allocateLotCost(_totalCost, lines);
    final pieces = lines.fold(0, (sum, l) => sum + l.qty);
    final pickable = widget.items.where((i) => !_drafts.any((d) => d.item.id == i.id)).toList();

    return AlertDialog(
      title: const Text('RECEIVE STOCK'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          // Room for the first fields' floating labels, which the scroll
          // view would otherwise clip.
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _supplier,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Supplier or source'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 180,
                      child: DateField(label: 'Bought on', value: _date, onChanged: (d) => setState(() => _date = d)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _itemsCost,
                        decoration: const InputDecoration(labelText: 'Price paid for the lot (₱)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => _amountValidator(v, required: true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _fees,
                        decoration: const InputDecoration(
                          labelText: 'Shipping & other fees (₱)',
                          helperText: 'Part of what the pieces cost.',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => _amountValidator(v, required: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _PaidFromPicker(
                  paidFrom: _paidFrom,
                  person: _person,
                  ownerNames: widget.ownerNames,
                  onPaidFrom: (v) => setState(() => _paidFrom = v),
                  onPerson: (v) => setState(() => _person = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                SectionLabel('Pieces in this lot', trailing: pieces == 0 ? null : '$pieces pieces'),
                Text(
                  'A mixed bundle? Add each kind on its own line — e.g. T-Shirt, ₱150, 12 pieces, then Long Sleeves, '
                  '₱180, 5 pieces. Count only pieces you\'ll sell; leave damaged ones out — their cost is spread '
                  'over the rest.',
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                if (_drafts.isNotEmpty) ...[
                  ListSurface(
                    header: const _LineHeader(),
                    children: [
                      for (var i = 0; i < _drafts.length; i++)
                        _LineRow(
                          key: ObjectKey(_drafts[i]),
                          draft: _drafts[i],
                          unitCost: _drafts[i].pieces > 0 ? unitCosts[i] : null,
                          onChanged: () => setState(() {}),
                          onRemove: () => _removeDraft(_drafts[i]),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                _quickLine(context),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _ItemPicker(
                        items: pickable,
                        onPicked: (item) => _addDraft(_Draft(item, isNew: false)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Tooltip(
                      message: 'Add a new item with a photo',
                      child: OutlinedButton.icon(
                        onPressed: _addNewItem,
                        icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                        label: const Text('NEW ITEM'),
                      ),
                    ),
                  ],
                ),
                if (_linesError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_linesError!, style: context.text.bodySmall?.copyWith(color: context.tokens.danger)),
                ],
                if (pieces > 0) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _LotSummary(
                    lines: lines,
                    totalCost: _totalCost,
                    piecesByCategory: _piecesByCategory,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextFormField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)')),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: _submit,
          child: Text(pieces == 0 ? 'RECEIVE' : 'RECEIVE $pieces ${pieces == 1 ? 'PIECE' : 'PIECES'}'),
        ),
      ],
    );
  }
}

/// Shop money vs. the owners' own, and (for a couple) which of them paid.
class _PaidFromPicker extends StatelessWidget {
  const _PaidFromPicker({
    required this.paidFrom,
    required this.person,
    required this.ownerNames,
    required this.onPaidFrom,
    required this.onPerson,
  });

  final PaidFrom paidFrom;
  final String? person;
  final List<String> ownerNames;
  final ValueChanged<PaidFrom> onPaidFrom;
  final ValueChanged<String?> onPerson;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PAID WITH', style: context.text.labelSmall),
        const SizedBox(height: 6),
        ChoiceStrip<PaidFrom>(
          options: [for (final p in PaidFrom.values) (p, p.label)],
          selected: paidFrom,
          onSelected: onPaidFrom,
        ),
        if (paidFrom == PaidFrom.owners) ...[
          if (ownerNames.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            ChoiceStrip<String?>(
              options: [(null, 'Both of us'), for (final n in ownerNames) (n, n)],
              selected: person,
              onSelected: onPerson,
            ),
          ],
          const SizedBox(height: 6),
          Text('Counts toward what you\'ve put into the shop.', style: context.text.bodySmall),
        ],
      ],
    );
  }
}

const _flexName = 6;
const _qtyWidth = 84.0;
const _flexMoney = 2;
const _removeWidth = 40.0;
const _linePadding = EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm);

class _LineHeader extends StatelessWidget {
  const _LineHeader();

  @override
  Widget build(BuildContext context) {
    final style = context.text.labelSmall;
    return Padding(
      padding: _linePadding,
      child: Row(
        children: [
          Expanded(flex: _flexName, child: Text('ITEM', style: style)),
          SizedBox(width: _qtyWidth, child: Text('PIECES', style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: _flexMoney, child: Text('SELLS FOR', style: style, textAlign: TextAlign.right)),
          Expanded(flex: _flexMoney, child: Text('COST EACH', style: style, textAlign: TextAlign.right)),
          Expanded(flex: _flexMoney, child: Text('PROFIT EACH', style: style, textAlign: TextAlign.right)),
          const SizedBox(width: _removeWidth),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    super.key,
    required this.draft,
    required this.unitCost,
    required this.onChanged,
    required this.onRemove,
  });

  final _Draft draft;

  /// Null until the line has pieces — there's nothing to split yet.
  final double? unitCost;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final item = draft.item;
    final tabular = context.text.bodyMedium?.copyWith(fontFeatures: kTabularFigures);
    final profit = unitCost == null ? null : item.unitPrice - unitCost!;

    return Padding(
      padding: _linePadding,
      child: Row(
        children: [
          Expanded(
            flex: _flexName,
            child: Row(
              children: [
                ItemThumbnail(imagePath: item.imagePath, name: item.name, size: 32),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        draft.isNew ? '${item.category} · new item' : '${item.category} · ${item.qtyOnHand} in stock',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: _qtyWidth,
            child: TextFormField(
              controller: draft.qty,
              keyboardType: TextInputType.number,
              style: tabular,
              decoration: const InputDecoration(hintText: '0'),
              onChanged: (_) => onChanged(),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n <= 0) ? '1 or more' : null;
              },
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: _flexMoney,
            child: Text(_peso.format(item.unitPrice), style: tabular, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: _flexMoney,
            child: Text(
              unitCost == null ? '—' : _peso.format(unitCost),
              style: tabular?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: _flexMoney,
            child: Text(
              profit == null ? '—' : _peso.format(profit),
              style: tabular?.copyWith(color: profit != null && profit < 0 ? context.tokens.danger : null),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: _removeWidth,
            child: IconButton(icon: const Icon(Icons.close, size: 16), tooltip: 'Remove from lot', onPressed: onRemove),
          ),
        ],
      ),
    );
  }
}

/// Type-to-search over inventory, for adding an existing item to the lot.
class _ItemPicker extends StatefulWidget {
  const _ItemPicker({required this.items, required this.onPicked});
  final List<Item> items;
  final ValueChanged<Item> onPicked;

  @override
  State<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends State<_ItemPicker> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Item>(
      textEditingController: _controller,
      focusNode: _focusNode,
      displayStringForOption: (item) => item.name,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        return widget.items.where((i) => query.isEmpty || i.name.toLowerCase().contains(query));
      },
      onSelected: (item) {
        widget.onPicked(item);
        _controller.clear();
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
        controller: controller,
        focusNode: focusNode,
        onSubmitted: (_) => onSubmitted(),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search, size: 20),
          hintText: 'Add an item from inventory',
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: context.colors.surface,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.container),
            side: BorderSide(color: context.tokens.hairline),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              shrinkWrap: true,
              children: [
                for (final item in options)
                  InkWell(
                    onTap: () => onSelected(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      child: Row(
                        children: [
                          ItemThumbnail(imagePath: item.imagePath, name: item.name, size: 28),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(item.name, overflow: TextOverflow.ellipsis)),
                          Text(
                            _peso.format(item.unitPrice),
                            style: context.text.bodySmall?.copyWith(fontFeatures: kTabularFigures),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The lot as a whole: what it cost against what it can sell for. Every
/// piece shares the same margin (that's what splitting by selling price
/// does), so this one figure speaks for the whole lot.
class _LotSummary extends StatelessWidget {
  const _LotSummary({required this.lines, required this.totalCost, required this.piecesByCategory});
  final List<LotLine> lines;
  final double totalCost;
  final Map<String, int> piecesByCategory;

  @override
  Widget build(BuildContext context) {
    final sellingValue = lines.fold<double>(0, (sum, l) => sum + l.qty * l.sellingPrice);
    final profit = sellingValue - totalCost;
    final margin = sellingValue == 0 ? 0.0 : profit / sellingValue;
    final losing = profit < 0;
    final figure = context.text.titleMedium?.copyWith(fontFeatures: kTabularFigures);

    Widget cell(String label, String value, {Color? color}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.text.labelSmall),
              const SizedBox(height: 2),
              Text(value, style: figure?.copyWith(color: color)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.tokens.sunken,
        borderRadius: BorderRadius.circular(AppRadius.container),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              cell('LOT COSTS', _peso.format(totalCost)),
              cell('SELLS FOR', _peso.format(sellingValue)),
              cell(
                'PROFIT IF ALL SELL',
                '${_peso.format(profit)} · ${(margin * 100).toStringAsFixed(0)}%',
                color: losing ? context.tokens.danger : context.tokens.success,
              ),
            ],
          ),
          if (piecesByCategory.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'In this bundle: ${piecesByCategory.entries.map((e) => '${e.value} ${e.key}').join(' · ')}',
              style: context.text.bodySmall?.copyWith(fontFeatures: kTabularFigures),
            ),
          ],
          if (losing) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This lot costs more than it can sell for at current prices.',
              style: context.text.bodySmall?.copyWith(color: context.tokens.danger),
            ),
          ],
        ],
      ),
    );
  }
}
